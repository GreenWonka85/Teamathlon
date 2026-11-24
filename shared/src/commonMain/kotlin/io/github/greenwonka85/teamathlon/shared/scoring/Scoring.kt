package io.github.greenwonka85.teamathlon.shared.scoring

import io.github.greenwonka85.teamathlon.shared.model.Activity
import io.github.greenwonka85.teamathlon.shared.model.ActivityStatus
import io.github.greenwonka85.teamathlon.shared.model.Ruleset
import io.github.greenwonka85.teamathlon.shared.model.Sport

/**
 * Punkteberechnung nach dem Regelwerk einer Challenge.
 *
 * Punkte = Punkte je Normdistanz * Distanz / Normdistanz der Sportart.
 * Im Standard ergibt eine volle Ironman-Teildistanz 100 Punkte. Das macht
 * die Sportarten untereinander vergleichbar, wenn eine Challenge mehrere enthält.
 * Es gibt keine Obergrenze: Jeder Kilometer zählt voll.
 *
 * Diese Formel ist identisch mit der Datenbankfunktion
 * `public.activity_points` in `server/supabase/migrations`.
 */
object Scoring {
    /** Punkte für eine Distanz in Metern, ohne Prüfung der Regeln. */
    fun pointsForDistance(sport: Sport, distanceMeters: Double, ruleset: Ruleset = Ruleset.DEFAULT): Double {
        if (distanceMeters <= 0.0) return 0.0
        return ruleset.pointsPerNormDistance * distanceMeters / ruleset.normDistanceFor(sport)
    }

    /**
     * Punkte einer Aktivität in einer Challenge. Liefert 0, wenn die Sportart
     * nicht zählt, Indoor nicht erlaubt ist oder die Prüfung sie nicht als
     * gültig einstuft.
     */
    fun pointsFor(activity: Activity, ruleset: Ruleset = Ruleset.DEFAULT): Double {
        if (activity.sport !in ruleset.sports) return 0.0
        if (activity.indoor && !ruleset.indoorAllowed) return 0.0
        if (ActivityCheck.check(activity, ruleset).status != ActivityStatus.VALID) {
            return 0.0
        }
        return pointsForDistance(activity.sport, activity.distanceMeters, ruleset)
    }
}
