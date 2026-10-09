import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/workshop.dart';
import '../theme/pipe_themes.dart';

/// PRO: custom theme creator — pick backdrop, tile, pipe, water, accent.
/// Live preview, persisted per color.
class CustomThemeScreen extends StatefulWidget {
  final PipeAudio audio;
  final PipeSettings settings;

  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  PipeThemeDef get _t => PipeThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  // Curated workshop-friendly palette choices.
  static const List<Color> palette = [
    Color(0xFF2B1A10), Color(0xFF4A2E1A), Color(0xFF241309),
    Color(0xFF1E242B), Color(0xFF323B45), Color(0xFF14181D),
    Color(0xFF14291F), Color(0xFF264433), Color(0xFF0D1A13),
    Color(0xFF0E2233), Color(0xFF1B3A52), Color(0xFF08141D),
    Color(0xFFC9A227), Color(0xFFE8CE7A), Color(0xFF8A6D1A),
    Color(0xFFB87333), Color(0xFFE09E5A), Color(0xFF7E4F22),
    Color(0xFFC0C6D4), Color(0xFFE8ECF5), Color(0xFF7E8698),
    Color(0xFFF5EFE0), Color(0xFFFAF6EE), Color(0xFF2E2118),
    Color(0xFF9AA3AD), Color(0xFFAEB8C2), Color(0xFF5C3A21),
    Color(0xFF4FB3E8), Color(0xFF37C6D0), Color(0xFF2E86C1),
    Color(0xFF7FD1B9), Color(0xFFB388EB), Color(0xFFD4A94E),
    Color(0xFFC0392B), Color(0xFF1B7A4D), Color(0xFF8E44AD),
    Color(0xFFDEE8E4), Color(0xFFEDE6DA), Color(0xFFC9A86A),
  ];

  static const rows = [
    ('Backdrop deep', 'bgDeep'),
    ('Backdrop mid', 'bgMid'),
    ('Tile', 'tile'),
    ('Tile edge', 'tileEdge'),
    ('Pipe body', 'pipe'),
    ('Water', 'water'),
    ('Endpoint brass', 'endpoint'),
    ('Accent metal', 'accent'),
    ('Accent light', 'accentLight'),
    ('Text', 'text'),
  ];

  Future<void> _pick(String key, String label) async {
    final s = widget.settings;
    final current = Color(s.customColors[key]!);
    final chosen = await showDialog<Color>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [
              _t.bgMid,
              _t.tileEdge,
            ]),
            border: Border.all(color: _t.accent, width: 2.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pick $label', style: Workshop.display(20, theme: _t)),
              const SizedBox(height: 14),
              SizedBox(
                width: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: palette.length,
                  itemBuilder: (_, i) {
                    final c = palette[i];
                    final selected = c.value == current.value;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop(c);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c,
                          border: Border.all(
                            color: selected
                                ? _t.accentLight
                                : Colors.black.withValues(alpha: 0.4),
                            width: selected ? 3 : 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              WorkshopButton(
                label: 'Cancel',
                width: 160,
                fontSize: 15,
                theme: _t,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
      await s.setCustomColor(key, chosen.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Custom Theme',
              style: Workshop.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              children: [
                // Live preview strip.
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.bgMid, t.bgDeep],
                    ),
                    border: Border.all(color: t.accent, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in [t.pipe, t.water, t.endpoint])
                        Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            border: Border.all(
                                color: t.accentLight, width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.4),
                                  offset: const Offset(0, 3),
                                  blurRadius: 5),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final r in rows)
                  SettingRow(
                    label: r.$1,
                    theme: t,
                    control: GestureDetector(
                      onTap: () => _pick(r.$2, r.$1),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(s.customColors[r.$2]!),
                          border: Border.all(
                              color: t.accentLight, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                offset: const Offset(0, 3),
                                blurRadius: 5),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: WorkshopButton(
                    label: 'Reset colors',
                    width: 220,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      s.resetCustomColors();
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
