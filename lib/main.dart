import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const PipeConnectApp());

class PipeConnectApp extends StatelessWidget {
  const PipeConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.softBlob,
      title: 'Pipe Connect',
      tagline: 'Twist and connect every pipe to light up the board',
      emoji: '🔧',
      slug: 'pipeconnect',
      howToPlay:
          '• Tap any pipe to rotate it 90°.\n• Connect the pump 💧 to every glowing endpoint.\n• Connected pipes light up with flowing water — so satisfying.\n• Clear all 15 boards to become certified Pipe Royalty. 👑',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) =>
          PipeConnectScreen(players: players, callbacks: cb),
    );
  }
}
