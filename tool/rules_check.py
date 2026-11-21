#!/usr/bin/env python3
"""Vérifie les règles Firestore contre l'émulateur local.

Lancer d'abord :  firebase emulators:start --project demo-womp --only auth,firestore
Puis :            python3 tool/rules_check.py
"""
import json
import sys
import urllib.error
import urllib.request
from datetime import date

AUTH = "http://localhost:9199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo"
BASE = "http://localhost:8180/v1"
ROOT = "projects/demo-womp/databases/(default)/documents"
TODAY = date.today().isoformat()

results = []


def call(method, url, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def user():
    _, d = call("POST", AUTH, body={"returnSecureToken": True})
    return d["localId"], d["idToken"]


def val(v):
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, list):
        return {"arrayValue": {"values": [val(x) for x in v]}}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: val(x) for k, x in v.items()}}}
    raise TypeError(v)


def write(path, fields, *, exists=None, mask=None, server_time=None, append=None):
    w = {"update": {"name": f"{ROOT}/{path}", "fields": {k: val(v) for k, v in fields.items()}}}
    if exists is not None:
        w["currentDocument"] = {"exists": exists}
    if mask is not None:
        w["updateMask"] = {"fieldPaths": mask}
    transforms = []
    if server_time:
        transforms.append({"fieldPath": server_time, "setToServerValue": "REQUEST_TIME"})
    if append:
        transforms.append({"fieldPath": append[0], "appendMissingElements": {"values": [val(append[1])]}})
    if transforms:
        w["updateTransforms"] = transforms
    return w


def commit(token, *writes):
    return call("POST", f"{BASE}/{ROOT}:commit", token, {"writes": list(writes)})[0]


def get(token, path):
    return call("GET", f"{BASE}/{ROOT}/{path}", token)[0]


def check(label, status, allowed):
    ok = (status == 200) == allowed
    results.append(ok)
    want = "permis" if allowed else "refusé"
    print(f"{'OK  ' if ok else 'ÉCHEC'} {label} — attendu {want}, reçu HTTP {status}")


def new_crew(uid, tok, code, name="Al"):
    crew_id = f"crew_{code}"
    crew = {"name": f"{name}'s crew", "code": code, "members": [uid], "names": {uid: name}, "createdBy": uid}
    status = commit(
        tok,
        write(f"crews/{crew_id}", crew, exists=False, server_time="createdAt"),
        write(f"invites/{code}", {"crewId": crew_id}, exists=False),
        write(f"users/{uid}", {"crewId": crew_id, "name": name}),
    )
    return crew_id, status


def join(uid, tok, crew_id, name="Bo", as_uid=None):
    who = as_uid or uid
    return commit(tok, write(
        f"crews/{crew_id}", {"names": {who: name}}, exists=True,
        mask=[f"names.`{who}`"], append=("members", who),
    ))


def score(tok, crew_id, uid, value, day=TODAY, name="Bo"):
    return commit(tok, write(
        f"crews/{crew_id}/days/{day}/scores/{uid}", {"name": name, "score": value},
        server_time="at",
    ))


def main():
    import random
    code = "".join(random.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(6))
    a, ta = user()
    b, tb = user()
    c, tc = user()

    crew, st = new_crew(a, ta, code)
    check("A crée sa bande, son invitation et son profil", st, True)
    check("A lit sa bande", get(ta, f"crews/{crew}"), True)
    check("B, non membre, lit la bande", get(tb, f"crews/{crew}"), False)
    check("B lit l'invitation par son code", get(tb, f"invites/{code}"), True)
    check("B liste toutes les invitations", get(tb, "invites"), False)
    check("B liste toutes les bandes", get(tb, "crews"), False)
    check("Sans compte, lecture de l'invitation", get(None, f"invites/{code}"), False)
    check("B crée une invitation vers la bande de A", commit(tb, write("invites/ZZZZ22", {"crewId": crew}, exists=False)), False)
    check("B réécrit l'invitation de A", commit(tb, write(f"invites/{code}", {"crewId": "ailleurs"})), False)
    check("B lit le profil de A", get(tb, f"users/{a}"), False)

    check("C, non membre, lit les scores", get(tc, f"crews/{crew}/days/{TODAY}/scores/{a}"), False)
    check("C, non membre, poste un score", score(tc, crew, c, 5), False)
    check("B ajoute C à la bande à sa place", join(b, tb, crew, as_uid=c), False)

    check("B rejoint la bande", join(b, tb, crew), True)
    check("B, membre, lit la bande", get(tb, f"crews/{crew}"), True)
    check("B change son propre prénom", commit(tb, write(f"crews/{crew}", {"names": {b: "Bob"}}, exists=True, mask=[f"names.`{b}`"])), True)
    check("B change le prénom de A", commit(tb, write(f"crews/{crew}", {"names": {a: "Nul"}}, exists=True, mask=[f"names.`{a}`"])), False)
    check("B retire A de la bande", commit(tb, write(f"crews/{crew}", {"members": [b]}, exists=True, mask=["members"])), False)
    check("B renomme la bande", commit(tb, write(f"crews/{crew}", {"name": "Pirates"}, exists=True, mask=["name"])), False)
    check("B met un prénom de 40 lettres", commit(tb, write(f"crews/{crew}", {"names": {b: "x" * 40}}, exists=True, mask=[f"names.`{b}`"])), False)

    check("B poste un score hors bornes (9999)", score(tb, crew, b, 9999), False)
    check("B poste un score pour un jour passé", score(tb, crew, b, 5, day="2020-01-01"), False)
    check("B poste un score pour un jour futur", score(tb, crew, b, 5, day="2099-01-01"), False)
    check("B poste un score au nom de A", score(tb, crew, a, 5), False)
    check("B poste son score du jour", score(tb, crew, b, 17), True)
    check("B remplace son score du jour", score(tb, crew, b, 60), False)
    check("A lit le score de B", get(ta, f"crews/{crew}/days/{TODAY}/scores/{b}"), True)

    react = f"crews/{crew}/days/{TODAY}/reactions"
    check("B pose ses réactions", commit(tb, write(f"{react}/{b}", {"picks": [f"{a}|🔥"]})), True)
    check("B écrit les réactions de A", commit(tb, write(f"{react}/{a}", {"picks": ["x"]})), False)
    check("B pose 41 réactions", commit(tb, write(f"{react}/{b}", {"picks": [str(i) for i in range(41)]})), False)
    check("C, non membre, lit les réactions", get(tc, f"{react}/{b}"), False)

    full_code = "".join(random.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(6))
    owner, towner = user()
    full, _ = new_crew(owner, towner, full_code)
    joined = []
    for _ in range(11):
        u, t = user()
        joined.append(join(u, t, full))
    check("11 joueurs rejoignent une bande (12 membres)", 200 if all(s == 200 for s in joined) else 403, True)
    u13, t13 = user()
    check("Un 13e joueur rejoint la bande pleine", join(u13, t13, full), False)

    bad = sum(1 for r in results if not r)
    print(f"\n{len(results) - bad} / {len(results)} vérifications conformes")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
