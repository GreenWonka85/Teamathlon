# Teamathlon-Server auf einem Raspberry Pi 5

Diese Anleitung richtet einen Teamathlon-Server mit Supabase auf einem Raspberry Pi 5 ein. Sie ist für die Entwicklung und für Tests im eigenen Netz gedacht. Der Zugang aus dem Internet mit HTTPS folgt in einer eigenen Anleitung.

Der Server läuft vollständig in Docker. Derselbe Aufbau funktioniert später auch auf einem Server im Rechenzentrum oder bei einem Hoster.

## Inhalt dieses Verzeichnisses

| Pfad | Inhalt |
| --- | --- |
| `supabase/migrations/` | Datenbankschema mit Zugriffsregeln, Punkteberechnung, Einladungen und Ranglisten |
| `scripts/setup-env.py` | Erzeugt alle Passwörter und Schlüssel für Supabase |
| `scripts/apply-migrations.sh` | Spielt das Datenbankschema ein |
| `tests/` | Automatische Tests des Datenbankschemas |

## 1. Hardware

- Raspberry Pi 5 mit 8 GB RAM
- NVMe-Aufsatz (M.2 HAT) mit einer SSD ab 256 GB
- Offizielles 27-W-Netzteil
- Aktiver Kühler und ein passendes Gehäuse
- Netzwerkkabel zum Router

## 2. Betriebssystem aufspielen

1. Auf dem PC den [Raspberry Pi Imager](https://www.raspberrypi.com/software/) installieren.
2. Die SSD per USB-Adapter an den PC anschließen. Alternativ zuerst auf eine SD-Karte schreiben und später umziehen.
3. Im Imager wählen: Gerät **Raspberry Pi 5**, Betriebssystem **Raspberry Pi OS (other) > Raspberry Pi OS Lite (64-bit)**, Speicher **die SSD**.
4. Bei den Einstellungen festlegen:
   - Hostname: `teamathlon-pi`
   - Benutzername und ein sicheres Passwort
   - Zeitzone und Tastaturlayout
   - Unter **Dienste**: SSH aktivieren
5. Schreiben, SSD in den NVMe-Aufsatz einbauen, Netzwerkkabel und Netzteil anschließen.

Falls der Pi nicht von der SSD startet: einmal mit einer SD-Karte starten, `sudo raspi-config` aufrufen und unter **Advanced Options > Boot Order** den Start von NVMe wählen.

## 3. Feste IP-Adresse vergeben

Im Router (z.B. FRITZ!Box unter **Heimnetz > Netzwerk**) dem Gerät `teamathlon-pi` immer dieselbe IP-Adresse zuweisen. Im Folgenden steht `192.168.178.40` als Beispiel, bitte durch die eigene Adresse ersetzen.

Die App erreicht den Server über diese Adresse. Unverschlüsseltes `http` erlaubt die App nur für Adressen im lokalen Netz.

## 4. Anmelden und System aktualisieren

Auf dem PC ein Terminal öffnen (Windows: PowerShell):

```bash
ssh benutzername@192.168.178.40
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y git
sudo reboot
```

## 5. Docker installieren

Nach dem Neustart wieder per SSH anmelden:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
exit
```

Erneut per SSH anmelden, damit die Gruppenzuordnung greift, und prüfen:

```bash
docker run --rm hello-world
```

## 6. Teamathlon und Supabase herunterladen

```bash
git clone https://github.com/GreenWonka85/Teamathlon.git ~/teamathlon
git clone --depth 1 https://github.com/supabase/supabase.git ~/supabase-quelle
mkdir ~/supabase
cp -r ~/supabase-quelle/docker/. ~/supabase/
```

## 7. Supabase einrichten

Das Skript erzeugt alle Passwörter und Schlüssel und trägt die Serveradresse ein:

```bash
cd ~/supabase
python3 ~/teamathlon/server/scripts/setup-env.py --url http://192.168.178.40:8000
```

Die Datei `~/supabase/.env` enthält danach alle Geheimnisse. Sie darf nicht weitergegeben werden. Eine Sicherungskopie an einem sicheren Ort ist sinnvoll.

### E-Mail-Versand für den Anmeldelink

Teilnehmer melden sich per E-Mail-Link ohne Passwort an. Dafür braucht der Server ein E-Mail-Konto zum Versenden. In `~/supabase/.env` diese Werte eintragen (die Angaben stehen beim E-Mail-Anbieter unter SMTP):

```
SMTP_ADMIN_EMAIL=teamathlon@ihre-domain.de
SMTP_HOST=smtp.ihr-anbieter.de
SMTP_PORT=587
SMTP_USER=teamathlon@ihre-domain.de
SMTP_PASS=passwort-des-postfachs
SMTP_SENDER_NAME=Teamathlon
```

## 8. Supabase starten

```bash
cd ~/supabase
docker compose pull
docker compose up -d
```

Der erste Start dauert einige Minuten. Mit `docker compose ps` prüfen, dass alle Dienste den Status `healthy` oder `running` haben.

## 9. Datenbankschema einspielen

```bash
cd ~/supabase
~/teamathlon/server/scripts/apply-migrations.sh
```

Das Skript merkt sich, was bereits eingespielt ist, und kann nach jedem Update erneut aufgerufen werden.

## 10. Supabase Studio öffnen

Im Browser auf dem PC `http://192.168.178.40:8000` öffnen. Benutzer ist `teamathlon`, das Passwort steht in `~/supabase/.env` unter `DASHBOARD_PASSWORD`:

```bash
grep DASHBOARD_PASSWORD ~/supabase/.env
```

## 11. Organisatoren festlegen

Challenges eröffnen nur Organisatoren. Nachdem sich eine Person einmal in der App angemeldet hat, im Studio unter **SQL Editor** ausführen:

```sql
update public.profiles
set is_organizer = true
where id = (select id from auth.users where email = 'name@beispiel.de');
```

## Pflege

**Updates von Teamathlon:**

```bash
cd ~/teamathlon && git pull
cd ~/supabase && ~/teamathlon/server/scripts/apply-migrations.sh
```

**Datensicherung der Datenbank:**

```bash
cd ~/supabase
docker compose exec -T db pg_dump -U postgres -d postgres > ~/teamathlon-sicherung-$(date +%F).sql
```

**Neustart nach Stromausfall:** Die Dienste starten automatisch mit, da Supabase sie mit `restart: unless-stopped` anlegt.

## Sicherheit

- Port 8000 im Router **nicht** freigeben. Für den Zugang aus dem Internet folgt eine Anleitung mit HTTPS über einen Reverse Proxy.
- Die Datei `.env` enthält alle Schlüssel. Wer sie hat, hat vollen Zugriff auf die Datenbank.
- Das System regelmäßig aktualisieren: `sudo apt update && sudo apt full-upgrade -y`.

## Tests des Datenbankschemas

Die Tests laufen gegen ein leeres PostgreSQL 15 oder neuer, nicht gegen den laufenden Server:

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres server/tests/run.sh
```

Sie laufen auch automatisch bei jedem Pull Request auf GitHub.
