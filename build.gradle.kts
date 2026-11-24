// Die Android-Plugins werden nur im Modul androidApp geladen, damit sich das
// gemeinsame Modul auch ohne Android SDK bauen lässt.
plugins {
    alias(libs.plugins.kotlin.multiplatform) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
