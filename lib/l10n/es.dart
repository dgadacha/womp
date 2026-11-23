import '../core/games.dart';
import '../data/repo.dart';
import 'strings.dart';

/// Español neutro, de tú.
class SEs extends S {
  const SEs();

  // ---------- Arrivée ----------
  @override
  String get tagline => 'Minijuegos con tu grupo.\nEl último cumple el reto.';
  @override
  String get firstNameLabel => 'Tu nombre';
  @override
  String get firstNameHint => 'p. ej. Maya';
  @override
  String get friendInvited => '¿Te invitó un amigo?';
  @override
  String get crewCodeLabel => 'Código del grupo';
  @override
  String get joinCrew => 'Unirme al grupo';
  @override
  String get startCrew => 'Crear mi grupo';
  @override
  String get oneSec => 'Un segundo…';
  @override
  String crewNameFor(String name) => 'Grupo de $name';
  @override
  String joinProblem(JoinProblem problem) => switch (problem) {
        JoinProblem.badCode => 'Un código de grupo tiene 6 letras y números.',
        JoinProblem.unknownCode => 'Ningún grupo tiene ese código.',
        JoinProblem.fullOrRefused => 'Ese grupo está lleno (12 máx.).',
        JoinProblem.offline => 'No se puede conectar con Womp. Revisa tu conexión.',
      };

  // ---------- Commun ----------
  @override
  String get languageTitle => 'Idioma';
  @override
  String get phoneLanguage => 'Idioma del teléfono';
  @override
  String get back => 'Volver';
  @override
  String get cantReach => 'No se puede conectar con Womp.\nRevisa tu conexión.';
  @override
  String get tryAgain => 'Reintentar';
  @override
  String get liveFailed => 'No funcionó. Inténtalo de nuevo.';
  @override
  String get partyBadge => 'Fiesta · 18+';
  @override
  String get waterCounts => 'El agua cuenta. Nunca presiones a nadie para beber.';

  // ---------- Salon de la bande ----------
  @override
  String get everyoneHere => '¿Están todos?';
  @override
  String lobbyIntro(int seconds) => 'Partidas de $seconds segundos, una tras otra, cada uno en su teléfono. '
      'El último cumple un reto al momento.';
  @override
  String inTheCrew(int n) => 'En el grupo · $n';
  @override
  String get shareCode => 'Tus amigos se unen con este código.';
  @override
  String get inviteFriends => 'Invitar amigos';
  @override
  String inviteText(String code) =>
      'Únete a mi grupo en Womp: minijuegos, el último cumple el reto.\nCódigo del grupo: $code';
  @override
  String get inviteCopied => 'Invitación copiada. Pégala en el chat de tu grupo.';
  @override
  String get daresTitle => 'Retos';
  @override
  String get classicOn => 'Retos clásicos activados.';
  @override
  String get partyOn =>
      'Retos con bebida activados: sorbos pequeños, y uno de cada cinco juegos es una pausa de agua.';
  @override
  String get switchToParty => 'Pasar a retos con bebida (18+)';
  @override
  String get backToClassic => 'Volver a los retos clásicos';
  @override
  String get partyTitle => 'Los retos con bebida son para adultos';
  @override
  String get partyBody => 'Estos retos incluyen alcohol. Actívalos solo si todos en tu grupo tienen la edad '
      'legal para beber donde viven.\n\nLos sorbos son pequeños y limitados, y el agua siempre cuenta.';
  @override
  String get keepClassic => 'Seguir con los clásicos';
  @override
  String get allAdults => 'Somos todos adultos';
  @override
  String get switchFailed => 'No se pudieron cambiar los retos. Inténtalo más tarde.';
  @override
  String get startGames => '¡Vamos!';
  @override
  String get leave => 'Salir';
  @override
  String get leaveTitle => '¿Salir de este grupo?';
  @override
  String get leaveBody => 'Podrás unirte a otro grupo con su código. '
      'Para volver aquí, necesitarás el código de este grupo.';
  @override
  String get stay => 'Quedarme';

  // ---------- Manche ----------
  @override
  String gameNumber(int n) => 'Juego $n';
  @override
  String roundIntro(int seconds) => '$seconds segundos. El último cumple el reto.';
  @override
  List<String> rules(GameId game) => switch (game) {
        GameId.snap => ['Verde: +1', 'Amarillo: +3, desaparece rápido', 'Rojo: −3, no lo toques'],
        GameId.spot => ['Una flecha apunta al revés. Tócala.', 'La correcta: +1', 'Una equivocada: −1'],
        GameId.stop => ['Toca para parar la barra.', 'Centro rojo: +3', 'Zona amarilla: +1', 'Fuera: −1'],
        GameId.stash => [
            'Unas casillas se encienden y se apagan. Recuérdalas.',
            'Cada casilla encontrada: +1',
            'Casilla equivocada: −1, siguiente cuadrícula',
          ],
      };
  @override
  String startsIn(int seconds) => 'Empieza en $seconds…';
  @override
  String get nobodyPlayedThis => 'Nadie ha jugado este todavía.';
  @override
  String alreadyPlayed(int played, int total) => '$played de $total ya jugaron.';
  @override
  String get playNow => 'Jugar ahora';
  @override
  String get endGames => 'Dejar de jugar';

  // ---------- Gage de la manche ----------
  @override
  String gameDare(int n) => 'Juego $n · el reto';
  @override
  String get waitingOthers => 'Esperando a que alguien más termine.';
  @override
  String get itsOnYou => 'Te toca a ti.';
  @override
  String itsOn(String name) => 'Le toca a $name.';
  @override
  String stillPlaying(String names) => 'Todavía jugando: $names. Aún puede cambiar.';
  @override
  String get nextGame => 'Siguiente juego';

  // ---------- Dans les jeux ----------
  @override
  String stopFeedback(int points) => switch (points) { 3 => '+3  Perfecto', 1 => '+1  Bien', _ => '−1  Fallo' };
  @override
  String stopBar(int i, int n) => 'Barra $i de $n';
  @override
  String get stopHint => 'Toca la pantalla para parar la barra';
  @override
  String get stashShow => 'Recuerda las casillas amarillas';
  @override
  String stashRecall(int found, int total) => 'Tócalas: $found de $total';
  @override
  String get stashMissed => 'Fallaste una';
  @override
  String get stashAllFound => 'Todas encontradas';

  // ---------- Gages ----------
  @override
  List<String> get dares => const [
        'Diez sentadillas, ya.',
        'Habla como un robot hasta el próximo juego.',
        'Canta el estribillo que elija el ganador.',
        'Haz un cumplido a cada jugador, uno por uno.',
        'Haz tu mejor imitación del ganador.',
        'Aguanta una plancha veinte segundos.',
        'Juega el próximo juego sobre un pie.',
        'Confiesa al grupo la canción más vergonzosa que te encanta.',
      ];
  @override
  List<String> get partyDares => const [
        'Dos sorbos.',
        'Tres sorbos, y el ganador elige la bebida.',
        'Un sorbo, y el ganador bebe contigo.',
        'Dos sorbos con la mano equivocada.',
        'Brinda en voz alta por el ganador y luego un sorbo.',
        'Un sorbo por cada punto de diferencia con el ganador. Tres máx.',
        'Verdad o sorbo: el ganador pregunta. Si lo esquivas, dos sorbos.',
        'Sin sorbo: cuenta un secreto al grupo.',
      ];
  @override
  String get waterRound => 'Pausa de agua: todos beben un vaso de agua. Sin reto.';
}
