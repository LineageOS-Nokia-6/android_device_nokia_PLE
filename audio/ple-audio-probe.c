/* SPDX-License-Identifier: Apache-2.0
 * Bounded bringup diagnostic: load/open exact HAL; optional one-second tone.
 * No capture path, partition operation, calibration command or reboot API.
 * Normal HAL speaker startup may initialize SmartAmp, as explicitly approved.
 */
#include <dlfcn.h>
#include <errno.h>
#include <hardware/audio.h>
#include <inttypes.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    const char *mode = argc > 1 ? argv[1] : "--load";
    if (strcmp(mode, "--load") && strcmp(mode, "--open") && strcmp(mode, "--tone"))
        return 2;
    void *library = dlopen("/vendor/lib/hw/audio.primary.ple.so", RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        fprintf(stderr, "dlopen: %s\n", dlerror());
        return 3;
    }
    const struct hw_module_t *module = dlsym(library, HAL_MODULE_INFO_SYM_AS_STR);
    if (!module || !module->methods || !module->methods->open)
        return 4;
    printf("MODULE id=%s name=%s author=%s api=%04x\n", module->id,
           module->name, module->author, module->module_api_version);
    fflush(stdout);
    if (!strcmp(mode, "--load"))
        return 0;

    struct audio_hw_device *device = NULL;
    int status = audio_hw_device_open(module, &device);
    printf("OPEN status=%d version=%04x init=%d\n", status,
           device ? device->common.version : 0,
           device && device->init_check ? device->init_check(device) : -1);
    fflush(stdout);
    if (status || !device)
        return 5;
    if (!strcmp(mode, "--open")) {
        audio_hw_device_close(device);
        return 0;
    }

    struct audio_config config = {
        .sample_rate = 48000,
        .channel_mask = AUDIO_CHANNEL_OUT_STEREO,
        .format = AUDIO_FORMAT_PCM_16_BIT,
    };
    struct audio_stream_out *stream = NULL;
    status = device->open_output_stream(device, 2310, AUDIO_DEVICE_OUT_SPEAKER,
                                       AUDIO_OUTPUT_FLAG_PRIMARY, &config, &stream, "");
    printf("STREAM status=%d rate=%u mask=%x format=%x\n", status,
           config.sample_rate, config.channel_mask, config.format);
    fflush(stdout);
    if (status || !stream) {
        audio_hw_device_close(device);
        return 6;
    }
    if (config.sample_rate != 48000 || config.channel_mask != AUDIO_CHANNEL_OUT_STEREO ||
        config.format != AUDIO_FORMAT_PCM_16_BIT) {
        device->close_output_stream(device, stream);
        audio_hw_device_close(device);
        return 7;
    }
    if (stream->set_volume)
        stream->set_volume(stream, 0.1f, 0.1f);
    const size_t frames = 480, iterations = 100;
    int16_t samples[960];
    size_t written = 0;
    int result = 0;
    for (size_t n = 0; n < iterations; ++n) {
        for (size_t frame = 0; frame < frames; ++frame) {
            /* About -36dBFS peak before optional stream attenuation. */
            double phase = 6.283185307179586 * 440.0 * (double)(n * frames + frame) / 48000.0;
            int16_t sample = (int16_t)(512.0 * sin(phase));
            samples[frame * 2] = samples[frame * 2 + 1] = sample;
        }
        ssize_t bytes = stream->write(stream, samples, sizeof(samples));
        if (bytes != sizeof(samples)) {
            printf("WRITE unexpected=%zd expected=%zu\n", bytes, sizeof(samples));
            result = 8;
            break;
        }
        written += bytes;
    }
    uint64_t presented = 0;
    struct timespec timestamp = {0};
    int position = stream->get_presentation_position ?
        stream->get_presentation_position(stream, &presented, &timestamp) : -ENOSYS;
    printf("TONE bytes=%zu presentation_status=%d frames=%" PRIu64 "\n",
           written, position, presented);
    fflush(stdout);
    stream->common.standby(&stream->common);
    device->close_output_stream(device, stream);
    audio_hw_device_close(device);
    return result;
}
