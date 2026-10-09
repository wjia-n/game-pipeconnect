import 'package:flutter/material.dart';
import 'pipe_themes.dart';

/// Pipe Workshop design system: warm metal workshop, real material depth.
/// No neon, no cyberpunk, no generic Material look.
///
/// All widgets accept an optional [PipeThemeDef]; they default to the
/// Copper Foundry theme so existing call sites keep working.
class Workshop {
  static TextStyle display(double size,
          {Color? color, PipeThemeDef? theme}) =>
      TextStyle(
        fontFamily: 'serif',
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE8CE7A),
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Color(0xFF1A0F08), offset: Offset(0, 2), blurRadius: 4),
        ],
      );

  static TextStyle body(double size, {Color? color, PipeThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme?.text ?? const Color(0xFFF5EFE0),
        height: 1.35,
      );

  static TextStyle label(double size, {Color? color, PipeThemeDef? theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? theme?.accentLight ?? const Color(0xFFE8CE7A),
        letterSpacing: 0.8,
      );

  static ThemeData theme([PipeThemeDef? t]) {
    t ??= PipeThemes.byId('copper');
    final lightBg = t.id == 'porcelain' || t.id == 'marble' || t.id == 'ivory' || t.id == 'sandstone';
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.bgDeep,
      colorScheme: ColorScheme(
        brightness: lightBg ? Brightness.light : Brightness.dark,
        primary: t.accent,
        onPrimary: t.bgDeep,
        secondary: t.accentLight,
        onSecondary: t.bgDeep,
        surface: t.bgMid,
        onSurface: t.text,
        error: t.water,
        onError: t.text,
      ),
      textTheme: TextTheme(
        displayLarge: display(34, theme: t),
        displayMedium: display(26, theme: t),
        titleLarge: display(22, theme: t),
        bodyLarge: body(16, theme: t),
        bodyMedium: body(14, theme: t),
        labelLarge: label(14, theme: t),
      ),
      dialogTheme: DialogThemeData(backgroundColor: t.bgMid),
    );
  }
}

/// Workshop backdrop: metal-dark vignette + rivet plate texture.
class WorkshopBackdrop extends StatelessWidget {
  final Widget child;
  final PipeThemeDef? theme;
  const WorkshopBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PipeThemes.byId('copper');
    return Container(
      decoration: BoxDecoration(color: t.bgDeep),
      child: CustomPaint(
        painter: _WorkshopPainter(t),
        child: child,
      ),
    );
  }
}

class _WorkshopPainter extends CustomPainter {
  final PipeThemeDef t;
  _WorkshopPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final vignette = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 1.15,
      colors: [
        t.bgMid.withValues(alpha: 0.55),
        t.bgDeep.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.45),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = vignette.createShader(Offset.zero & size),
    );
    // Rivet dots along the edges — a bolted steel-plate feel.
    final rivet = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.0,
        colors: [
          t.accentLight.withValues(alpha: 0.55),
          t.accent.withValues(alpha: 0.25),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 12, 12));
    for (double y = 18; y < size.height; y += 96) {
      canvas.drawCircle(Offset(10, y), 5, rivet);
      canvas.drawCircle(Offset(size.width - 10, y), 5, rivet);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A chunky metal-framed button — looks physically pressable.
class WorkshopButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;
  final PipeThemeDef? theme;

  const WorkshopButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 19,
    this.theme,
  });

  @override
  State<WorkshopButton> createState() => _WorkshopButtonState();
}

class _WorkshopButtonState extends State<WorkshopButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? PipeThemes.byId('copper');
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15),
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? [t.bgMid, t.bgDeep]
                : [
                    t.bgDeep.withValues(alpha: 0.7),
                    t.bgDeep.withValues(alpha: 0.5)
                  ],
          ),
          border: Border.all(color: t.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: t.accentLight.withValues(alpha: _pressed ? 0.05 : 0.22),
              offset: const Offset(0, -2),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              offset: Offset(0, _pressed ? 2 : 6),
              blurRadius: _pressed ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Workshop.display(widget.fontSize,
              theme: t,
              color: enabled ? t.text : t.muted),
        ),
      ),
    );
  }
}

/// An engraved metal plaque for titles.
class MetalPlaque extends StatelessWidget {
  final String title;
  final String? subtitle;
  final PipeThemeDef? theme;
  const MetalPlaque(
      {super.key, required this.title, this.subtitle, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PipeThemes.byId('copper');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.tileEdge, t.bgDeep],
        ),
        border: Border.all(color: t.accent, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(0, 6),
              blurRadius: 12),
          BoxShadow(
              color: t.accentLight.withValues(alpha: 0.7),
              offset: const Offset(0, -1),
              blurRadius: 1),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: Workshop.display(30, theme: t),
              textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: Workshop.body(14, theme: t, color: t.muted),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// A metal lever toggle for settings.
class WorkshopToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final PipeThemeDef? theme;
  const WorkshopToggle(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PipeThemes.byId('copper');
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 64,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: value ? t.accent.withValues(alpha: 0.85) : t.tileEdge,
          border: Border.all(color: t.accent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 3),
                blurRadius: 5),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.accentLight, t.accent, t.tileEdge],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 2),
                    blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A brass-bead volume slider on a metal rail.
class BeadSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final PipeThemeDef? theme;
  const BeadSlider(
      {super.key, required this.value, required this.onChanged, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PipeThemes.byId('copper');
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.tileEdge,
        thumbShape: _BeadThumb(t),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _BeadThumb extends SliderComponentShape {
  final PipeThemeDef t;
  const _BeadThumb(this.t);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(
        center + const Offset(0, 2),
        12,
        Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(
        center,
        11,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 1.0,
            colors: [t.accentLight, t.accent, t.tileEdge],
          ).createShader(Rect.fromCircle(center: center, radius: 11)));
  }
}

/// Small helper: a labeled settings row.
class SettingRow extends StatelessWidget {
  final String label;
  final Widget control;
  final PipeThemeDef? theme;
  const SettingRow(
      {super.key, required this.label, required this.control, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? PipeThemes.byId('copper');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: t.tileEdge.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Workshop.body(16, theme: t))),
          control,
        ],
      ),
    );
  }
}

/// Generic workshop card with a title.
class WorkshopCard extends StatelessWidget {
  final PipeThemeDef theme;
  final String title;
  final Widget child;
  const WorkshopCard(
      {super.key, required this.theme, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.bgMid.withValues(alpha: 0.9),
            theme.tileEdge.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: Workshop.display(20, theme: theme)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Selectable chip.
class WorkshopChip extends StatelessWidget {
  final PipeThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const WorkshopChip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Workshop.label(13,
              theme: theme, color: selected ? theme.tileEdge : theme.text),
        ),
      ),
    );
  }
}

/// Circular icon button.
class WorkshopIcon extends StatelessWidget {
  final PipeThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const WorkshopIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.bgMid, theme.tileEdge],
              ),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Workshop.label(12, theme: theme)),
        ],
      ),
    );
  }
}
