// Alle Plugins einmal hier laden, damit Kotlin- und Android-Plugin im selben
// Classloader liegen. Ohne Android SDK wird stattdessen
// build-ohne-android.gradle.kts verwendet (siehe settings.gradle.kts).
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
