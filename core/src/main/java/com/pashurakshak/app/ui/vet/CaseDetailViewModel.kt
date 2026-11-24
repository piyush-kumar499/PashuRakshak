package com.pashurakshak.app.ui.vet

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.pashurakshak.app.BuildConfig
import com.pashurakshak.app.data.AlertRepository
import com.pashurakshak.app.data.AnimalRepository
import com.pashurakshak.app.data.ReportRepository
import com.pashurakshak.app.data.local.Alert
import com.pashurakshak.app.data.local.Animal
import com.pashurakshak.app.data.local.ReportStatus
import com.pashurakshak.app.data.local.SymptomReport
import com.pashurakshak.app.data.SessionManager
import com.pashurakshak.app.data.sync.SyncScheduler
import com.pashurakshak.app.di.ServiceLocator
import com.pashurakshak.app.ui.farmer.prettifyStatus
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import kotlin.math.roundToInt

data class CaseDetailUiState(
    val isLoading: Boolean = true,
    val report: SymptomReport? = null,
    val animal: Animal? = null,
    val isSubmittingFieldCheck: Boolean = false,
    val isSubmittingVisit: Boolean = false,
    val isSubmittingResolution: Boolean = false,
    val notice: String? = null,
    val error: String? = null,
    val isQrScanned: Boolean = false,
    val scannedQrCodeId: String? = null,
    val qrVerified: Boolean = false,
    val qrExpiresAt: Long? = null,
    val qrExpired: Boolean = false,
    val assessment: String? = null,
    val assessmentText: String = "",
    val latitudeText: String = "",
    val longitudeText: String = "",
    val locationAccuracyMeters: Double? = null,
    val locationCapturedAt: Long? = null,
    val locationIsMock: Boolean = false,
    val locationError: String? = null,
    val resolutionNote: String = "",
) {
    val isReadOnly: Boolean
        get() = report?.status == ReportStatus.RESOLVED
    val canMarkExamined: Boolean
        get() = report != null &&
            (report.status == ReportStatus.REPORTED || report.status == ReportStatus.VET_ASSIGNED) &&
            !isSubmittingFieldCheck &&
            !isReadOnly

    /**
     * A location counts as trustworthy only when it came from the device's
     * location provider (never typed by hand), the OS did not mark it as a mock,
     * it is accurate enough, and it is recent enough to describe where the vet is
     * standing right now. The verification distance is computed from these
     * coordinates, so any weaker source would make the check meaningless.
     */
    val hasFreshDeviceLocation: Boolean
        get() = locationCapturedAt != null &&
            !locationIsMock &&
            locationError == null &&
            latitudeText.toDoubleOrNull() != null &&
            longitudeText.toDoubleOrNull() != null &&
            System.currentTimeMillis() - (locationCapturedAt ?: 0L) <= LOCATION_MAX_AGE_MS

    /**
     * The signed QR is only good for its own two-minute window. A code that was
     * scanned earlier must be re-scanned, so a saved screenshot cannot be reused
     * to "verify" a visit later.
     */
    val isQrFreshNow: Boolean
        get() = qrVerified &&
            qrExpiresAt != null &&
            System.currentTimeMillis() < (qrExpiresAt ?: 0L)

    val canSubmitVisit: Boolean
        get() = !isReadOnly &&
            isQrFreshNow &&
            assessment != null &&
            assessmentText.isNotBlank() &&
            hasFreshDeviceLocation &&
            !isSubmittingVisit
    val canResolve: Boolean
        get() = report != null &&
            (report.status == ReportStatus.EXAMINED ||
                report.status == ReportStatus.SAMPLE_SENT ||
                report.status == ReportStatus.CONFIRMED) &&
            !isSubmittingResolution &&
            !isSubmittingFieldCheck &&
            !isSubmittingVisit

    companion object {
        /** A fix older than this cannot prove where the vet is standing now. */
        const val LOCATION_MAX_AGE_MS: Long = 5 * 60 * 1000L

        /** Poorer fixes (cell/Wi-Fi only) are too imprecise to gate a verification. */
        const val LOCATION_MAX_ACCURACY_M: Double = 100.0
    }
}

