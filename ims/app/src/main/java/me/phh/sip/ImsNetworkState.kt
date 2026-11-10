// SPDX-License-Identifier: GPL-2.0
package me.phh.sip

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.os.SystemProperties
import android.telephony.Rlog
import android.telephony.TelephonyManager
import android.telephony.ims.stub.ImsRegistrationImplBase.REGISTRATION_TECH_IWLAN
import android.telephony.ims.stub.ImsRegistrationImplBase.REGISTRATION_TECH_LTE
import java.net.Inet6Address
import java.net.InetAddress

internal sealed class ImsNetworkEndpointResolution {
    data class Success(
        val pcscfAddr: InetAddress,
        val localAddr: InetAddress,
    ) : ImsNetworkEndpointResolution()

    object WaitingForPcscf : ImsNetworkEndpointResolution()
    object NoLocalAddress : ImsNetworkEndpointResolution()
}

internal object ImsNetworkState {
    const val PROP_PCSCF_FALLBACK = "persist.ims.pcscf_fallback"

    fun registrationTechName(tech: Int): String =
        when (tech) {
            REGISTRATION_TECH_IWLAN -> "IWLAN"
            REGISTRATION_TECH_LTE -> "LTE"
            else -> "unknown($tech)"
        }

    fun detectRegistrationTech(
        connectivityManager: ConnectivityManager,
        network: Network?,
        lp: LinkProperties,
    ): Int {
        val iface = lp.interfaceName ?: ""
        if (iface.startsWith("ipsec", ignoreCase = true)) {
            return REGISTRATION_TECH_IWLAN
        }

        val caps = if (network != null) {
            try {
                connectivityManager.getNetworkCapabilities(network)
            } catch (_: Throwable) {
                null
            }
        } else {
            null
        }

        return if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) {
            REGISTRATION_TECH_IWLAN
        } else {
            REGISTRATION_TECH_LTE
        }
    }

    private fun cachePcscfs(tag: String, cache: PcscfCache?, addresses: List<InetAddress>) {
        if (cache == null || addresses.isEmpty()) return
        try {
            cache.write(addresses)
            Rlog.i(tag, "Cached discovered P-CSCFs in device-protected app storage: " +
                addresses.mapNotNull(InetAddress::getHostAddress))
        } catch (t: Throwable) {
            Rlog.w(tag, "Failed to cache P-CSCFs in device-protected app storage", t)
        }
    }

    private fun readManualPcscfs(ipVersionPolicy: SipIpVersionPolicy): List<InetAddress> =
        SystemProperties.get(PROP_PCSCF_FALLBACK, "")
            .trim()
            .takeIf { it.isNotEmpty() }
            ?.let { hostOrIp ->
                try {
                    InetAddress.getAllByName(hostOrIp).filter(ipVersionPolicy::accepts)
                } catch (_: Throwable) {
                    emptyList()
                }
            }
            .orEmpty()

    private fun readCachedPcscfs(
        tag: String,
        cache: PcscfCache?,
        ipVersionPolicy: SipIpVersionPolicy,
    ): List<InetAddress> = try {
        cache?.read()
            .orEmpty()
            .filter(ipVersionPolicy::accepts)
            .distinctBy(InetAddress::getHostAddress)
        } catch (_: Throwable) {
            Rlog.w(tag, "Failed to read cached P-CSCFs from device-protected app storage")
            emptyList()
        }

    fun getPcscfServers(
        lp: LinkProperties,
        ipVersionPolicy: SipIpVersionPolicy = SipIpVersionPolicy.ANY,
        configuredFallbacks: String = "",
        pcscfCache: PcscfCache? = null,
    ): List<InetAddress> {
        val addresses = (lp.javaClass.getMethod("getPcscfServers").invoke(lp) as List<*>)
            .filterIsInstance<InetAddress>()
            .sortedBy { if (it is Inet6Address) 0 else 1 }
        val matching = addresses.filter(ipVersionPolicy::accepts)
        val netPcscfs = matching.ifEmpty { addresses }

        cachePcscfs("ImsNetworkState", pcscfCache, netPcscfs)

        val configured = ConfiguredPcscfFallbacks.parse(configuredFallbacks)
            .flatMap { hostOrIp ->
                try {
                    InetAddress.getAllByName(hostOrIp).toList()
                } catch (_: Throwable) {
                    emptyList()
                }
            }
            .filter(ipVersionPolicy::accepts)
            .distinctBy(InetAddress::getHostAddress)
        val manual = readManualPcscfs(ipVersionPolicy)
        val cached = readCachedPcscfs("ImsNetworkState", pcscfCache, ipVersionPolicy)
        return PcscfCandidateOrder.merge(
            network = netPcscfs,
            cached = manual + cached,
            configured = configured,
        )
    }

    fun getImsLocalAddress(
        lp: LinkProperties,
        ipVersionPolicy: SipIpVersionPolicy = SipIpVersionPolicy.ANY,
        peerAddress: InetAddress? = null,
    ): InetAddress? {
        val addresses = lp.linkAddresses
            .map { it.address }
            .filter { !it.isAnyLocalAddress && !it.isLoopbackAddress }
            .sortedBy { if (it is Inet6Address) 0 else 1 }
        val sameFamily = peerAddress?.let { peer ->
            addresses.filter { candidate ->
                (candidate is Inet6Address) == (peer is Inet6Address)
            }
        }.orEmpty()
        return sameFamily.firstOrNull(ipVersionPolicy::accepts)
            ?: addresses.firstOrNull(ipVersionPolicy::accepts)
            ?: sameFamily.firstOrNull()
            ?: addresses.firstOrNull()
    }

    fun resolveEndpoint(
        tag: String,
        lp: LinkProperties,
        mnc: String,
        mcc: String,
        preferredPcscf: InetAddress? = null,
        ipVersionPolicy: SipIpVersionPolicy = SipIpVersionPolicy.ANY,
        configuredFallbacks: String = "",
        pcscfCache: PcscfCache? = null,
    ): ImsNetworkEndpointResolution {
        val pcscfs = getPcscfServers(lp, ipVersionPolicy, configuredFallbacks, pcscfCache)
        val pcscf = preferredPcscf ?: if (pcscfs.isNotEmpty()) {
            pcscfs[0]
        } else {
            val dnsFallback = try {
                InetAddress.getAllByName("ims.mnc${mnc}.mcc${mcc}.pub.3gppnetwork.org")
                    .firstOrNull(ipVersionPolicy::accepts)
            } catch (t: Throwable) {
                null
            } ?: try {
                InetAddress.getAllByName("ims.mnc${mnc}.mcc${mcc}.3gppnetwork.org")
                    .firstOrNull(ipVersionPolicy::accepts)
            } catch (t: Throwable) {
                null
            }

            if (dnsFallback != null) {
                Rlog.w(tag, "No P-CSCF from network or cache, using 3GPP DNS: $dnsFallback")
                dnsFallback
            } else {
                Rlog.w(tag, "No P-CSCF from network, cache or DNS, waiting for onLinkPropertiesChanged")
                return ImsNetworkEndpointResolution.WaitingForPcscf
            }
        }

        val localAddr = getImsLocalAddress(lp, ipVersionPolicy, pcscf)
        if (localAddr == null) {
            Rlog.w(tag, "No usable local address on IMS link properties")
            return ImsNetworkEndpointResolution.NoLocalAddress
        }

        return ImsNetworkEndpointResolution.Success(pcscf, localAddr)
    }

    fun ratName(rat: Int): String =
        when (rat) {
            TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
            TelephonyManager.NETWORK_TYPE_NR -> "NR"
            TelephonyManager.NETWORK_TYPE_IWLAN -> "IWLAN"
            TelephonyManager.NETWORK_TYPE_EDGE -> "EDGE"
            TelephonyManager.NETWORK_TYPE_GPRS -> "GPRS"
            TelephonyManager.NETWORK_TYPE_GSM -> "GSM"
            TelephonyManager.NETWORK_TYPE_UMTS -> "UMTS"
            TelephonyManager.NETWORK_TYPE_HSPA -> "HSPA"
            TelephonyManager.NETWORK_TYPE_HSDPA -> "HSDPA"
            TelephonyManager.NETWORK_TYPE_HSUPA -> "HSUPA"
            TelephonyManager.NETWORK_TYPE_UNKNOWN -> "UNKNOWN"
            else -> "rat($rat)"
        }

    fun isRatReadyForImsNetworkRequest(
        tag: String,
        telephonyManager: TelephonyManager,
    ): Boolean {
        val dataRat = try {
            telephonyManager.dataNetworkType
        } catch (t: Throwable) {
            TelephonyManager.NETWORK_TYPE_UNKNOWN
        }

        val voiceRat = try {
            telephonyManager.voiceNetworkType
        } catch (t: Throwable) {
            TelephonyManager.NETWORK_TYPE_UNKNOWN
        }

        val ready =
            dataRat == TelephonyManager.NETWORK_TYPE_LTE ||
                dataRat == TelephonyManager.NETWORK_TYPE_NR ||
                dataRat == TelephonyManager.NETWORK_TYPE_IWLAN ||
                voiceRat == TelephonyManager.NETWORK_TYPE_LTE ||
                voiceRat == TelephonyManager.NETWORK_TYPE_NR

        Rlog.d(
            tag,
            "IMS network request RAT gate: data=${ratName(dataRat)} voice=${ratName(voiceRat)} ready=$ready",
        )

        return ready
    }
}
