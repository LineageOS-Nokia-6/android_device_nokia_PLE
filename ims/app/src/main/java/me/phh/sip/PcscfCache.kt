// SPDX-License-Identifier: GPL-2.0
package me.phh.sip

import android.content.Context
import java.net.InetAddress

internal class PcscfCache(context: Context) {
    companion object {
        private const val PREFERENCES_NAME = "ims_network_state"
        private const val KEY_PCSCF_ADDRESSES = "pcscf_addresses"
    }

    private val preferences = context.createDeviceProtectedStorageContext().getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    fun write(addresses: List<InetAddress>) {
        val serialized = addresses
            .mapNotNull(InetAddress::getHostAddress)
            .distinct()
            .joinToString(",")
        if (serialized.isEmpty() || preferences.getString(KEY_PCSCF_ADDRESSES, "") == serialized) {
            return
        }
        preferences.edit().putString(KEY_PCSCF_ADDRESSES, serialized).apply()
    }

    fun read(): List<InetAddress> =
        preferences.getString(KEY_PCSCF_ADDRESSES, "")
            .orEmpty()
            .split(',')
            .map(String::trim)
            .filter(String::isNotEmpty)
            .flatMap { hostOrIp ->
                try {
                    InetAddress.getAllByName(hostOrIp).toList()
                } catch (_: Throwable) {
                    emptyList()
                }
            }
}
