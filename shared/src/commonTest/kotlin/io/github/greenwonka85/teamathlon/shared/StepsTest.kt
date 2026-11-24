package io.github.greenwonka85.teamathlon.shared

import io.github.greenwonka85.teamathlon.shared.model.Activity
import io.github.greenwonka85.teamathlon.shared.model.ActivitySource
import io.github.greenwonka85.teamathlon.shared.model.ActivityStatus
import io.github.greenwonka85.teamathlon.shared.model.DailySteps
import io.github.greenwonka85.teamathlon.shared.model.RecordingMethod
import io.github.greenwonka85.teamathlon.shared.model.Ruleset
import io.github.greenwonka85.teamathlon.shared.model.Sport
import io.github.greenwonka85.teamathlon.shared.scoring.ActivityCheck
import io.github.greenwonka85.teamathlon.shared.scoring.Category
import io.github.greenwonka85.teamathlon.shared.scoring.Leaderboard
import io.github.greenwonka85.teamathlon.shared.scoring.PersonScore
import io.github.greenwonka85.teamathlon.shared.scoring.Scoring
import io.github.greenwonka85.teamathlon.shared.scoring.Steps
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class StepsTest {
    private fun day(date: String, steps: Long, source: ActivitySource = ActivitySource.HEALTH_CONNECT, manual: Boolean = false) =
        DailySteps(source, date, steps, if (manual) RecordingMethod.MANUAL else RecordingMethod.RECORDED)

    @Test
    fun sameDayFromTwoSourcesCountsOnlyOnce() {
        val entries = listOf(
            day("2026-12-01", 8_000, ActivitySource.HEALTH_CONNECT),
            day("2026-12-01", 8_400, ActivitySource.GARMIN),
            day("2026-12-02", 5_000),
        )
        assertEquals(mapOf("2026-12-01" to 8_400L, "2026-12-02" to 5_000L), Steps.countedPerDay(entries))
        assertEquals(13_400, Steps.total(entries, "2026-12-01", "2026-12-31"))
    }

    @Test
    fun onlyDaysInsideTheChallengeCount() {
        val entries = listOf(day("2026-11-30", 9_000), day("2026-12-01", 4_000), day("2027-01-01", 7_000))
        assertEquals(4_000, Steps.total(entries, "2026-12-01", "2026-12-31"))
    }

    @Test
    fun manualAndImplausibleEntriesDoNotCount() {
        assertEquals(ActivityStatus.REJECTED, ActivityCheck.check(day("2026-12-01", 10_000, manual = true)).status)
        assertEquals(ActivityStatus.FLAGGED, ActivityCheck.check(day("2026-12-01", 150_000)).status)
        val entries = listOf(day("2026-12-01", 10_000, manual = true), day("2026-12-02", 150_000))
        assertEquals(0, Steps.total(entries, "2026-12-01", "2026-12-31"))
    }

    @Test
    fun stepsCanBeSwitchedOffPerChallenge() {
        assertEquals(0, Steps.total(listOf(day("2026-12-01", 6_000)), "2026-12-01", "2026-12-31", Ruleset(stepsEnabled = false)))
    }

    @Test
    fun invalidDateIsRejected() {
        assertFailsWith<IllegalArgumentException> { day("1.12.2026", 100) }
    }

    @Test
    fun stepsHaveOwnRankingAndDoNotAddToTriathlon() {
        val scores = listOf(
            PersonScore("geher", emptyMap(), steps = 300_000),
            PersonScore("laeufer", mapOf(Sport.RUN to 40.0), steps = 120_000),
        )
        assertEquals(listOf("geher", "laeufer"), Leaderboard.rankPersons(scores, Category.STEPS).map { it.id })
        assertEquals(0.0, scores[0].points(Category.TRIATHLON))
        assertEquals(40.0, scores[1].points(Category.TRIATHLON))
        // Teams: Durchschnitt der Schritte je Mitglied.
        val teams = Leaderboard.rankTeams(mapOf("t" to listOf("geher", "laeufer")), scores, Category.STEPS)
        assertEquals(210_000.0, teams.single().points)
    }

    @Test
    fun stepsOnlyChallengeCountsStepsButNoSports() {
        val ruleset = Ruleset.STEPS_ONLY
        assertEquals(6_000, Steps.total(listOf(day("2026-12-01", 6_000)), "2026-12-01", "2026-12-31", ruleset))
        val run = Activity(
            ActivitySource.HEALTH_CONNECT, "r", Sport.RUN, 0, 3000, 10_000.0,
        )
        assertEquals(0.0, Scoring.pointsFor(run, ruleset))
    }

    @Test
    fun challengeNeedsAtLeastOneCategory() {
        assertFailsWith<IllegalArgumentException> { Ruleset(sports = emptySet(), stepsEnabled = false) }
    }
}
