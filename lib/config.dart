/// Nom affiché partout. Pour renommer l'app : changer ici, puis
/// CFBundleDisplayName (ios/Runner/Info.plist) et android:label (AndroidManifest.xml).
const String appName = 'Womp';

// Aides de test, passées par --dart-define.
const bool shortRound = bool.fromEnvironment('SHORT');
const String initialName = String.fromEnvironment('NAME'); // prénom prérempli
const String initialJoin = String.fromEnvironment('JOIN'); // code de bande prérempli
const String forcedGame = String.fromEnvironment('GAME'); // snap, spot, stop ou stash ; émulateur seulement
const String forcedLocale = String.fromEnvironment('LOCALE'); // en, fr ou es ; sinon la langue du téléphone

/// Nom du Pass, le même dans toutes les langues.
const String passName = 'Womp Pass';

// Clés publiques du SDK RevenueCat (Project settings > API keys). Elles n'ont rien de
// secret et partent dans l'app. Vides : pas de magasin, le Pass reste caché quoi qu'il arrive.
// Le Pass n'apparaît que si l'interrupteur `pass` du document Firestore config/app est vrai.
const String revenueCatAppleKey = String.fromEnvironment('RC_APPLE_KEY', defaultValue: '');
const String revenueCatGoogleKey = String.fromEnvironment('RC_GOOGLE_KEY', defaultValue: '');
