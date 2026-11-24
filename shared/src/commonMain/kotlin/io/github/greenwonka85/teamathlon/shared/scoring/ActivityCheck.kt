package io.github.greenwonka85.teamathlon.shared.scoring

import io.github.greenwonka85.teamathlon.shared.model.Activity
import io.github.greenwonka85.teamathlon.shared.model.ActivityStatus
import io.github.greenwonka85.teamathlon.shared.model.RecordingMethod
import io.github.greenwonka85.teamathlon.shared.model.Ruleset

/** Ergebnis der Prüfung einer Aktivität mit Begründung. */
data class CheckResult(val status: ActivityStatus, val reason: Reason?) {
    enum class Reason {
        MANUAL_ENTRY,
        INVALID_VALUES,
        SPEED_TOO_HIGH,
    }
}

/**
 * Plausibilitätsprüfung, für alle Quellen identisch.
 *
 * - Von Hand nachgetragene Einträge werden verworfen.
 * - Unmögliche Werte (Distanz oder Dauer nicht positiv) werden verworfen.
 * - Unrealistisch schnelle Aktivitäten werden markiert und vom Admin geprüft.
 */
object ActivityCheck {
    fun check(activity: Activity, ruleset: Ruleset = Ruleset.DEFAULT): CheckResult {
        if (activity.recordingMethod == RecordingMethod.MANUAL) {
            return CheckResult(ActivityStatus.REJECTED, CheckResult.Reason.MANUAL_ENTRY)
        }
        if (activity.distanceMeters <= 0.0 || activity.durationSeconds <= 0L) {
            return CheckResult(ActivityStatus.REJECTED, CheckResult.Reason.INVALID_VALUES)
        }
        val limit = ruleset.maxSpeedKmh[activity.sport]
        val speed = activity.averageSpeedKmh
        if (limit != null && speed != null && speed > limit) {
            return CheckResult(ActivityStatus.FLAGGED, CheckResult.Reason.SPEED_TOO_HIGH)
        }
        return CheckResult(ActivityStatus.VALID, null)
    }
}
