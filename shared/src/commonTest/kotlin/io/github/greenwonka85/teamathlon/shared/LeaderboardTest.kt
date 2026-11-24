package io.github.greenwonka85.teamathlon.shared

import io.github.greenwonka85.teamathlon.shared.model.Sport
import io.github.greenwonka85.teamathlon.shared.scoring.Category
import io.github.greenwonka85.teamathlon.shared.scoring.Leaderboard
import io.github.greenwonka85.teamathlon.shared.scoring.PersonScore
import io.github.greenwonka85.teamathlon.shared.scoring.RankedEntry
import kotlin.test.Test
import kotlin.test.assertEquals

class LeaderboardTest {
    private val scores = listOf(
        PersonScore("anna", mapOf(Sport.RUN to 50.0, Sport.SWIM to 30.0)),
        PersonScore("ben", mapOf(Sport.BIKE to 80.0)),
        PersonScore("cem", mapOf(Sport.RUN to 20.0)),
        PersonScore("dora", mapOf(Sport.BIKE to 60.0, Sport.RUN to 20.0)),
    )

    @Test
    fun totalCategorySumsAllSportsAndSharesRanksOnTies() {
        assertEquals(
            listOf(
                RankedEntry("anna", 80.0, 1),
                RankedEntry("ben", 80.0, 1),
                RankedEntry("dora", 80.0, 1),
                RankedEntry("cem", 20.0, 4),
            ),
            Leaderboard.rankPersons(scores, Category.TOTAL),
        )
    }

    @Test
    fun sportCategoryCountsOnlyThatSport() {
        val run = Leaderboard.rankPersons(scores, Category.RUN)
        assertEquals("anna", run.first().id)
        assertEquals(0.0, run.first { it.id == "ben" }.points)
    }

    @Test
    fun teamsAreRankedByAveragePerMemberSoSmallTeamsAreNotDisadvantaged() {
        val teams = mapOf(
            "klein" to listOf("anna", "ben"),             // (80 + 80) / 2 = 80
            "gross" to listOf("cem", "dora", "neu"),      // (20 + 80 + 0) / 3 = 33,3
        )
        val ranked = Leaderboard.rankTeams(teams, scores, Category.TOTAL)
        assertEquals(listOf("klein", "gross"), ranked.map { it.id })
        assertEquals(100.0 / 3, ranked[1].points, 1e-9)
    }
}
