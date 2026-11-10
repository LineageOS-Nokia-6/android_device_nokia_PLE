//SPDX-License-Identifier: GPL-2.0
package me.phh.sip

import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.TelephonyNetworkSpecifier

internal object ImsNetworkRequestPolicy {
    fun capabilityFor(useDefaultCellularBearer: Boolean): Int =
        if (useDefaultCellularBearer) {
            NetworkCapabilities.NET_CAPABILITY_INTERNET
        } else {
            NetworkCapabilities.NET_CAPABILITY_IMS
        }
}

object ImsNetworkRequestBuilder {
    fun buildForSubscription(
        subId: Int,
        useDefaultCellularBearer: Boolean = false,
    ): NetworkRequest {
        return NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(ImsNetworkRequestPolicy.capabilityFor(useDefaultCellularBearer))
            .setNetworkSpecifier(
                TelephonyNetworkSpecifier.Builder()
                    .setSubscriptionId(subId)
                    .build()
            )
            .build()
    }
}
