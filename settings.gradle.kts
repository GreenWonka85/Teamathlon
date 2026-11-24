rootProject.name = "Teamathlon"

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

include(":shared")

// Mit -Pteamathlon.ohneAndroid=true lässt sich das gemeinsame Modul
// ohne Android SDK bauen und testen (z.B. auf einem Server).
if (providers.gradleProperty("teamathlon.ohneAndroid").orNull != "true") {
    include(":androidApp")
}
