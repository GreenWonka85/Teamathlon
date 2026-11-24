package io.github.greenwonka85.teamathlon.shared.scoring

import io.github.greenwonka85.teamathlon.shared.model.Sport

/** Wertungskategorien: Triathlon (alle Sportarten) und jede Sportart einzeln. */
enum class Category(val sport: Sport?) {
    TRIATHLON(null),
    SWIM(Sport.SWIM),
    BIKE(Sport.BIKE),
    RUN(Sport.RUN),
}

/** Punkte einer Person, aufgeschlüsselt nach Sportart. */
data class PersonScore(val userId: String, val pointsBySport: Map<Sport, Double>) {
    fun points(category: Category): Double =
        if (category.sport == null) pointsBySport.values.sum() else pointsBySport[category.sport] ?: 0.0
}

data class RankedEntry(val id: String, val points: Double, val rank: Int)

/**
 * Ranglisten für Personen und Teams.
 *
 * Teams werden nach dem Durchschnitt je Mitglied gewertet, damit kleine
 * Teams nicht benachteiligt sind. Mitglieder ohne Punkte zählen mit 0.
 * Gleiche Punktzahl ergibt den gleichen Platz (1, 2, 2, 4).
 */
object Leaderboard {
    fun rankPersons(scores: List<PersonScore>, category: Category): List<RankedEntry> =
        rank(scores.associate { it.userId to it.points(category) })

    fun rankTeams(
        teamMembers: Map<String, List<String>>,
        scores: List<PersonScore>,
        category: Category,
    ): List<RankedEntry> {
        val byUser = scores.associateBy { it.userId }
        val averages = teamMembers.mapValues { (_, members) ->
            if (members.isEmpty()) 0.0
            else members.sumOf { byUser[it]?.points(category) ?: 0.0 } / members.size
        }
        return rank(averages)
    }

    private fun rank(points: Map<String, Double>): List<RankedEntry> {
        val sorted = points.entries.sortedWith(compareByDescending<Map.Entry<String, Double>> { it.value }.thenBy { it.key })
        var previous: Double? = null
        var rank = 0
        return sorted.mapIndexed { index, entry ->
            if (entry.value != previous) {
                rank = index + 1
                previous = entry.value
            }
            RankedEntry(entry.key, entry.value, rank)
        }
    }
}
