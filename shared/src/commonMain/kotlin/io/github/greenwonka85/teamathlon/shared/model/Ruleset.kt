package io.github.greenwonka85.teamathlon.shared.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Regelwerk einer Challenge. Der Organisator wählt frei, was zählt: jede
 * Kombination aus Schwimmen, Rad und Lauf, mit oder ohne Schritte, also auch
 * eine reine Rad-, Lauf-, Schwimm- oder Schritte-Challenge.
 * Wird als JSON in der Datenbank gespeichert,
 * damit der Admin es je Challenge anpassen kann.
 */
@Serializable
data class Ruleset(
    /** Version des Regelwerks, wird an jedem Punkteeintrag gespeichert. */
    val version: Int = 1,
    /** Sportarten, die in dieser Challenge zählen. Leer bei einer reinen Schritte-Challenge. */
    val sports: Set<Sport> = Sport.entries.toSet(),
    /** Ob Indoor-Aktivitäten (Laufband, Ergometer) zählen. */
    @SerialName("indoor_allowed") val indoorAllowed: Boolean = true,
    /** Punkte für eine volle Normdistanz je Sportart. */
    @SerialName("points_per_norm_distance") val pointsPerNormDistance: Double = 100.0,
    /** Normdistanz je Sportart in Metern, Standard ist die Ironman-Distanz als Vergleichsmaßstab. */
    @SerialName("norm_distance_m") val normDistanceMeters: Map<Sport, Double> =
        Sport.entries.associateWith { it.ironmanDistanceMeters },
    /** Ab dieser Durchschnittsgeschwindigkeit (km/h) wird eine Aktivität markiert. */
    @SerialName("max_speed_kmh") val maxSpeedKmh: Map<Sport, Double> = mapOf(
        Sport.SWIM to 6.0,
        Sport.BIKE to 60.0,
        Sport.RUN to 25.0,
    ),
    /** Ob es eine eigene Schritte-Wertung gibt. Zählt nicht zu den Punkten der Sportarten. */
    @SerialName("steps_enabled") val stepsEnabled: Boolean = true,
    /** Ab dieser Tagessumme werden Schritte markiert und vom Admin geprüft. */
    @SerialName("max_daily_steps") val maxDailySteps: Long = 100_000,
) {
    init {
        require(pointsPerNormDistance > 0) { "pointsPerNormDistance muss positiv sein" }
        require(normDistanceMeters.values.all { it > 0 }) { "Normdistanzen müssen positiv sein" }
        require(maxDailySteps > 0) { "maxDailySteps muss positiv sein" }
        require(sports.isNotEmpty() || stepsEnabled) { "Mindestens eine Sportart oder die Schritte-Wertung muss aktiv sein" }
    }

    fun normDistanceFor(sport: Sport): Double =
        normDistanceMeters[sport] ?: sport.ironmanDistanceMeters

    companion object {
        /** Standard-Regelwerk: alle Sportarten, Indoor erlaubt, Schritte als eigene Wertung. */
        val DEFAULT = Ruleset()

        /** Reine Schritte-Challenge ohne Sportarten. */
        val STEPS_ONLY = Ruleset(sports = emptySet(), stepsEnabled = true)

        /** Challenge nur mit den angegebenen Sportarten, z.B. `only(Sport.BIKE)` für eine Rad-Challenge. */
        fun only(vararg sports: Sport, steps: Boolean = false): Ruleset =
            Ruleset(sports = sports.toSet(), stepsEnabled = steps)
    }
}
