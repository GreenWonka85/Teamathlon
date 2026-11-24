package io.github.greenwonka85.teamathlon.shared.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Die Sportarten der App. Jede Challenge wählt frei, welche davon zählen:
 * eine einzelne, mehrere oder keine (reine Schritte-Challenge).
 *
 * [ironmanDistanceMeters] ist der Vergleichsmaßstab, auf den die Punkte im
 * Standard-Regelwerk normiert werden, damit die Sportarten untereinander
 * fair vergleichbar sind.
 */
@Serializable
enum class Sport(val ironmanDistanceMeters: Double) {
    @SerialName("swim")
    SWIM(3_800.0),

    @SerialName("bike")
    BIKE(180_000.0),

    @SerialName("run")
    RUN(42_195.0),
}
