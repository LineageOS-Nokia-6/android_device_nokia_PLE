// SPDX-License-Identifier: GPL-2.0
package me.phh.sip

import java.net.InetAddress

internal object PcscfCandidateOrder {
    fun merge(
        network: List<InetAddress>,
        cached: List<InetAddress>,
        configured: List<InetAddress>,
    ): List<InetAddress> =
        (network + cached + configured).distinctBy(InetAddress::getHostAddress)
}
