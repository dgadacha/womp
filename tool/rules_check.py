#!/usr/bin/env python3
"""Vérifie les règles Firestore contre l'émulateur local.

Lancer d'abord :  firebase emulators:start --project demo-womp --only auth,firestore
Puis :            python3 tool/rules_check.py
"""
import json
import sys
import urllib.error
import urllib.request

AUTH = "http://localhost:9199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo"
BASE = "http://localhost:8180/v1"
ROOT = "projects/demo-womp/databases/(default)/documents"

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

    check("B ajoute C à la bande à sa place", join(b, tb, crew, as_uid=c), False)

    check("B rejoint la bande", join(b, tb, crew), True)
    check("B, membre, lit la bande", get(tb, f"crews/{crew}"), True)
    check("B change son propre prénom", commit(tb, write(f"crews/{crew}", {"names": {b: "Bob"}}, exists=True, mask=[f"names.`{b}`"])), True)
    check("B change le prénom de A", commit(tb, write(f"crews/{crew}", {"names": {a: "Nul"}}, exists=True, mask=[f"names.`{a}`"])), False)
    check("B retire A de la bande", commit(tb, write(f"crews/{crew}", {"members": [b]}, exists=True, mask=["members"])), False)
    check("B renomme la bande", commit(tb, write(f"crews/{crew}", {"name": "Pirates"}, exists=True, mask=["name"])), False)
    check("B met un prénom de 40 lettres", commit(tb, write(f"crews/{crew}", {"names": {b: "x" * 40}}, exists=True, mask=[f"names.`{b}`"])), False)


    dares = lambda tok, value, extra=None: commit(tok, write(
        f"crews/{crew}", {"dares": value, **(extra or {})}, exists=True,
        mask=["dares"] + list((extra or {}).keys()),
    ))
    check("A, créateur, passe aux gages à boire", dares(ta, "party"), True)
    check("A revient aux gages classiques", dares(ta, "classic"), True)
    check("B, simple membre, change les gages", dares(tb, "party"), False)
    check("C, non membre, change les gages", dares(tc, "party"), False)
    check("A met un type de gages inconnu", dares(ta, "vodka"), False)
    check("A change les gages et le nom de la bande ensemble", dares(ta, "party", {"name": "Pirates"}), False)

    def live(tok, uid, rnd, base, is_open):
        return commit(tok, write(
            f"crews/{crew}/live/state", {"round": rnd, "base": base, "open": is_open, "by": uid},
            server_time="at",
        ))

    def live_score(tok, uid, rnd, value):
        return commit(tok, write(
            f"crews/{crew}/live/state/rounds/{rnd}/scores/{uid}", {"name": "Bo", "score": value},
            server_time="at",
        ))

    check("C, non membre, lance le mode instantané", live(tc, c, 1, 1, True), False)
    check("B poste un score avant toute session", live_score(tb, b, 1, 5), False)
    check("B lance le mode instantané en sautant à la manche 5", live(tb, b, 5, 5, True), False)
    check("B lance le mode instantané (manche 1)", live(tb, b, 1, 1, True), True)
    check("C, non membre, lit l'état du mode instantané", get(tc, f"crews/{crew}/live/state"), False)
    check("A poste son score de la manche 1", live_score(ta, a, 1, 12), True)
    check("A remplace son score de la manche 1", live_score(ta, a, 1, 99), False)
    check("B poste un score au nom de A", live_score(tb, a, 1, 3), False)
    check("B poste un score pour la manche 2, pas encore ouverte", live_score(tb, b, 2, 5), False)
    check("B poste un score hors bornes", live_score(tb, b, 1, 9999), False)
    check("C, non membre, poste un score de manche", live_score(tc, c, 1, 5), False)
    check("A passe au jeu suivant (manche 2)", live(ta, a, 2, 1, True), True)
    check("B poste en retard un score pour la manche 1", live_score(tb, b, 1, 5), False)
    check("B revient à la manche 1", live(tb, b, 1, 1, True), False)
    check("B saute à la manche 9", live(tb, b, 9, 1, True), False)
    check("B signe le changement au nom de A", live(tb, a, 3, 1, True), False)
    check("B termine la session", live(tb, b, 2, 1, False), True)
    check("A poste un score après la fin de la session", live_score(ta, a, 2, 5), False)
    check("A relance une session (manche 3)", live(ta, a, 3, 3, True), True)
    check("B lit les scores de la manche 1", get(tb, f"crews/{crew}/live/state/rounds/1/scores/{a}"), True)

    # Quitter la bande, puis y revenir.
    leave = lambda tok, members: commit(tok, write(f"crews/{crew}", {"members": members}, exists=True, mask=["members"]))
    _, doc = call("GET", f"{BASE}/{ROOT}/crews/{crew}", ta)
    members = [v["stringValue"] for v in doc["fields"]["members"]["arrayValue"]["values"]]
    check("C, non membre, « quitte » la bande", leave(tc, members), False)
    check("B retire A en même temps que lui", leave(tb, [m for m in members if m not in (a, b)]), False)
    check("B quitte la bande", leave(tb, [m for m in members if m != b]), True)
    check("B, parti, lit la bande", get(tb, f"crews/{crew}"), False)
    check("B, parti, poste un score de manche", live_score(tb, b, 3, 5), False)
    check("B revient avec le code", join(b, tb, crew), True)

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
