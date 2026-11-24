package io.github.greenwonka85.teamathlon.shared

import io.github.greenwonka85.teamathlon.shared.model.Activity
import io.github.greenwonka85.teamathlon.shared.model.ActivitySource
import io.github.greenwonka85.teamathlon.shared.model.ActivityStatus
import io.github.greenwonka85.teamathlon.shared.model.RecordingMethod
import io.github.greenwonka85.teamathlon.shared.model.Ruleset
import io.github.greenwonka85.teamathlon.shared.model.Sport
import io.github.greenwonka85.teamathlon.shared.scoring.ActivityCheck
import io.github.greenwonka85.teamathlon.shared.scoring.CheckResult
import io.github.greenwonka85.teamathlon.shared.scoring.Scoring
import kotlin.test.Test
import kotlin.test.assertEquals

class ScoringTest {
    private fun activity(
        sport: Sport,
        km: Double,
        minutes: Long,
        indoor: Boolean = false,
        method: RecordingMethod = RecordingMethod.RECORDED,
    ) = Activity(
        source = ActivitySource.HEALTH_CONNECT,
        externalId = "test",
        sport = sport,
        startedAtEpochMillis = 0,
        durationSeconds = minutes * 60,
        distanceMeters = km * 1000,
        indoor = indoor,
        recordingMethod = method,
    )

    @Test
    fun fullIronmanDistanceGives100PointsInEverySport() {
        assertEquals(100.0, Scoring.pointsFor(activity(Sport.SWIM, 3.8, 80)), 1e-9)
        assertEquals(100.0, Scoring.pointsFor(activity(Sport.BIKE, 180.0, 360)), 1e-9)
        assertEquals(100.0, Scoring.pointsFor(activity(Sport.RUN, 42.195, 240)), 1e-9)
    }

    @Test
    fun pointsPerKilometerMatchConcept() {
        assertEquals(26.3, Scoring.pointsForDistance(Sport.SWIM, 1000.0), 0.05)
        assertEquals(2.37, Scoring.pointsForDistance(Sport.RUN, 1000.0), 0.005)
        assertEquals(0.56, Scoring.pointsForDistance(Sport.BIKE, 1000.0), 0.005)
    }

    @Test
    fun noUpperLimitForLongTours() {
        // 360 km Rad in 14 Stunden: doppelte Ironman-Distanz, doppelte Punkte.
        assertEquals(200.0, Scoring.pointsFor(activity(Sport.BIKE, 360.0, 14 * 60)), 1e-9)
    }

    @Test
    fun manualEntriesAreRejectedAndScoreZero() {
        val manual = activity(Sport.RUN, 10.0, 50, method = RecordingMethod.MANUAL)
        assertEquals(CheckResult(ActivityStatus.REJECTED, CheckResult.Reason.MANUAL_ENTRY), ActivityCheck.check(manual))
        assertEquals(0.0, Scoring.pointsFor(manual))
    }

    @Test
    fun unrealisticSpeedIsFlagged() {
        // 30 km "Lauf" in einer Stunde, z.B. eine Radfahrt mit falscher Sportart.
        val tooFast = activity(Sport.RUN, 30.0, 60)
        assertEquals(ActivityStatus.FLAGGED, ActivityCheck.check(tooFast).status)
        assertEquals(0.0, Scoring.pointsFor(tooFast))
        // Autofahrt als Radtour.
        assertEquals(ActivityStatus.FLAGGED, ActivityCheck.check(activity(Sport.BIKE, 80.0, 60)).status)
        assertEquals(ActivityStatus.VALID, ActivityCheck.check(activity(Sport.BIKE, 35.0, 60)).status)
    }

    @Test
    fun invalidValuesAreRejected() {
        assertEquals(ActivityStatus.REJECTED, ActivityCheck.check(activity(Sport.SWIM, 0.0, 30)).status)
        assertEquals(ActivityStatus.REJECTED, ActivityCheck.check(activity(Sport.SWIM, 1.0, 0)).status)
    }

    @Test
    fun rulesetControlsSportsAndIndoor() {
        val runAndBikeOnly = Ruleset(sports = setOf(Sport.RUN, Sport.BIKE), indoorAllowed = false)
        assertEquals(0.0, Scoring.pointsFor(activity(Sport.SWIM, 2.0, 50), runAndBikeOnly))
        assertEquals(0.0, Scoring.pointsFor(activity(Sport.RUN, 10.0, 60, indoor = true), runAndBikeOnly))
        assertEquals(100.0 * 10 / 42.195, Scoring.pointsFor(activity(Sport.RUN, 10.0, 60), runAndBikeOnly), 1e-9)
    }
}
