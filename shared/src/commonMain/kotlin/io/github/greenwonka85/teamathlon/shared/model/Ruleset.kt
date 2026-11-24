package io.github.greenwonka85.teamathlon.shared.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Regelwerk einer Challenge. Wird als JSON in der Datenbank gespeichert,
 * damit der Admin es je Challenge anpassen kann.
 */
@Serializable
data class Ruleset(
    /** Version des Regelwerks, wird an jedem Punkteeintrag gespeichert. */
    val version: Int = 1,
    /** Sportarten, die in dieser Challenge zählen. */
    val sports: Set<Sport> = Sport.entries.toSet(),
    /** Ob Indoor-Aktivitäten (Laufband, Ergometer) zählen. */
    @SerialName("indoor_allowed") val indoorAllowed: Boolean = true,
    /** Punkte für eine volle Normdistanz je Sportart. */
    @SerialName("points_per_norm_distance") val pointsPerNormDistance: Double = 100.0,
    /** Normdistanz je Sportart in Metern, Standard ist die Ironman-Distanz. */
    @SerialName("norm_distance_m") val normDistanceMeters: Map<Sport, Double> =
        Sport.entries.associateWith { it.ironmanDistanceMeters },
    /** Ab dieser Durchschnittsgeschwindigkeit (km/h) wird eine Aktivität markiert. */
    @SerialName("max_speed_kmh") val maxSpeedKmh: Map<Sport, Double> = mapOf(
        Sport.SWIM to 6.0,
        Sport.BIKE to 60.0,
        Sport.RUN to 25.0,
    ),
) {
    init {
        require(pointsPerNormDistance > 0) { "pointsPerNormDistance muss positiv sein" }
        require(normDistanceMeters.values.all { it > 0 }) { "Normdistanzen müssen positiv sein" }
    }

    fun normDistanceFor(sport: Sport): Double =
        normDistanceMeters[sport] ?: sport.ironmanDistanceMeters

    companion object {
        /** Standard-Regelwerk: Ironman-Normierung, alle Sportarten, Indoor erlaubt. */
        val DEFAULT = Ruleset()
    }
}
