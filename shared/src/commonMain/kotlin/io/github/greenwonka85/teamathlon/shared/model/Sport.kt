package io.github.greenwonka85.teamathlon.shared.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Die drei Sportarten der App. Andere Sportarten werden nicht erfasst.
 *
 * [ironmanDistanceMeters] ist die Ironman-Teildistanz, auf die die Punkte
 * im Standard-Regelwerk normiert werden.
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
