import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Style « BD plat » : un trait d'encre, une ombre dure sans flou, des aplats.
/// Une seule épaisseur de trait, deux hauteurs d'ombre, peu de couleurs.
class Tone {
  static const bg = Color(0xFFFFF6E6);
  static const ink = Color(0xFF1D2440);
  static const soft = Color(0xFF6B7190);
  static const paper = Color(0xFFFFFFFF);
  static const tomato = Color(0xFFFF5A3C);
  static const sun = Color(0xFFFFC531);
  static const mint = Color(0xFF18B58A);
  static const blush = Color(0xFFFFE3DB);

  static const stroke = 2.5;
  static const radius = 20.0;
  static const drop = 5.0;
  static const dropSmall = 3.0;
}

BoxDecoration inkDecoration({
  Color color = Tone.paper,
  double radius = Tone.radius,
  double drop = Tone.drop,
  BoxShape shape = BoxShape.rectangle,
}) {
  return BoxDecoration(
    color: color,
    shape: shape,
    borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(radius),
    border: Border.all(color: Tone.ink, width: Tone.stroke),
    boxShadow: drop > 0
        ? [BoxShadow(color: Tone.ink, offset: Offset(0, drop), blurRadius: 0)]
        : null,
  );
}

/// Carte : fond plat, trait d'encre, ombre dure.
class InkBox extends StatelessWidget {
  const InkBox({
    super.key,
    required this.child,
    this.color = Tone.paper,
    this.padding = const EdgeInsets.all(18),
    this.radius = Tone.radius,
    this.drop = Tone.drop,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double radius;
  final double drop;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: drop),
      padding: padding,
      decoration: inkDecoration(color: color, radius: radius, drop: drop),
      child: child,
    );
  }
}

/// Surface pressable : elle s'enfonce sur son ombre quand on appuie.
class InkPress extends StatefulWidget {
  const InkPress({
    super.key,
    required this.child,
    required this.onTap,
    this.color = Tone.paper,
    this.radius = Tone.radius,
    this.drop = Tone.drop,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  final double drop;
  final EdgeInsets padding;

  @override
  State<InkPress> createState() => _InkPressState();
}

class _InkPressState extends State<InkPress> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final sink = _down ? widget.drop - 1 : 0.0;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              }
            : null,
        child: Padding(
          padding: EdgeInsets.only(top: sink, bottom: widget.drop - sink),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 60),
            padding: widget.padding,
            decoration: inkDecoration(
              color: widget.color,
              radius: widget.radius,
              drop: widget.drop - sink,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Bouton principal.
class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = Tone.tomato,
    this.textColor = Colors.white,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkPress(
      onTap: onTap,
      color: color,
      radius: 18,
      child: SizedBox(
        height: 58,
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: textColor, fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// Pastille : étiquette fixe, ou petit bouton si [onTap] est donné.
class InkPill extends StatelessWidget {
  const InkPill({
    super.key,
    required this.label,
    this.color = Tone.paper,
    this.textColor = Tone.ink,
    this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w800, height: 1.1),
    );
    const pad = EdgeInsets.symmetric(horizontal: 12, vertical: 7);
    if (onTap == null) {
      return InkBox(color: color, padding: pad, radius: 999, drop: Tone.dropSmall, child: text);
    }
    return InkPress(
      onTap: onTap,
      color: color,
      radius: 999,
      drop: Tone.dropSmall,
      padding: pad,
      child: text,
    );
  }
}

/// Petit titre en capitales au-dessus d'un bloc.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color = Tone.soft});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
    );
  }
}

/// Logo en toutes lettres, avec son point d'exclamation dans une pastille.
class Logo extends StatelessWidget {
  const Logo({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          name.toLowerCase(),
          style: const TextStyle(
            color: Tone.ink, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1,
          ),
        ),
        const SizedBox(width: 6),
        Transform.rotate(
          angle: 0.14,
          child: Container(
            width: 26,
            height: 30,
            alignment: Alignment.center,
            decoration: inkDecoration(color: Tone.sun, radius: 9, drop: Tone.dropSmall),
            child: const Text(
              '!',
              style: TextStyle(color: Tone.ink, fontSize: 19, fontWeight: FontWeight.w900, height: 1),
            ),
          ),
        ),
      ],
    );
  }
}
