// Copyright (C) 2026 The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
// Pronto's firmware is brought up by the existing exact619F WCNSS path.
// Its two native SMD channels already carry HCI packets (without H4 bytes).
// Reuse the maintained AOSP packetizer, not an unrelated UART/vendor blob.
#define LOG_TAG "PLE-Bluetooth"
#include <android/hardware/bluetooth/1.0/IBluetoothHci.h>
#include <android/hardware/bluetooth/1.0/IBluetoothHciCallbacks.h>
#include <hidl/HidlTransportSupport.h>
#include <log/log.h>
#include <memory>
#include <mutex>
#include "endpoints.h"
#include "packet-watcher.h"
#include "packet-write.h"
#include "quiesce.h"
#include "mct_protocol.h"

using android::sp;
using android::hardware::Return;
using android::hardware::Void;
using android::hardware::hidl_vec;
using namespace android::hardware::bluetooth::V1_0;
namespace hci = android::hardware::bluetooth::hci;

namespace {
struct Transport {
    std::unique_ptr<ple::Endpoints> endpoints;
    std::unique_ptr<hci::MctProtocol> protocol;
    std::unique_ptr<ple::PacketWatcher> watcher;
    std::mutex transmit_mutex;
    sp<IBluetoothHciCallbacks> callback;
    bool closed = false; // guarded by transmit_mutex, including retained senders
    ~Transport() { Shutdown(); }
    void Shutdown() {
        std::lock_guard lock(transmit_mutex);
        if (closed) return;
        closed = true;
        // Reader callbacks reference protocol. Join before destroying either
        // protocol or its endpoint descriptors, including partial startup.
        watcher.reset();
        if (protocol && !ple::Quiesce(endpoints->command()))
            ALOGW("Pronto HCIReset not acknowledged during close");
        protocol.reset();
        endpoints.reset();
    }
};

class DeathRecipient : public android::hardware::hidl_death_recipient {
public:
    explicit DeathRecipient(std::function<void()> close) : close_(std::move(close)) {}
    void serviceDied(uint64_t, const android::wp<android::hidl::base::V1_0::IBase>&) override {
        close_();
    }
private:
    std::function<void()> close_;
};

class BluetoothHci final : public IBluetoothHci {
public:
    BluetoothHci() : death_(new DeathRecipient([this] { close(); })) {}
    Return<void> initialize(const sp<IBluetoothHciCallbacks>& cb) override {
        if (!cb) return Void();
        {
            std::lock_guard lock(mutex_);
            if (transport_ || closing_) {
                cb->initializationComplete(Status::INITIALIZATION_ERROR).isOk();
                return Void();
            }
        }
        auto state = std::make_shared<Transport>();
        state->callback = cb;
        state->endpoints = ple::Endpoints::Open();
        if (!state->endpoints) {
            ALOGE("Cannot open Pronto SMD packet endpoints: %m");
            cb->initializationComplete(Status::INITIALIZATION_ERROR).isOk();
            return Void();
        }
        int fds[CH_MAX];
        fds[CH_CMD] = fds[CH_EVT] = state->endpoints->command();
        fds[CH_ACL_IN] = fds[CH_ACL_OUT] = state->endpoints->acl();
        state->protocol = std::make_unique<hci::MctProtocol>(fds,
            [cb](const hidl_vec<uint8_t>& p) { cb->hciEventReceived(p).isOk(); },
            [cb](const hidl_vec<uint8_t>& p) { cb->aclDataReceived(p).isOk(); });
        auto* protocol = state->protocol.get();
        state->watcher = ple::PacketWatcher::Start(state->endpoints->command(), state->endpoints->acl(),
            [protocol](int fd) { protocol->OnEventDataReady(fd); },
            [protocol](int fd) { protocol->OnAclDataReady(fd); },
            [cb] {
                ALOGE("Pronto packet channel closed or failed");
                // Standard HCI Hardware Error, letting Android recover the
                // controller instead of an EOF busy loop or silent hang.
                cb->hciEventReceived(hidl_vec<uint8_t>{0x10, 0x01, 0x01}).isOk();
            });
        if (!state->watcher) {
            cb->initializationComplete(Status::INITIALIZATION_ERROR).isOk();
            return Void();
        }
        auto linked = cb->linkToDeath(death_, 0);
        if (cb->isRemote() && (!linked.isOk() || !static_cast<bool>(linked))) {
            ALOGE("Cannot link Bluetooth stack death recipient");
            return Void();
        }
        {
            std::lock_guard lock(mutex_);
            callback_ = cb;
            transport_ = std::move(state);
        }
        ALOGI("Pronto CMD/ACL packet transport initialized; no NV/persist write");
        if (!cb->initializationComplete(Status::SUCCESS).isOk()) close();
        return Void();
    }
    Return<void> close() override {
        std::shared_ptr<Transport> old;
        sp<IBluetoothHciCallbacks> cb;
        {
            std::lock_guard lock(mutex_);
            if (closing_) return Void();
            closing_ = true;
            old = std::move(transport_);
            cb = std::move(callback_);
        }
        // Explicitly quiesce even if an in-flight sender still retains state;
        // its later destructor must not reset a newly initialized controller.
        if (old) old->Shutdown();
        old.reset();
        if (cb) cb->unlinkToDeath(death_).isOk();
        {
            std::lock_guard lock(mutex_);
            closing_ = false;
        }
        return Void();
    }
    Return<void> sendHciCommand(const hidl_vec<uint8_t>& p) override { Send(HCI_PACKET_TYPE_COMMAND, p); return Void(); }
    Return<void> sendAclData(const hidl_vec<uint8_t>& p) override { Send(HCI_PACKET_TYPE_ACL_DATA, p); return Void(); }
    Return<void> sendScoData(const hidl_vec<uint8_t>&) override {
        // Pronto carries SCO through the platform PCM path, not either MCT fd.
        ALOGE("Host HCI SCO packets unsupported on Pronto PCM transport");
        return Void();
    }
private:
    void Send(uint8_t type, const hidl_vec<uint8_t>& p) {
        std::shared_ptr<Transport> state;
        {
            std::lock_guard lock(mutex_);
            state = transport_;
        }
        const bool command = type == HCI_PACKET_TYPE_COMMAND;
        if (!state || !ple::ValidPacket(command, p.data(), p.size())) {
            ALOGE("Send without initialized transport or with malformed packet"); return;
        }
        std::lock_guard lock(state->transmit_mutex);
        if (state->closed) return;
        if (!ple::WritePacket(command ? state->endpoints->command() : state->endpoints->acl(), p.data(), p.size())) {
            ALOGE("Incomplete Pronto HCI packet write");
            state->callback->hciEventReceived(hidl_vec<uint8_t>{0x10, 0x01, 0x01}).isOk();
        }
    }
    std::mutex mutex_;
    std::shared_ptr<Transport> transport_;
    bool closing_ = false;
    sp<IBluetoothHciCallbacks> callback_;
    sp<DeathRecipient> death_;
};
}

int main() {
    android::hardware::configureRpcThreadpool(1, true);
    sp<BluetoothHci> service = new BluetoothHci;
    if (service->registerAsService("default") != android::OK) {
        ALOGE("Cannot register PLE Bluetooth HCI1.0");
        return 1;
    }
    android::hardware::joinRpcThreadpool();
    return 1;
}
