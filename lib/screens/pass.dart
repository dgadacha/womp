import 'package:flutter/material.dart';

import '../config.dart';
import '../data/pass.dart';
import '../l10n/strings.dart';
import '../ui/kit.dart';

/// L'écran de vente du Womp Pass : ce qu'il apporte, son prix, l'achat et la restauration.
class PassScreen extends StatefulWidget {
  const PassScreen({super.key, required this.pass});
  final PassController pass;

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  bool _busy = false;

  PassController get _pass => widget.pass;

  @override
  void initState() {
    super.initState();
    _pass.addListener(_changed);
    if (!_pass.offerLoaded && !_pass.owned) _pass.loadOffer();
  }

  @override
  void dispose() {
    _pass.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<String?> Function(S s) action) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    final message = await action(s);
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
    if (_pass.owned) nav.pop();
  }

  void _buy() => _run((s) async => switch (await _pass.buy()) {
        PassResult.bought => s.passBought,
        PassResult.pending => s.passPending,
        PassResult.failed => s.passFailed,
        PassResult.cancelled => null,
      });

  void _restore() => _run((s) async => await _pass.restore() ? s.passRestored : s.passNothingToRestore);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final offer = _pass.offer;
    final perks = s.passPerks;

    final Widget action;
    if (_pass.owned) {
      action = InkBox(
        color: Tone.mint,
        child: Text(s.passOwned, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.3)),
      );
    } else if (!_pass.offerLoaded) {
      action = Center(child: Text(s.oneSec, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)));
    } else if (offer == null) {
      action = Text(
        s.passUnavailable,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      );
    } else {
      action = InkButton(label: s.passBuy(offer.price), onTap: _busy ? null : _buy);
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      passName,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkPill(label: s.back, onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 20),
            InkBox(
              color: Tone.sun,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.passHeadline,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.1),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < perks.length; i++)
                    _Perk(color: _perkColors[i % _perkColors.length], text: perks[i]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            action,
            if (!_pass.owned)
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(
                    s.passRestore,
                    style: const TextStyle(
                      color: Tone.ink,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _perkColors = [Tone.tomato, Tone.mint, Tone.paper, Tone.ink];

class _Perk extends StatelessWidget {
  const _Perk({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: inkDecoration(color: color, shape: BoxShape.circle, drop: 0),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
