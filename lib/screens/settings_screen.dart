import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/workshop.dart';
import '../theme/pipe_themes.dart';

/// Settings: music / SFX / volume, reset progress.
class SettingsScreen extends StatelessWidget {
  final PipeAudio audio;
  final PipeSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  PipeThemeDef get _t => PipeThemes.byId(settings.themeId,
      custom: settings.customTheme);

  @override
  Widget build(BuildContext context) {
    final t = _t;
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
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Workshop.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: settings,
            builder: (_, _) => ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              children: [
                SettingRow(
                  label: 'Music',
                  theme: t,
                  control: WorkshopToggle(
                    theme: t,
                    value: settings.musicOn,
                    onChanged: (v) {
                      settings.setMusic(v);
                      audio.configure(
                          musicOn: v,
                          sfxOn: settings.sfxOn,
                          volume: settings.volume);
                      if (v) {
                        audio.startMenuMusic();
                      }
                      audio.click();
                    },
                  ),
                ),
                SettingRow(
                  label: 'Sound effects',
                  theme: t,
                  control: WorkshopToggle(
                    theme: t,
                    value: settings.sfxOn,
                    onChanged: (v) {
                      settings.setSfx(v);
                      audio.configure(
                          musicOn: settings.musicOn,
                          sfxOn: v,
                          volume: settings.volume);
                      audio.click();
                    },
                  ),
                ),
                SettingRow(
                  label: 'Volume',
                  theme: t,
                  control: SizedBox(
                    width: 170,
                    child: BeadSlider(
                      theme: t,
                      value: settings.volume,
                      onChanged: (v) {
                        settings.setVolume(v);
                        audio.configure(
                            musicOn: settings.musicOn,
                            sfxOn: settings.sfxOn,
                            volume: v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                WorkshopCard(
                  theme: t,
                  title: 'Progress',
                  child: Column(
                    children: [
                      Text(
                        'Resets campaign boards, daily streak and stats. Your themes, name and Pro unlock stay.',
                        style: Workshop.body(14, theme: t),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      WorkshopButton(
                        label: 'Reset progress',
                        width: 220,
                        fontSize: 16,
                        theme: t,
                        onTap: () {
                          audio.click();
                          _confirmReset(context, t);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text('Pipe Connect v2.0 · by WAJIHA',
                      style: Workshop.label(12, theme: t)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, PipeThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.bgMid, t.tileEdge],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Reset all progress?',
                  style: Workshop.display(22, theme: t)),
              const SizedBox(height: 10),
              Text('This cannot be undone.',
                  style: Workshop.body(14, theme: t)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WorkshopButton(
                    label: 'Keep it',
                    width: 130,
                    fontSize: 15,
                    theme: t,
                    onTap: () {
                      audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 10),
                  WorkshopButton(
                    label: 'Reset',
                    width: 130,
                    fontSize: 15,
                    theme: t,
                    onTap: () {
                      audio.click();
                      settings.resetProgress();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
