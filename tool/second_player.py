#!/usr/bin/env python3
"""Fait entrer un faux joueur dans une bande de l'émulateur et lui fait poster un score.

Usage : python3 tool/second_player.py <prénom> <score> [nom de la bande]
"""
import sys
sys.path.insert(0, "tool")
import rules_check as rc

name, value = sys.argv[1], int(sys.argv[2])
wanted = sys.argv[3] if len(sys.argv) > 3 else "Al's crew"
# Le jeton « owner » de l'émulateur passe outre les règles : il sert à trouver la bande.
_, listing = rc.call("GET", f"{rc.BASE}/{rc.ROOT}/crews?pageSize=300", "owner")
docs = [d for d in listing.get("documents", []) if d["fields"]["name"]["stringValue"] == wanted]
doc = max(docs, key=lambda d: d["createTime"])
crew_id = doc["name"].split("/")[-1]
code = doc["fields"]["code"]["stringValue"]
uid, tok = rc.user()
print("invitation lue :", rc.get(tok, f"invites/{code}"))
print("entrée dans la bande :", rc.join(uid, tok, crew_id, name=name))
print("score posté :", rc.score(tok, crew_id, uid, value, name=name))
print("bande", crew_id, "code", code)
