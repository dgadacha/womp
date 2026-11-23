#!/usr/bin/env python3
"""Allume ou éteint le Womp Pass sur l'émulateur local (document config/app).

    python3 tool/pass_switch.py on
    python3 tool/pass_switch.py off

En production, le même interrupteur se règle à la main dans la console Firebase :
Firestore > config > app > pass (booléen). L'app le lit à son lancement.
"""
import json
import sys
import urllib.request

URL = ("http://localhost:8180/v1/projects/demo-womp/databases/(default)/documents/config/app"
       "?updateMask.fieldPaths=pass")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("on", "off"):
        sys.exit(__doc__)
    on = sys.argv[1] == "on"
    body = json.dumps({"fields": {"pass": {"booleanValue": on}}}).encode()
    req = urllib.request.Request(URL, data=body, method="PATCH")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", "Bearer owner")  # passe outre les règles, comme la console
    with urllib.request.urlopen(req, timeout=10):
        pass
    print(f"Womp Pass {'allumé' if on else 'éteint'} sur l'émulateur. Relancer l'app pour le voir.")


if __name__ == "__main__":
    main()
