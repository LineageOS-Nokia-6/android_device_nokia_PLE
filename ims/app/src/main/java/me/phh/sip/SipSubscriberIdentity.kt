// SPDX-License-Identifier: GPL-2.0
package me.phh.sip

/**
 * The IMS private identity, public identity, and home domain are independent
 * ISIM records.  Do not derive all three from the IMSI when the SIM supplies
 * carrier-specific values.
 */
data class SipSubscriberIdentity(
    val privateIdentity: String,
    val publicIdentity: String,
    val homeDomain: String,
    val usesIsimPrivateIdentity: Boolean,
    val usesIsimPublicIdentity: Boolean,
    val usesIsimHomeDomain: Boolean,
) {
    companion object {
        fun resolve(
            imsi: String,
            defaultRealm: String,
            isimImpi: String?,
            isimImpu: Array<String>?,
            isimDomain: String?,
        ): SipSubscriberIdentity {
            val normalizedIsimDomain = isimDomain
                ?.trim()
                ?.takeIf(::isUsableDomain)
            val homeDomain = normalizedIsimDomain ?: defaultRealm

            val normalizedIsimPrivateIdentity = isimImpi
                ?.trim()
                ?.removePrefix("sip:")
                ?.takeIf(::isUsableIdentity)
            val privateIdentity = normalizedIsimPrivateIdentity ?: "$imsi@$homeDomain"

            val normalizedIsimPublicIdentity = isimImpu
                ?.asSequence()
                ?.mapNotNull(::normalizePublicIdentity)
                ?.firstOrNull()
            val publicIdentity = normalizedIsimPublicIdentity ?: "$imsi@$homeDomain"

            return SipSubscriberIdentity(
                privateIdentity = privateIdentity,
                publicIdentity = publicIdentity,
                homeDomain = homeDomain,
                usesIsimPrivateIdentity = normalizedIsimPrivateIdentity != null,
                usesIsimPublicIdentity = normalizedIsimPublicIdentity != null,
                usesIsimHomeDomain = normalizedIsimDomain != null,
            )
        }

        private fun normalizePublicIdentity(raw: String?): String? {
            val trimmed = raw?.trim().orEmpty()
            if (!trimmed.startsWith("sip:", ignoreCase = true)) return null
            return trimmed.substringAfter(':').takeIf(::isUsableIdentity)
        }

        private fun isUsableIdentity(value: String): Boolean {
            val local = value.substringBefore('@', missingDelimiterValue = "")
            val domain = value.substringAfter('@', missingDelimiterValue = "")
            return local.isNotBlank() && isUsableDomain(domain)
        }

        private fun isUsableDomain(value: String): Boolean =
            value.isNotBlank() &&
                !value.any(Char::isWhitespace) &&
                '@' !in value &&
                ':' !in value
    }
}
