package com.pashurakshak.app.data.remote

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QrPayloadsTest {

    @Test
    fun signedPayloadVerifiesAndExtractsId() {
        val id = "animal-123"
        val payload = QrPayloads.sign(id)

        assertEquals(id, QrPayloads.verifyAndExtractId(payload))
    }

    @Test
    fun tamperedPayloadIsRejected() {
        val payload = QrPayloads.sign("animal-123")
        val parts = payload.split('|')
        val tampered = "${parts[0]}|${parts[1]}|${"0".repeat(64)}"

        assertNull(QrPayloads.verifyAndExtractId(tampered))
    }

    @Test
    fun malformedPayloadIsRejected() {
        assertNull(QrPayloads.verifyAndExtractId("animal-123"))
        assertNull(QrPayloads.verifyAndExtractId("animal-123|123|"))
        assertNull(QrPayloads.verifyAndExtractId("a|b|c|d"))
    }

    @Test
    fun payloadInsideTtlIsAccepted() {
        val payload = QrPayloads.signAt("animal-123", System.currentTimeMillis() - 1_000L)

        assertEquals(
            "animal-123",
            (QrPayloads.verify(payload) as QrPayloads.Verification.Valid).id,
        )
    }

    @Test
    fun payloadOlderThanTtlIsRejected() {
        // Validly signed, but generated just past the freshness window: this is
        // the replay case (a saved screenshot) that must not verify.
        val payload = QrPayloads.signAt(
            "animal-123",
            System.currentTimeMillis() - QrPayloads.TTL_MS - 1_000L,
        )

        assertEquals(QrPayloads.Verification.Expired, QrPayloads.verify(payload))
        assertNull(QrPayloads.verifyAndExtractId(payload))
    }

    @Test
    fun payloadTooFarInTheFutureIsRejected() {
        val payload = QrPayloads.signAt(
            "animal-123",
            System.currentTimeMillis() + 5 * 60 * 1000L,
        )

        assertEquals(QrPayloads.Verification.Expired, QrPayloads.verify(payload))
    }
}
