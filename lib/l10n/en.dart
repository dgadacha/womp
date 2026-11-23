import '../core/game.dart';
import '../core/games.dart';
import '../data/repo.dart';
import 'strings.dart';

class SEn extends S {
  const SEn();

  // ---------- Arrivée ----------
  @override
  String get tagline => 'Quick games with your crew.\nLast place takes the dare.';
  @override
  String get firstNameLabel => 'Your first name';
  @override
  String get firstNameHint => 'e.g. Maya';
  @override
  String get friendInvited => 'A friend invited you?';
  @override
  String get crewCodeLabel => 'Crew code';
  @override
  String get joinCrew => 'Join the crew';
  @override
  String get startCrew => 'Start a new crew';
  @override
  String get oneSec => 'One sec…';
  @override
  String crewNameFor(String name) => "$name's crew";
  @override
  String joinProblem(JoinProblem problem) => switch (problem) {
        JoinProblem.badCode => 'A crew code is 6 letters and digits.',
        JoinProblem.unknownCode => 'No crew has that code.',
        JoinProblem.fullOrRefused => 'That crew is full (12 max).',
        JoinProblem.offline => "Can't reach Womp. Check your connection.",
      };

  // ---------- Commun ----------
  @override
  String get languageTitle => 'Language';
  @override
  String get phoneLanguage => 'Phone language';
  @override
  String get back => 'Back';
  @override
  String get cantReach => "Can't reach Womp.\nCheck your connection.";
  @override
  String get tryAgain => 'Try again';
  @override
  String get liveFailed => "That didn't go through. Try again.";
  @override
  String get partyBadge => 'Party · 18+';
  @override
  String get waterCounts => 'Water counts. Never push anyone to drink.';

  // ---------- Salon de la bande ----------
  @override
  String get everyoneHere => 'Everyone here?';
  @override
  String lobbyIntro(int seconds) => '$seconds-second games, back to back, each on your own phone. '
      'Last place takes a dare right away.';
  @override
  String inTheCrew(int n) => 'In the crew · $n';
  @override
  String get shareCode => 'Friends join with this code.';
  @override
  String get inviteFriends => 'Invite friends';
  @override
  String inviteText(String code) =>
      'Join my crew on Womp: quick games, last place takes the dare.\nCrew code: $code';
  @override
  String get inviteCopied => 'Invite copied. Paste it in your crew chat.';
  @override
  String get daresTitle => 'Dares';
  @override
  String get classicOn => 'Classic dares are on.';
  @override
  String get partyOn => 'Party dares are on: small sips, and every fifth game is a water round.';
  @override
  String get switchToParty => 'Switch to party dares (18+)';
  @override
  String get backToClassic => 'Back to classic dares';
  @override
  String get partyTitle => 'Party dares are for adults';
  @override
  String get partyBody => 'These dares involve alcohol. Only switch if everyone in your crew is of legal '
      'drinking age where they live.\n\nSips are small and capped, and water always counts.';
  @override
  String get keepClassic => 'Keep classic';
  @override
  String get allAdults => "We're all adults";
  @override
  String get switchFailed => "Couldn't switch the dares. Try again later.";
  @override
  String get startGames => "Let's go";
  @override
  String get leave => 'Leave';
  @override
  String get leaveTitle => 'Leave this crew?';
  @override
  String get leaveBody => "You can join another crew with its code. To come back, you'll need this crew's code.";
  @override
  String get stay => 'Stay';

  // ---------- Manche ----------
  @override
  String gameNumber(int n) => 'Game $n';
  @override
  String roundIntro(int seconds) => '$seconds seconds. Last place takes the dare.';
  @override
  List<String> rules(GameId game) => switch (game) {
        GameId.snap => ['Green: +1', 'Yellow: +3, gone in a blink', "Red: −3, don't touch"],
        GameId.spot => ['One arrow points the wrong way. Tap it.', 'Right one: +1', 'Wrong one: −1'],
        GameId.stop => ['Tap to stop the bar.', 'Red centre: +3', 'Yellow zone: +1', 'Outside: −1'],
        GameId.stash => [
            'Tiles light up, then go dark. Remember them.',
            'Each tile found: +1',
            'A wrong tile: −1, next grid',
          ],
      };
  @override
  String startsIn(int seconds) => 'Starts in $seconds…';
  @override
  String get nobodyPlayedThis => 'Nobody has played this one yet.';
  @override
  String alreadyPlayed(int played, int total) => '$played of $total already played.';
  @override
  String get playNow => 'Play now';
  @override
  String get endGames => 'Stop playing';

