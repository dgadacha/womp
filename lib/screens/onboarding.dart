import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../core/game.dart';
import '../data/repo.dart';
import '../l10n/strings.dart';
import '../ui/kit.dart';
import 'language.dart';

/// Premier lancement : un prénom, puis on crée sa bande ou on en rejoint une.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onCreate,
    required this.onJoin,
    required this.locale,
    required this.onLocale,
    this.name = '',
  });

  final String name;

  /// Langue choisie ('' = celle du téléphone) et de quoi la changer.
  final String locale;
  final ValueChanged<String> onLocale;

  /// Les deux retournent le problème rencontré, ou null si tout s'est bien passé.
  final Future<JoinProblem?> Function(String name, String crewName) onCreate;
  final Future<JoinProblem?> Function(String name, String code) onJoin;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _name = TextEditingController(text: widget.name);
  final _code = TextEditingController(text: initialJoin);
  bool _busy = false;
  JoinProblem? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<JoinProblem?> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = cleanName(_name.text);
    // Les règles du serveur limitent le nom de bande à 24 caractères.
    final crewName = s.crewNameFor(name);
    final shortCrewName = crewName.length > 24 ? crewName.substring(0, 24) : crewName;
    final code = normalizeCode(_code.text);
    final ready = name.isNotEmpty && !_busy;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Logo(name: appName),
                  LanguageButton(current: widget.locale, onPick: widget.onLocale),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                s.tagline,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.1),
              ),
              const SizedBox(height: 20),
              _Field(
                label: s.firstNameLabel,
                hint: s.firstNameHint,
                controller: _name,
                onChanged: () => setState(() {}),
                capitalization: TextCapitalization.words,
                maxLength: 12,
              ),
              const SizedBox(height: 12),
              InkBox(
                color: Tone.sun,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.friendInvited,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      label: s.crewCodeLabel,
                      hint: 'ABC234',
                      controller: _code,
                      onChanged: () => setState(() {}),
                      capitalization: TextCapitalization.characters,
                      maxLength: 6,
                      flat: true,
                    ),
                    const SizedBox(height: 12),
                    InkButton(
                      label: s.joinCrew,
                      color: Tone.ink,
                      onTap: ready && code != null
                          ? () => _run(() => widget.onJoin(name, code))
                          : null,
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    s.joinProblem(_error!),
                    style: const TextStyle(color: Tone.tomato, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              const SizedBox(height: 16),
              InkButton(
                label: _busy ? s.oneSec : s.startCrew,
                onTap: ready ? () => _run(() => widget.onCreate(name, shortCrewName)) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    required this.capitalization,
    required this.maxLength,
    this.flat = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final TextCapitalization capitalization;
  final int maxLength;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return InkBox(
      drop: flat ? 0 : Tone.drop,
      radius: flat ? 14 : Tone.radius,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Overline(label),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            textCapitalization: capitalization,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Tone.ink),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFFB9BCCB)),
            ),
          ),
        ],
      ),
    );
  }
}
