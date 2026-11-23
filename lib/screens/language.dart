import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../ui/kit.dart';

/// Langues proposées, chacune écrite dans sa propre langue. '' = langue du téléphone.
const languages = <String, String>{
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
};

/// Le bouton de langue des en-têtes : le code de la langue affichée (EN, FR, ES).
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, required this.current, required this.onPick});

  /// Choix enregistré : '' pour la langue du téléphone.
  final String current;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final shown = Localizations.localeOf(context).languageCode.toUpperCase();
    return InkPill(
      label: shown,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LanguageScreen(current: current, onPick: onPick)),
      ),
    );
  }
}

/// L'écran de choix de la langue.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key, required this.current, required this.onPick});

  final String current;
  final ValueChanged<String> onPick;

  void _pick(BuildContext context, String code) {
    onPick(code);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.languageTitle,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1),
                ),
                InkPill(label: s.back, onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 20),
            _Choice(
              label: s.phoneLanguage,
              selected: current.isEmpty,
              onTap: () => _pick(context, ''),
            ),
            for (final e in languages.entries) ...[
              const SizedBox(height: 12),
              _Choice(label: e.value, selected: current == e.key, onTap: () => _pick(context, e.key)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkPress(
      onTap: onTap,
      color: selected ? Tone.sun : Tone.paper,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          if (selected) const Icon(Icons.check_rounded, color: Tone.ink, size: 28),
        ],
      ),
    );
  }
}
