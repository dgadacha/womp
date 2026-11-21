# Womp

Réseau social de bandes d'amis : un mini-jeu de 45 secondes par jour, identique pour tous. Le score sert de post, le dernier de la semaine prend le gage. Interface en anglais.

## Lancer

L'app parle au projet Firebase `womp-crew` (compte encheres.nc@gmail.com) : connexion anonyme et Firestore, région nam5.

```bash
flutter run
```

Pour travailler sans toucher aux vraies données, lancer l'émulateur puis l'app avec `EMULATOR=true` :

```bash
firebase emulators:start --project demo-womp --only auth,firestore
```

```bash
flutter run --dart-define=EMULATOR=true
```

Les données de l'émulateur disparaissent quand on l'arrête.

## Vérifier

```bash
flutter analyze
```

```bash
flutter test
```

Règles de sécurité Firestore, émulateur lancé :

```bash
python3 tool/rules_check.py
```

Faire entrer un faux joueur dans la bande du simulateur :

```bash
python3 tool/second_player.py Maya 12 "Al's crew"
```

## Les mini-jeux

Un seul jeu par jour, le même pour tout le monde, tiré de la date (`gameOfDay` dans `lib/core/games.dart`).

- **Snap** : des pastilles apparaissent et rétrécissent. Vert +1, jaune +3, rouge −3.
- **Spot** : une flèche pointe dans le mauvais sens. Bonne tuile +1, mauvaise −1.
- **Stop** : une barre va et vient, on la stoppe dans la zone. Centre +3, zone +1, dehors −1.

Chaque jeu a sa logique en Dart pur dans `lib/core/`, son écran dans `lib/games/`, et partage l'horloge et le cadre de `lib/games/round.dart`.

Deux contraintes à respecter pour tout nouveau jeu :
- le score doit rester entre -150 et 150, bornes des règles Firestore (`clampScore` s'en charge, un test le vérifie) ;
- ajouter un jeu à la rotation décale les jours suivants : deux versions de l'app ne joueraient plus au même jeu.

## Aides de test

- `--dart-define=SHORT=true` : manche de 6 secondes.
- `--dart-define=NAME=Al` : prénom prérempli.
- `--dart-define=JOIN=ABC234` : code de bande prérempli.
- `--dart-define=EMULATOR=true` : émulateur local au lieu du vrai projet.
- `--dart-define=GAME=spot` : force un jeu (snap, spot ou stop). Ignoré hors émulateur, pour ne pas fausser une vraie bande.

## Organisation du code

- `lib/core/game.dart` et `lib/core/games.dart` : les parties du jour, tirées de la date. Ne dépendent de rien d'autre.
- `lib/data/repo.dart` : ce que les écrans demandent au serveur. `firestore_repo.dart` pour l'app, `memory_repo.dart` pour les tests.
- `lib/ui/kit.dart` : les briques du style BD plat (carte, bouton, pastille).
- `lib/games/` : les trois mini-jeux et leur cadre commun.
- `lib/screens/` : accueil d'arrivée, jeu du jour, classement de la bande.
- `firestore.rules` : qui a le droit de lire et d'écrire quoi.

## Publier les règles et la config auth

```bash
firebase deploy --only firestore,auth --project womp-crew --account encheres.nc@gmail.com
```

Toujours lancer `python3 tool/rules_check.py` contre l'émulateur avant de publier des règles modifiées.

## Limites connues

- Le score est calculé sur le téléphone. Les règles le bornent, mais ne peuvent pas vérifier qu'il a vraiment été joué.
- Le compte est anonyme : il est perdu si l'app est désinstallée.
- Le jour est fixé au lancement de l'app, il ne change pas si elle reste ouverte après minuit.
