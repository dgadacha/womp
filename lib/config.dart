/// Nom affiché partout. Pour renommer l'app : changer ici, puis
/// CFBundleDisplayName (ios/Runner/Info.plist) et android:label (AndroidManifest.xml).
const String appName = 'Womp';

// Aides de test, passées par --dart-define.
const bool shortRound = bool.fromEnvironment('SHORT');
const String initialName = String.fromEnvironment('NAME'); // prénom prérempli
const String initialJoin = String.fromEnvironment('JOIN'); // code de bande prérempli
const String forcedGame = String.fromEnvironment('GAME'); // snap, spot, stop ou stash ; émulateur seulement
const String forcedLocale = String.fromEnvironment('LOCALE'); // en, fr ou es ; sinon la langue du téléphone