class CaseDetailViewModel(
    private val reportId: String,
    private val reportRepository: ReportRepository,
    private val animalRepository: AnimalRepository,
    private val alertRepository: AlertRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(CaseDetailUiState())
    val uiState: StateFlow<CaseDetailUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    private fun load() {
        viewModelScope.launch {
            // Local-first: show the cached report immediately.
            runCatching { loadLocal() }.onSuccess { (report, animal) ->
                _uiState.update {
                    it.copy(isLoading = false, report = report, animal = animal, error = null)
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(isLoading = false, error = error.message ?: "Failed to load case")
                }
            }

            launch {
                runCatching { com.pashurakshak.app.data.sync.RemoteSync.pullAll(force = true) }
                runCatching { loadLocal() }.onSuccess { (report, animal) ->
                    _uiState.update {
                        it.copy(isLoading = false, report = report, animal = animal)
                    }
                }
            }
        }
    }

    private suspend fun loadLocal(): Pair<SymptomReport, Animal?> {
        val report = reportRepository.getById(reportId) ?: error("Report not found")
        val animal = animalRepository.getById(report.animalId)
        return report to animal
    }

    /** Called when the vet tries to mark examined without a verified QR scan. */
    fun blockUntilQrVerified() {
        _uiState.update {
            it.copy(error = "Scan the report QR first before submitting the details.")
        }
    }

    fun submitFieldCheck(sampleRequired: Boolean) {
        val report = _uiState.value.report ?: return
        if (report.status == ReportStatus.RESOLVED) return
        val assessmentText = _uiState.value.assessmentText
        val newStatus = if (sampleRequired) ReportStatus.SAMPLE_SENT else ReportStatus.EXAMINED
        // Marking a case examined without a successful QR scan is allowed for the
        // case to be tracked, but it is NOT QR-verified: the verification row is
        // written with matched = 0 so downstream screens can label it honestly.
        val verifiedThisCase = _uiState.value.qrVerified

        viewModelScope.launch {
            _uiState.update { it.copy(isSubmittingFieldCheck = true) }
            runCatching {
                reportRepository.update(report.copy(status = newStatus, vetAssessment = assessmentText, synced = false))
                // Persist the visit-verification row locally (matched = 1 only when
                // the QR actually matched this case; otherwise UNVERIFIED, matched = 0).
                runCatching {
                    val lat = _uiState.value.latitudeText.toDoubleOrNull() ?: report.latitude
                    val lon = _uiState.value.longitudeText.toDoubleOrNull() ?: report.longitude
                    reportRepository.insertVisitVerification(
                        reportId = report.id,
                        scannedQrCodeId = _uiState.value.scannedQrCodeId.orEmpty(),
                        latitude = lat,
                        longitude = lon,
                        assessment = assessmentText.ifBlank { newStatus.dbValue },
                        matched = if (verifiedThisCase) 1 else 0,
                    )
                }
                com.pashurakshak.app.data.sync.SyncScheduler.triggerNow(com.pashurakshak.app.di.ServiceLocator.context)
                val animalLabel = _uiState.value.animal?.let { "${it.name} (${it.species})" }
                    ?: "Animal ${report.animalId.take(8)}"
                val statusLabel = prettifyStatus(newStatus.dbValue)
                alertRepository.insert(
                    Alert(
                        recipientRole = "farmer",
                        recipientId = report.farmerId,
                        message = if (sampleRequired) {
                            "A vet examined $animalLabel — a sample was sent for lab testing."
                        } else {
                            "A vet examined $animalLabel — status: $statusLabel."
                        },
                    ),
                )
            }.onSuccess {
                _uiState.update {
                    it.copy(
                        isSubmittingFieldCheck = false,
                        report = report.copy(status = newStatus, vetAssessment = assessmentText),
                        notice = if (sampleRequired) {
                            "Status updated to: sample sent"
                        } else {
                            "Status updated to: examined"
                        },
                    )
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isSubmittingFieldCheck = false,
                        error = error.message ?: "Failed to update status",
                    )
                }
            }
        }
    }

    fun onResolutionNoteChanged(text: String) {
        _uiState.update { it.copy(resolutionNote = text) }
    }

    fun resolveCase() {
        val state = _uiState.value
        val report = state.report ?: return
        if (!state.canResolve) return
        val vetId = SessionManager.uid ?: return
        val note = state.resolutionNote.ifBlank { state.assessmentText.trim() }.takeIf { it.isNotBlank() }
        val resolvedAt = System.currentTimeMillis()

        viewModelScope.launch {
            _uiState.update { it.copy(isSubmittingResolution = true, error = null) }
            runCatching {
                val resolved = report.copy(
                    status = ReportStatus.RESOLVED,
                    resolvedAt = resolvedAt,
                    resolvedBy = vetId,
                    resolutionNote = note,
                    synced = false,
                )
                reportRepository.update(resolved)
                SyncScheduler.triggerNow(ServiceLocator.context)
                val animalLabel = state.animal?.let { "${it.name} (${it.species})" }
                    ?: "Animal ${report.animalId.take(8)}"
                alertRepository.insert(
                    Alert(
                        recipientRole = "farmer",
                        recipientId = report.farmerId,
                        message = "Case resolved for $animalLabel." +
                            (note?.let { " Note: $it" } ?: ""),
                    ),
                )
                resolved
            }.onSuccess { resolved ->
                _uiState.update {
                    it.copy(
                        isSubmittingResolution = false,
                        report = resolved,
                        notice = "Case marked as resolved",
                    )
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isSubmittingResolution = false,
                        error = error.message ?: "Could not resolve the case",
                    )
                }
            }
        }
    }

    fun onQrScanned(qrCodeId: String) {
        val report = _uiState.value.report
        // First verify the QR payload's HMAC signature (anti guess/forgery) and
        // its freshness (anti screenshot replay), then compare its embedded id
        // against this report's QR (animal fallback for legacy rows).
        val verification = com.pashurakshak.app.data.remote.QrPayloads.verify(qrCodeId)
        val valid = verification as? com.pashurakshak.app.data.remote.QrPayloads.Verification.Valid
        val signedId = valid?.id
        val expected = report?.qrCodeId?.takeIf { it.isNotBlank() }
            ?: _uiState.value.animal?.qrCodeId
        val matches = signedId != null && expected != null && signedId == expected
        _uiState.update {
            it.copy(
                isQrScanned = true,
                scannedQrCodeId = qrCodeId,
                qrVerified = matches,
                qrExpiresAt = valid
                    ?.takeIf { matches }
                    ?.let {
                        it.timestampMillis +
                            com.pashurakshak.app.data.remote.QrPayloads.TTL_MS
                    },
                qrExpired = false,
                error = when {
                    verification is com.pashurakshak.app.data.remote.QrPayloads.Verification.Expired ->
                        "This QR code has expired. Ask the farmer to refresh the code on their screen and scan again."
                    verification is com.pashurakshak.app.data.remote.QrPayloads.Verification.Invalid ->
                        "QR code signature is invalid or forged."
                    !matches -> "This QR code does not match this case. Scan the QR shown for this report first."
                    else -> null
                },
                notice = if (matches) "QR verified for this case" else null,
            )
        }
    }

    /** Called by the UI when the scanned QR's two-minute window runs out. */
    fun onQrExpired() {
        _uiState.update {
            if (!it.qrVerified) {
                it
            } else {
                it.copy(
                    qrVerified = false,
                    qrExpiresAt = null,
                    qrExpired = true,
                    error = "The scanned QR code expired after 2 minutes. Ask the farmer to refresh it and scan again.",
                )
            }
        }
    }

    fun onAssessmentSelected(assessment: String) {
        _uiState.update { it.copy(assessment = assessment) }
    }

    fun onAssessmentTextChanged(text: String) {
        _uiState.update { it.copy(assessmentText = text) }
    }

    /**
     * Records a location provided by the device's location provider. There is
     * deliberately no setter that accepts typed coordinates: the visit distance
     * is proof of physical presence, so a manually entered latitude/longitude
     * would make the check trivially bypassable.
     */
    fun onLocationFetched(
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double? = null,
        isMock: Boolean = false,
        capturedAt: Long = System.currentTimeMillis(),
    ) {
        val accuracy = accuracyMeters ?: Double.POSITIVE_INFINITY
        when {
            isMock -> _uiState.update {
                it.copy(
                    latitudeText = "",
                    longitudeText = "",
                    locationAccuracyMeters = null,
                    locationCapturedAt = null,
                    locationIsMock = true,
                    locationError = "Mock location detected. Disable fake GPS and use your real device location.",
                )
            }
            accuracyMeters == null -> _uiState.update {
                it.copy(
                    latitudeText = "",
                    longitudeText = "",
                    locationAccuracyMeters = null,
                    locationCapturedAt = null,
                    locationIsMock = false,
                    locationError = "Location accuracy is unknown. Turn on precise location and try again.",
                )
            }
            accuracy > CaseDetailUiState.LOCATION_MAX_ACCURACY_M -> _uiState.update {
                it.copy(
                    latitudeText = "",
                    longitudeText = "",
                    locationAccuracyMeters = accuracyMeters,
                    locationCapturedAt = null,
                    locationIsMock = false,
                    locationError = "Location is too imprecise (±${accuracy.roundToInt()} m). Move outdoors and try again.",
                )
            }
            else -> _uiState.update {
                it.copy(
                    latitudeText = latitude.toString(),
                    longitudeText = longitude.toString(),
                    locationAccuracyMeters = accuracyMeters,
                    locationCapturedAt = capturedAt,
                    locationIsMock = false,
                    locationError = null,
                )
            }
        }
    }

    fun onLocationError(message: String) {
        _uiState.update {
            it.copy(
                latitudeText = "",
                longitudeText = "",
                locationCapturedAt = null,
                locationError = message,
            )
        }
    }

    fun submitVisit() {
        val state = _uiState.value
        if (!state.canSubmitVisit) return
        val report = state.report ?: return
        val visitId = UUID.randomUUID().toString()
        val vetId = SessionManager.uid ?: return
        val assessmentText = state.assessmentText
        val qrCodeId = state.scannedQrCodeId ?: return
        val assessment = state.assessment ?: return
        // Coordinates can only come from a fresh device fix; see hasFreshDeviceLocation.
        val latitude = state.latitudeText.toDoubleOrNull() ?: return
        val longitude = state.longitudeText.toDoubleOrNull() ?: return
        val resolvedAt = System.currentTimeMillis()
        val resolutionNote = assessmentText.trim().takeIf { it.isNotBlank() }

        viewModelScope.launch {
            _uiState.update { it.copy(isSubmittingVisit = true, error = null) }
            runCatching {
                val payload = JSONObject().apply {
                    put("visitId", visitId)
                    put("reportId", report.id)
                    put("scannedQrCodeId", qrCodeId)
                    put("latitude", latitude)
                    put("longitude", longitude)
                    put("assessment", assessment)
                    put("resolutionNote", resolutionNote ?: JSONObject.NULL)
                }
                val sessionToken = SessionManager.sessionToken ?: throw IOException("Not signed in")
                val connection = URL("${BuildConfig.API_BASE_URL}/api/v1/pashu-health/visits")
                    .openConnection() as HttpURLConnection
                try {
                    connection.requestMethod = "POST"
                    connection.connectTimeout = 15_000
                    connection.readTimeout = 30_000
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/json")
                    connection.setRequestProperty("X-App-Key", BuildConfig.APP_API_KEY)
                    connection.setRequestProperty("Idempotency-Key", visitId)
                    connection.setRequestProperty("Authorization", "Bearer $sessionToken")
                    connection.outputStream.use { it.write(payload.toString().toByteArray(Charsets.UTF_8)) }
                    val code = connection.responseCode
                    if (code !in 200..299) {
                        val body = connection.errorStream?.bufferedReader()?.use { it.readText() }.orEmpty()
                        // A 409 qr_mismatch/qr_expired means no QR verification
                        // happened, so the report status, local verification row
                        // and farmer alert are left untouched; show the friendly
                        // QR error instead.
                        val parsed = runCatching { JSONObject(body) }.getOrNull()
                        when (parsed?.optString("error")) {
                            "qr_expired" -> throw IOException(
                                "This QR code expired. Ask the farmer to refresh it and scan again."
                            )
                            "qr_mismatch" -> throw IOException("QR code did not match this animal")
                        }
                        throw IOException("POST /visits failed (HTTP $code): $body")
                    }
                    val body = connection.inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(body)
                    val matched = json.optJSONObject("visit")?.optInt("matched", 0) == 1 ||
                        json.optBoolean("matched", false)
                    if (!matched) {
                        throw IOException("QR code did not match this report — verification failed")
                    }
                    // Update report status with vet_assessment and assigned_vet_id
                    reportRepository.update(
                        report.copy(
                            status = ReportStatus.RESOLVED,
                            vetAssessment = assessmentText,
                            assignedVetId = vetId,
                            synced = false,
                            qrVerified = true,
                            verifiedAt = resolvedAt,
                            verifiedBy = vetId,
                            resolvedAt = resolvedAt,
                            resolvedBy = vetId,
                            resolutionNote = resolutionNote,
                        )
                    )
                    SyncScheduler.triggerNow(ServiceLocator.context)
                    runCatching {
                        reportRepository.insertVisitVerification(
                            reportId = report.id,
                            scannedQrCodeId = qrCodeId,
                            latitude = latitude,
                            longitude = longitude,
                            assessment = assessmentText.ifBlank { assessment },
                            matched = 1,
                        )
                    }
                    val animalLabel = state.animal?.let { "${it.name} (${it.species})" }
                        ?: "Animal ${report.animalId.take(8)}"
                    alertRepository.insert(
                        Alert(
                            recipientRole = "farmer",
                            recipientId = report.farmerId,
                            message = "Visit verified and case resolved for $animalLabel. " +
                                "Assessment: $assessmentText.",
                        ),
                    )
                    _uiState.update {
                        it.copy(
                            isSubmittingVisit = false,
                            notice = "Visit verified — case resolved",
                            report = report.copy(
                                status = ReportStatus.RESOLVED,
                                vetAssessment = assessmentText,
                                assignedVetId = vetId,
                                qrVerified = true,
                                verifiedAt = resolvedAt,
                                verifiedBy = vetId,
                                resolvedAt = resolvedAt,
                                resolvedBy = vetId,
                                resolutionNote = resolutionNote,
                            ),
                        )
                    }
                } finally {
                    connection.disconnect()
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isSubmittingVisit = false,
                        error = error.message ?: "Visit verification failed",
                    )
                }
            }
        }
    }

    fun clearNotice() {
        _uiState.update { it.copy(notice = null) }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
