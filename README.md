# Teamathlon

**Die App für gemeinsame Bewegungs-Challenges.** Kolleginnen und Kollegen, Studierende oder Freundesgruppen treten als Teams oder einzeln gegeneinander an: beim Radfahren, Laufen, Schwimmen oder einfach beim Schritte zählen. Die Daten kommen automatisch von Smartwatch oder Smartphone.

Teamathlon ist kostenlos, Open Source und kommt ohne zentralen Anbieter aus: Jede Hochschule, Firma oder Gruppe betreibt ihren eigenen Server, und die Daten bleiben dort.

> Der Stand der Entwicklung: Grundgerüst, Wertung und Datenbank sind fertig, die App selbst entsteht gerade. Sie ist noch nicht in den App-Stores.

## Was kann Teamathlon?

### Jede Art von Challenge

Wer eine Challenge anlegt, wählt frei, was zählt. Einige Beispiele:

| Challenge | Was zählt |
| --- | --- |
| Mit dem Rad zur Arbeit | nur Radfahren |
| Lauf-Challenge im Frühjahr | nur Laufen |
| Schwimm-Winter | nur Schwimmen |
| 10.000 Schritte am Tag | nur Schritte |
| Sommer-Triathlon | Schwimmen, Rad und Lauf |
| Bewegt durch den Monat | alles zusammen, auch Schritte |

Niemand muss alle Sportarten betreiben. Bei einer gemischten Challenge zählt jede Sportart für sich, wer nur läuft oder nur Rad fährt, ist nicht benachteiligt.

### Ranglisten für Personen und Teams

- Eine Rangliste je Sportart und für die Schritte
- Bei mehreren Sportarten zusätzlich eine Gesamtwertung
- Teams werden nach dem Durchschnitt je Mitglied gewertet, damit kleine Teams genauso gewinnen können wie große
- Ranglisten für die ganze Challenge, je Monat und je Woche
- Abzeichen für erreichte Ziele, z.B. 100 km Rad oder eine Serie von Wochen mit Bewegung (in Planung)

### Faire Punkte

Punkte gibt es nach Distanz, ohne Obergrenze: Wer große Touren macht, wird dafür voll belohnt. Damit verschiedene Sportarten vergleichbar sind, gilt die Ironman-Distanz als Maßstab: 3,8 km Schwimmen, 180 km Rad und 42,2 km Lauf ergeben jeweils 100 Punkte. Schritte haben eine eigene Rangliste und werden nicht mit den Sportarten verrechnet.

### Automatisch und ohne Schummeln

- Aktivitäten und Schritte kommen automatisch aus **Health Connect** (Android, z.B. Samsung, Pixel, Fitbit), **Apple Health** (iPhone, Apple Watch) oder direkt von **Garmin**.
- Eine Eingabe von Hand gibt es nicht. Auch in anderen Apps nachgetragene Einträge werden nicht gezählt.
- Unrealistische Werte, etwa eine Autofahrt als Radtour, werden erkannt und vom Veranstalter geprüft.

### Einfach mitmachen

1. App installieren und den QR-Code der Organisation scannen.
2. Mit dem Konto der Hochschule oder Firma anmelden, oder per E-Mail-Link.
3. Der Challenge per QR-Code oder Link beitreten, ein Team gründen oder einem beitreten.
4. Bewegen. Alles Weitere passiert automatisch.

### Datenschutz

- Gespeichert werden nur Sportart, Datum, Dauer und Distanz sowie die Schritte je Tag. Keine GPS-Strecken, keine Herzfrequenz, kein Gewicht.
- In Ranglisten erscheint nur ein selbst gewählter Anzeigename, keine einzelnen Aktivitäten.
- Die Daten liegen ausschließlich auf dem Server der jeweiligen Organisation. Der Herausgeber der App erhält keine Daten.
- Keine Werbung, kein Tracking.

### Für Organisationen

Eine Hochschule, Firma oder Gruppe richtet ihren eigenen Teamathlon-Server ein, z.B. im Rechenzentrum, bei einem Hoster oder auf einem Raspberry Pi. Organisatoren eröffnen dort Challenges und laden per QR-Code ein. Eine Schritt-für-Schritt-Anleitung steht in [server/README.md](server/README.md).

### Verfügbarkeit

Geplant für Android (Google Play, F-Droid und als APK hier auf GitHub) und später für das iPhone. Die Android-App kommt ohne Google-Dienste aus und läuft daher auch auf Smartphones ohne Google Play.

---

## Für Entwickler

### Aufbau

| Modul | Inhalt |
| --- | --- |
| `shared/` | Gemeinsamer Kotlin-Code für Android und später iOS: Datenmodell, Regelwerk der Challenges, Punkte- und Schritte-Wertung, Plausibilitätsprüfung, Ranglisten, QR-Code-Inhalte |
| `androidApp/` | Android-App mit Jetpack Compose, ohne proprietäre Google-Bibliotheken |
| `server/` | Datenbankschema für Supabase, Einrichtungsskripte und [Anleitung für den Raspberry Pi](server/README.md) |

### Bauen und testen

Voraussetzungen: Android Studio (aktuelle Version) mit JDK 17 oder neuer. Das Projekt in Android Studio öffnen und die Konfiguration `androidApp` starten.

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
