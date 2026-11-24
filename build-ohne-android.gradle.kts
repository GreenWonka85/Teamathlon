// Wird mit -Pteamathlon.ohneAndroid=true statt build.gradle.kts verwendet,
// damit sich das gemeinsame Modul ohne Android-Plugin und SDK bauen lässt.
plugins {
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
