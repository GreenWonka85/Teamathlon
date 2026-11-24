package io.github.greenwonka85.teamathlon.shared.scoring

import io.github.greenwonka85.teamathlon.shared.model.ActivityStatus
import io.github.greenwonka85.teamathlon.shared.model.DailySteps
import io.github.greenwonka85.teamathlon.shared.model.Ruleset

/**
 * Schritte-Wertung.
 *
 * Viele Uhren schreiben ihre Schritte zusätzlich in Health Connect oder
 * HealthKit. Damit nichts doppelt zählt, gilt je Tag nur der höchste Wert
 * aller Quellen, nicht die Summe.
 *
 * Diese Regel ist identisch mit der Datenbankfunktion
 * `public.leaderboard_persons` in `server/supabase/migrations`.
 */
object Steps {
    /** Gezählte Schritte je Tag (Datum zu Schrittzahl), nur gültige Einträge. */
    fun countedPerDay(entries: List<DailySteps>, ruleset: Ruleset = Ruleset.DEFAULT): Map<String, Long> =
        entries
            .filter { ActivityCheck.check(it, ruleset).status == ActivityStatus.VALID }
            .groupBy { it.date }
            .mapValues { (_, days) -> days.maxOf { it.steps } }

    /** Summe der gezählten Schritte im Zeitraum [fromDate, toDate] (beide inklusive, JJJJ-MM-TT). */
    fun total(
        entries: List<DailySteps>,
        fromDate: String,
        toDate: String,
        ruleset: Ruleset = Ruleset.DEFAULT,
    ): Long {
        if (!ruleset.stepsEnabled) return 0
        return countedPerDay(entries, ruleset)
            .filterKeys { it in fromDate..toDate }
            .values
            .sum()
    }
}
