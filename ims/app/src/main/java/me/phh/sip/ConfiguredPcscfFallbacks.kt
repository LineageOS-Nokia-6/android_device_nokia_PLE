// SPDX-License-Identifier: GPL-2.0
package me.phh.sip

internal object ConfiguredPcscfFallbacks {
    fun parse(value: String): List<String> =
        value.split(',')
            .map(String::trim)
            .filter(String::isNotEmpty)
}
