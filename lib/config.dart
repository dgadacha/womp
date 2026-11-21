/// Nom affiché partout. Pour renommer l'app : changer ici, puis
/// CFBundleDisplayName (ios/Runner/Info.plist) et android:label (AndroidManifest.xml).
const String appName = 'Womp';

/// Préfixe des anciens codes de défi (prototype sans serveur).
const String codePrefix = 'WOMP';

// Aides de test, passées par --dart-define.
const bool shortRound = bool.fromEnvironment('SHORT');
const String initialName = String.fromEnvironment('NAME'); // prénom prérempli
const String initialJoin = String.fromEnvironment('JOIN'); // code de bande prérempli
const String forcedGame = String.fromEnvironment('GAME'); // snap, spot ou stop ; émulateur seulement

const int roundMs = shortRound ? 6000 : 45000;
