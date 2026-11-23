#!/usr/bin/env python3
"""Fait entrer un faux joueur dans une bande de l'émulateur et lui fait jouer la manche
en cours du mode instantané.

Usage : python3 tool/live_player.py <prénom> <score> [nom de la bande]
"""
import sys
sys.path.insert(0, "tool")
import rules_check as rc

name, value = sys.argv[1], int(sys.argv[2])
wanted = sys.argv[3] if len(sys.argv) > 3 else "Maya's crew"
# Le jeton « owner » de l'émulateur passe outre les règles : il sert à trouver la bande.
_, listing = rc.call("GET", f"{rc.BASE}/{rc.ROOT}/crews?pageSize=300", "owner")
docs = [d for d in listing.get("documents", []) if d["fields"]["name"]["stringValue"] == wanted]
doc = max(docs, key=lambda d: d["createTime"])
crew_id = doc["name"].split("/")[-1]
_, state = rc.call("GET", f"{rc.BASE}/{rc.ROOT}/crews/{crew_id}/live/state", "owner")
rnd = int(state["fields"]["round"]["integerValue"])
uid, tok = rc.user()
print("entrée dans la bande :", rc.join(uid, tok, crew_id, name=name))
print(f"score de la manche {rnd} :", rc.commit(tok, rc.write(
    f"crews/{crew_id}/live/state/rounds/{rnd}/scores/{uid}", {"name": name, "score": value},
    server_time="at",
)))
