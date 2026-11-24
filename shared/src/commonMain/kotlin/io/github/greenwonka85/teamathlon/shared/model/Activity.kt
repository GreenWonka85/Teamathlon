package io.github.greenwonka85.teamathlon.shared.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Herkunft einer Aktivität. */
@Serializable
enum class ActivitySource {
    @SerialName("health_connect")
    HEALTH_CONNECT,

    @SerialName("healthkit")
    HEALTHKIT,

    @SerialName("garmin")
    GARMIN,
}

/**
 * Wie eine Aktivität entstanden ist. Von Hand nachgetragene Einträge
 * (in Health Connect, HealthKit oder Garmin) werden verworfen.
 */
@Serializable
enum class RecordingMethod {
    @SerialName("recorded")
    RECORDED,

    @SerialName("manual")
    MANUAL,
}

/** Prüfstatus einer Aktivität. */
@Serializable
enum class ActivityStatus {
    /** Zählt in der Wertung. */
    @SerialName("valid")
    VALID,

    /** Auffällig, wird vom Challenge-Admin geprüft und zählt bis dahin nicht. */
    @SerialName("flagged")
    FLAGGED,

    /** Zählt nicht, z.B. weil sie von Hand nachgetragen wurde. */
    @SerialName("rejected")
    REJECTED,
}

/**
 * Eine abgeschlossene Trainingseinheit im einheitlichen Format aller Quellen.
 * Gespeichert werden nur die für die Wertung nötigen Kennzahlen, keine
 * GPS-Strecken und keine Herzfrequenz.
 */
@Serializable
data class Activity(
    val source: ActivitySource,
    @SerialName("external_id") val externalId: String,
    val sport: Sport,
    /** Startzeit in Millisekunden seit 1970-01-01 UTC. */
    @SerialName("started_at_ms") val startedAtEpochMillis: Long,
    @SerialName("duration_s") val durationSeconds: Long,
    @SerialName("distance_m") val distanceMeters: Double,
    val indoor: Boolean = false,
    @SerialName("recording_method") val recordingMethod: RecordingMethod = RecordingMethod.RECORDED,
) {
    /** Durchschnittsgeschwindigkeit in km/h, oder null bei Dauer 0. */
    val averageSpeedKmh: Double?
        get() = if (durationSeconds > 0) distanceMeters / durationSeconds * 3.6 else null
}