  // ---------- Gage de la manche ----------
  @override
  String gameDare(int n) => 'Game $n · the dare';
  @override
  String get waitingOthers => 'Waiting for someone else to finish.';
  @override
  String get itsOnYou => "It's on you.";
  @override
  String itsOn(String name) => "It's on $name.";
  @override
  String stillPlaying(String names) => 'Still playing: $names. It can still change.';
  @override
  String get nextGame => 'Next game';

  // ---------- Dans les jeux ----------
  @override
  String stopFeedback(int points) => switch (points) { 3 => '+3  Perfect', 1 => '+1  Nice', _ => '−1  Miss' };
  @override
  String stopBar(int i, int n) => 'Bar $i of $n';
  @override
  String get stopHint => 'Tap anywhere to stop the bar';
  @override
  String get stashShow => 'Remember the yellow tiles';
  @override
  String stashRecall(int found, int total) => 'Tap them: $found of $total';
  @override
  String get stashMissed => 'Missed one';
  @override
  String get stashAllFound => 'All found';

  // ---------- Womp Pass ----------
  @override
  String packName(String pack) => switch (pack) {
        packParty => 'Party 18+',
        packTruth => 'Truth',
        packChaos => 'Chaos',
        _ => 'Classic',
      };
  @override
  String get truthOn => 'Truth dares are on: the last one answers honestly.';
  @override
  String get chaosOn => 'Chaos dares are on: silly, loud, and all in the room.';
  @override
  String get passPitch => "One purchase and your whole crew gets more dares. Your friends don't pay a thing.";
  @override
  String get passSee => 'See the Pass';
  @override
  String passUnlockedBy(String name) => 'Unlocked by $name. Truth and Chaos dares are open to the whole crew.';
  @override
  String get passUnlockedByYou => 'You unlocked it. Truth and Chaos dares are open to the whole crew.';
  @override
  String passCreatorPicks(String name) => '$name picks the dares.';
  @override
  String get passHeadline => 'Buy once.\nYour whole crew plays.';
  @override
  List<String> get passPerks => const [
        'Two new dare packs: Truth and Chaos',
        'Unlocks every crew you play in',
        "Your friends don't pay a thing",
        'One-time purchase, no subscription',
      ];
  @override
  String passBuy(String price) => 'Get it for $price';
  @override
  String get passUnavailable => "The Pass isn't on sale right now. Try again later.";
  @override
  String get passOwned => 'You have the Pass. It unlocks every crew you play in.';
  @override
  String get passRestore => 'Restore purchases';
  @override
  String get passBought => 'Pass unlocked. Enjoy!';
  @override
  String get passPending => 'Payment pending. The Pass unlocks as soon as it goes through.';
  @override
  String get passFailed => "The purchase didn't go through.";
  @override
  String get passRestored => 'Pass restored.';
  @override
  String get passNothingToRestore => 'No Pass found on this account.';

  // ---------- Gages ----------
  @override
  List<String> get dares => const [
        'Ten squats, right now.',
        'Talk like a robot until the next game.',
        'Sing the chorus the winner picks.',
        'Give every player a compliment, one by one.',
        'Do your best impression of the winner.',
        'Hold a plank for twenty seconds.',
        'Play the next game standing on one leg.',
        'Tell the crew the most embarrassing song you love.',
      ];
  @override
  List<String> get partyDares => const [
        'Two sips.',
        'Three sips, and the winner picks the drink.',
        'One sip, and the winner sips with you.',
        'Two sips with your wrong hand.',
        'Toast the winner out loud, then one sip.',
        'One sip per point behind the winner. Three max.',
        'Truth or sip: the winner asks. Dodge it and take two sips.',
        'Skip the sip: tell the crew a secret instead.',
      ];
  @override
  String get waterRound => 'Water round: everyone drinks a glass of water. No dare.';
  @override
  List<String> get truthDares => const [
        'Tell the crew your most embarrassing moment this year.',
        'Read out your last web search.',
        'Who here would you call at 3 a.m.? Say why.',
        "What's the worst gift you ever got?",
        'Confess a small lie you told this week.',
        "Who here would survive a zombie apocalypse, and who wouldn't?",
        'Tell the crew your weirdest habit.',
        'The winner asks you any question. Answer honestly.',
      ];
  @override
  List<String> get chaosDares => const [
        'Talk only in questions until the next game.',
        'Act out your last game in slow motion, like a replay.',
        'The winner gives you a nickname for the rest of the night.',
        'Commentate everything you do like a sports announcer until the next game.',
        'Serenade the player on your left.',
        'Walk across the room like a runway model.',
        'Speak with an accent the winner picks until the next game.',
        'Make up a four-line poem about the winner, right now.',
      ];
}
