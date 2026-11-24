package com.pashurakshak.app.data.remote

import com.pashurakshak.app.BuildConfig
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * HMAC-signed QR payloads so a code's contents can't be guessed or forged:
 * the payload is "<id>|<timestampMillis>|<hmacHex>" and the signature is
 * HMAC-SHA256 of "<id>|<timestampMillis>" keyed by the app API key. The
 * backend verifies the same signature before trusting the embedded id.
 *
 * Payloads are also **short-lived**: a signed payload is only accepted for
 * [TTL_MS] after it was generated, so a photo or screenshot of a farmer's QR
 * cannot be replayed later. Farmer screens re-sign on [REFRESH_INTERVAL_MS],
 * which is deliberately shorter than the TTL so the code on screen is always
 * valid.
 */
object QrPayloads {

    /** How long a signed payload stays valid (2 minutes). */
    const val TTL_MS: Long = 2 * 60 * 1000L

    /**
     * How often the farmer's screen regenerates the QR. Slightly shorter than
     * [TTL_MS] so the visible code never expires between refreshes.
     */
    const val REFRESH_INTERVAL_MS: Long = 105_000L

    /** Tolerated device clock skew when a payload's timestamp is in the future. */
    private const val CLOCK_SKEW_MS: Long = 30_000L

    /** Result of checking a scanned QR payload. */
    sealed interface Verification {
        data class Valid(val id: String, val timestampMillis: Long) : Verification
        data object Expired : Verification
        data object Invalid : Verification
    }

    fun sign(id: String): String = signAt(id, System.currentTimeMillis())

    /** Test seam: sign with an explicit timestamp so expiry can be exercised. */
    internal fun signAt(id: String, timestampMillis: Long): String =
        "$id|$timestampMillis|${hmacHex("$id|$timestampMillis")}"

    /** Full check: signature, then freshness. */
    fun verify(raw: String): Verification {
        val parts = raw.split('|')
        if (parts.size != 3) return Verification.Invalid
        val (id, ts, sig) = parts
        val timestamp = ts.toLongOrNull() ?: return Verification.Invalid
        if (id.isBlank()) return Verification.Invalid
        if (hmacHex("$id|$ts") != sig) return Verification.Invalid
        val age = System.currentTimeMillis() - timestamp
        if (age > TTL_MS || age < -CLOCK_SKEW_MS) return Verification.Expired
        return Verification.Valid(id, timestamp)
    }

    /** Returns the embedded id when the signature is valid and fresh, else null. */
    fun verifyAndExtractId(raw: String): String? =
        (verify(raw) as? Verification.Valid)?.id

    private fun hmacHex(data: String): String {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(BuildConfig.APP_API_KEY.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        return mac.doFinal(data.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
}
