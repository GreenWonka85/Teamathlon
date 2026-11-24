package io.github.greenwonka85.teamathlon.shared

import io.github.greenwonka85.teamathlon.shared.model.Activity
import io.github.greenwonka85.teamathlon.shared.model.ActivitySource
import io.github.greenwonka85.teamathlon.shared.model.Ruleset
import io.github.greenwonka85.teamathlon.shared.model.Sport
import io.github.greenwonka85.teamathlon.shared.scoring.Category
import io.github.greenwonka85.teamathlon.shared.scoring.Scoring
import io.github.greenwonka85.teamathlon.shared.scoring.categoriesFor
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Teamathlon ist keine reine Triathlon-App: jede Kombination ist eine gültige Challenge. */
class ChallengeTypesTest {
    private fun activity(sport: Sport, km: Double, minutes: Long) =
        Activity(ActivitySource.HEALTH_CONNECT, "x", sport, 0, minutes * 60, km * 1000)

    @Test
    fun bikeOnlyChallengeCountsOnlyCycling() {
        val bike = Ruleset.only(Sport.BIKE)
        assertTrue(Scoring.pointsFor(activity(Sport.BIKE, 30.0, 60), bike) > 0)
        assertEquals(0.0, Scoring.pointsFor(activity(Sport.RUN, 10.0, 50), bike))
        assertEquals(0.0, Scoring.pointsFor(activity(Sport.SWIM, 1.0, 30), bike))
        assertEquals(listOf(Category.BIKE), categoriesFor(bike))
    }

    @Test
    fun categoriesFollowTheChosenSports() {
        assertEquals(listOf(Category.RUN), categoriesFor(Ruleset.only(Sport.RUN)))
        assertEquals(listOf(Category.SWIM, Category.STEPS), categoriesFor(Ruleset.only(Sport.SWIM, steps = true)))
        assertEquals(listOf(Category.TOTAL, Category.BIKE, Category.RUN), categoriesFor(Ruleset.only(Sport.BIKE, Sport.RUN)))
        assertEquals(listOf(Category.STEPS), categoriesFor(Ruleset.STEPS_ONLY))
        assertEquals(
            listOf(Category.TOTAL, Category.SWIM, Category.BIKE, Category.RUN, Category.STEPS),
            categoriesFor(Ruleset.DEFAULT),
        )
    }
}
