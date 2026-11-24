package io.github.greenwonka85.teamathlon.android.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/** Farben aus den Design-Screens. */
object TeamathlonColors {
    val Primary = Color(0xFF0B4F9C)
    val Swim = Color(0xFF2F6FD6)
    val Bike = Color(0xFFE8833A)
    val Run = Color(0xFF2E9E5B)
    val Background = Color(0xFFF4F6FA)
    val SurfaceVariant = Color(0xFFE9EDF3)
}

private val LightColors = lightColorScheme(
    primary = TeamathlonColors.Primary,
    onPrimary = Color.White,
    background = TeamathlonColors.Background,
    surface = Color.White,
    surfaceVariant = TeamathlonColors.SurfaceVariant,
)

@Composable
fun TeamathlonTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LightColors, content = content)
}
