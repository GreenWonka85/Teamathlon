# Teamathlon

Open-Source-App für Triathlon-Challenges zwischen Teams an Hochschulen, in Firmen und privaten Gruppen. Jede Organisation betreibt ihren eigenen Server.

- **Drei Sportarten:** Schwimmen, Radfahren, Laufen. Niemand muss alle drei betreiben, jede Sportart zählt für sich.
- **Faire Wertung:** Punkte nach Distanz, normiert auf die Ironman-Distanz (100 Punkte je volle Teildistanz), ohne Obergrenze.
- **Keine manuelle Eingabe:** Aktivitäten kommen nur aus Health Connect, HealthKit oder Garmin.
- **Kein zentraler Dienst:** Die App verbindet sich mit dem Server der Organisation, ausgewählt per QR-Code. Die Daten bleiben dort.
- **Frei:** Keine proprietären Google-Bibliotheken, damit die App auch über F-Droid und als APK verteilt werden kann.

## Aufbau

| Modul | Inhalt |
| --- | --- |
| `shared/` | Gemeinsamer Kotlin-Code für Android und später iOS: Datenmodell, Punktewertung, Plausibilitätsprüfung, Ranglisten, QR-Code-Inhalte |
| `androidApp/` | Android-App mit Jetpack Compose |
| `server/` | Datenbankschema für Supabase, Einrichtungsskripte und [Anleitung für den Raspberry Pi](server/README.md) |

## Entwicklung

Voraussetzungen: Android Studio (aktuelle Version) mit JDK 17 oder neuer.

Das Projekt in Android Studio öffnen und die Konfiguration `androidApp` starten.

Auf der Kommandozeile:

```bash
# Tests des gemeinsamen Moduls (ohne Android SDK möglich)
./gradlew -Pteamathlon.ohneAndroid=true :shared:jvmTest

# Android-App bauen
./gradlew :androidApp:assembleDebug
```

Tests des Datenbankschemas: siehe [server/README.md](server/README.md#tests-des-datenbankschemas).

## Lizenz

Apache License 2.0, siehe [LICENSE](LICENSE).
