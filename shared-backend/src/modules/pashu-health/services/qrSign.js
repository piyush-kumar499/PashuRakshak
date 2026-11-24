import crypto from 'node:crypto';

/** Server mirror of the Android QrPayloads signer: payload is
 * "<id>|<timestampMillis>|<hmacHex>" and the signature is HMAC-SHA256 of
 * "<id>|<timestampMillis>" keyed by the app API key (the same key the
 * Android client signed with).
 *
 * Payloads are short-lived: a code is only accepted for QR_TTL_MS (default
 * 2 minutes) after it was generated, so a photo or screenshot of a farmer's
 * QR cannot be replayed later. The Android screens re-sign well inside that
 * window.
 */
const DEFAULT_QR_TTL_MS = 2 * 60 * 1000;
const QR_CLOCK_SKEW_MS = 30_000;

function qrTtlMs() {
  const configured = Number(process.env.QR_TTL_MS);
  return Number.isFinite(configured) && configured > 0 ? configured : DEFAULT_QR_TTL_MS;
}

export function signQrPayload(id, secret) {
  const ts = Date.now();
  return `${id}|${ts}|${hmacHex(`${id}|${ts}`, secret)}`;
}

/**
 * Verifies the HMAC and the freshness of a scanned payload.
 * @returns {{ id: string|null, reason: 'ok'|'expired'|'invalid' }}
 */
export function verifyQrPayload(raw, secret) {
  if (typeof raw !== 'string') return { id: null, reason: 'invalid' };

  const parts = raw.split('|');
  if (parts.length !== 3) return { id: null, reason: 'invalid' };

  const [id, tsText, sig] = parts;
  if (!id || !/^[0-9]+$/.test(tsText) || !/^[0-9a-f]{64}$/.test(sig)) {
    return { id: null, reason: 'invalid' };
  }

  const expected = hmacHex(`${id}|${tsText}`, secret);
  const provided = Buffer.from(sig, 'hex');
  const wanted = Buffer.from(expected, 'hex');
  if (provided.length !== wanted.length || !crypto.timingSafeEqual(provided, wanted)) {
    return { id: null, reason: 'invalid' };
  }

  const age = Date.now() - Number(tsText);
  if (!Number.isFinite(age) || age > qrTtlMs() || age < -QR_CLOCK_SKEW_MS) {
    return { id: null, reason: 'expired' };
  }

  return { id, reason: 'ok' };
}

/** Backwards-compatible helper: the embedded id when valid and fresh, else null. */
export function verifyAndExtractId(raw, secret) {
  const result = verifyQrPayload(raw, secret);
  return result.reason === 'ok' ? result.id : null;
}

function hmacHex(data, secret) {
  return crypto.createHmac('sha256', secret).update(data).digest('hex');
}
