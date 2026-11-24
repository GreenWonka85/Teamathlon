#!/usr/bin/env python3
"""Erzeugt alle Geheimnisse und Adressen in der .env von Supabase.

Aufruf im Supabase-Verzeichnis (dort, wo docker-compose.yml liegt):

    python3 setup-env.py --url http://teamathlon-pi.local:8000

Beim ersten Lauf wird .env aus .env.example erzeugt und alle Geheimnisse
werden zufällig gesetzt. Spätere Läufe ändern nur die Adressen (mit --force
auch die Geheimnisse) und legen vorher eine Sicherung .env.bak an. Benötigt nur Python 3 ohne Zusatzpakete.
"""
import argparse
import base64
import hashlib
import hmac
import json
import secrets
import shutil
import string
import sys
import time
from pathlib import Path

ALPHABET = string.ascii_letters + string.digits


def random_text(length: int) -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(length))


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def jwt(secret: str, role: str) -> str:
    """JWT mit HS256, wie Supabase es für ANON_KEY und SERVICE_ROLE_KEY erwartet."""
    now = int(time.time())
    header = b64url(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    payload = b64url(json.dumps(
        {"role": role, "iss": "supabase", "iat": now, "exp": now + 10 * 365 * 24 * 3600},
        separators=(",", ":"),
    ).encode())
    signature = hmac.new(secret.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest()
    return f"{header}.{payload}.{b64url(signature)}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", required=True, help="Adresse, unter der die App den Server erreicht, z.B. http://teamathlon-pi.local:8000")
    parser.add_argument("--env", default=".env", help="Pfad zur .env (Standard: .env)")
    parser.add_argument("--force", action="store_true", help="Auch bereits gesetzte Geheimnisse neu erzeugen")
    args = parser.parse_args()

    env_path = Path(args.env)
    example = env_path.with_name(".env.example")
    first_run = not env_path.exists()
    if first_run:
        if not example.exists():
            print(f"{env_path} und {example} nicht gefunden. Im Supabase-Verzeichnis ausführen.", file=sys.stderr)
            return 1
        shutil.copy(example, env_path)
    else:
        shutil.copy(env_path, env_path.with_name(env_path.name + ".bak"))

    url = args.url.rstrip("/")
    addresses = {
        "SITE_URL": url,
        "API_EXTERNAL_URL": url,
        "SUPABASE_PUBLIC_URL": url,
        "DASHBOARD_USERNAME": "teamathlon",
        # Rückleitung nach dem Klick auf den Anmeldelink direkt in die App.
        "ADDITIONAL_REDIRECT_URLS": "teamathlon://login-callback",
    }
    # Geheimnisse nur beim ersten Lauf oder mit --force neu erzeugen, damit ein
    # erneuter Aufruf (z.B. für eine neue Adresse) laufende Server nicht aussperrt.
    generated = {}
    if first_run or args.force:
        jwt_secret = random_text(48)
        generated = {
            "POSTGRES_PASSWORD": random_text(32),
            "JWT_SECRET": jwt_secret,
            "ANON_KEY": jwt(jwt_secret, "anon"),
            "SERVICE_ROLE_KEY": jwt(jwt_secret, "service_role"),
            "DASHBOARD_PASSWORD": random_text(24),
            "SECRET_KEY_BASE": random_text(64),
            "VAULT_ENC_KEY": random_text(32),
            "PG_META_CRYPTO_KEY": random_text(32),
            "LOGFLARE_PUBLIC_ACCESS_TOKEN": random_text(32),
            "LOGFLARE_PRIVATE_ACCESS_TOKEN": random_text(32),
        }
    values = {**generated, **addresses}

    changed = []
    output = []
    for line in env_path.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key = line.split("=", 1)[0].strip()
            if key in values:
                line = f"{key}={values[key]}"
                changed.append(key)
        output.append(line)
    env_path.write_text("\n".join(output) + "\n")
    env_path.chmod(0o600)

    print("Geändert: " + ", ".join(changed))
    print()
    print("Zugang zum Supabase Studio:")
    print(f"  Adresse:  {url}")
    print(f"  Benutzer: {addresses['DASHBOARD_USERNAME']}")
    print("  Passwort: steht in .env unter DASHBOARD_PASSWORD")
    return 0


if __name__ == "__main__":
    sys.exit(main())
