package io.github.greenwonka85.teamathlon.shared.scoring

import io.github.greenwonka85.teamathlon.shared.model.Ruleset
import io.github.greenwonka85.teamathlon.shared.model.Sport

/**
 * Wertungskategorien: Gesamtwertung (alle Sportarten der Challenge), jede
 * Sportart einzeln und die eigene Schritte-Wertung. Schritte zählen nicht
 * zur Gesamtwertung. Welche Kategorien eine Challenge zeigt, ergibt sich aus
 * ihrem Regelwerk, siehe [categoriesFor].
 */
enum class Category(val sport: Sport?) {
    TOTAL(null),
    SWIM(Sport.SWIM),
    BIKE(Sport.BIKE),
    RUN(Sport.RUN),
    STEPS(null),
}

/**
 * Die Kategorien, die eine Challenge anzeigt. Die Gesamtwertung erscheint
 * nur, wenn mehr als eine Sportart zählt; bei einer reinen Rad-Challenge
 * wäre sie identisch mit der Rad-Wertung.
 */
fun categoriesFor(ruleset: Ruleset): List<Category> = buildList {
    if (ruleset.sports.size > 1) add(Category.TOTAL)
    Category.entries.filter { it.sport != null && it.sport in ruleset.sports }.forEach(::add)
    if (ruleset.stepsEnabled) add(Category.STEPS)
}

/** Punkte einer Person, aufgeschlüsselt nach Sportart, und ihre Schritte. */
data class PersonScore(
    val userId: String,
    val pointsBySport: Map<Sport, Double>,
    val steps: Long = 0,
) {
    /** Wert in der Kategorie: Punkte, bei [Category.STEPS] die Schrittzahl. */
    fun points(category: Category): Double = when (category) {
        Category.TOTAL -> pointsBySport.values.sum()
        Category.STEPS -> steps.toDouble()
        else -> pointsBySport[category.sport] ?: 0.0
    }
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
