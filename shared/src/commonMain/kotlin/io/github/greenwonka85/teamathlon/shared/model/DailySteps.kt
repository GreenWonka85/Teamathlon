package io.github.greenwonka85.teamathlon.shared.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Schrittzahl eines Tages aus einer Quelle. Gespeichert wird nur die
 * Tagessumme, keine Uhrzeiten und keine Strecken.
 *
 * Schritte bilden eine eigene Wertung und zählen nicht zu den
 * Punkten der Sportarten, da auch beim Laufen Schritte entstehen.
 */
@Serializable
data class DailySteps(
    val source: ActivitySource,
    /** Kalendertag im Format JJJJ-MM-TT, in der Zeitzone des Nutzers. */
    val date: String,
    val steps: Long,
    @SerialName("recording_method") val recordingMethod: RecordingMethod = RecordingMethod.RECORDED,
) {
    init {
        require(DATE_PATTERN.matches(date)) { "Datum muss das Format JJJJ-MM-TT haben: $date" }
    }

    private companion object {
        val DATE_PATTERN = Regex("^\\d{4}-\\d{2}-\\d{2}$")
    }
}
