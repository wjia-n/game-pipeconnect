import 'package:flutter/material.dart';

/// Theme, pipe-style catalog for Pipe Connect.
///
/// Every theme stays inside a physical workshop world — copper, steel,
/// brass, porcelain, wood, stone. Variety comes from different metals,
/// backdrops and water tones. No neon, no cyberpunk, no generic look.
class PipeThemeDef {
  final String id;
  final String name;
  final Color bgDeep;
  final Color bgMid;
  final Color tile; // cell background
  final Color tileEdge;
  final Color pipe; // unlit pipe body
  final Color pipeHi; // pipe highlight
  final Color water; // lit/flowing pipe
  final Color waterHi; // water glow
  final Color endpoint; // endpoint bulb metal
  final Color pump; // pump body accent
  final Color accent;
  final Color accentLight;
  final Color text;
  final Color muted;

  const PipeThemeDef({
    required this.id,
    required this.name,
    required this.bgDeep,
    required this.bgMid,
    required this.tile,
    required this.tileEdge,
    required this.pipe,
    required this.pipeHi,
    required this.water,
    required this.waterHi,
    required this.endpoint,
    required this.pump,
    required this.accent,
    required this.accentLight,
    required this.text,
    required this.muted,
  });
}

class PipeThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'copper',
    'steel',
    'barn',
    'brassworks',
  ];

  static const List<PipeThemeDef> all = [
    // ---------------- FREE ----------------
    PipeThemeDef(
      id: 'copper',
      name: 'Copper Foundry',
      bgDeep: Color(0xFF2B1A10),
      bgMid: Color(0xFF4A2E1A),
      tile: Color(0xFF5C3A21),
      tileEdge: Color(0xFF241309),
      pipe: Color(0xFF9AA3AD),
      pipeHi: Color(0x44FFFFFF),
      water: Color(0xFF4FB3E8),
      waterHi: Color(0x734FB3E8),
      endpoint: Color(0xFFC9A227),
      pump: Color(0xFFB87333),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      text: Color(0xFFF5EFE0),
      muted: Color(0x99F5EFE0),
    ),
    PipeThemeDef(
      id: 'steel',
      name: 'Steel Works',
      bgDeep: Color(0xFF1E242B),
      bgMid: Color(0xFF323B45),
      tile: Color(0xFF3F4854),
      tileEdge: Color(0xFF14181D),
      pipe: Color(0xFFAEB8C2),
      pipeHi: Color(0x55FFFFFF),
      water: Color(0xFF37C6D0),
      waterHi: Color(0x6637C6D0),
      endpoint: Color(0xFFC0C6D4),
      pump: Color(0xFF7E8A98),
      accent: Color(0xFF9FB4C7),
      accentLight: Color(0xFFD8E4EF),
      text: Color(0xFFEFF2F6),
      muted: Color(0x99EFF2F6),
    ),
    PipeThemeDef(
      id: 'barn',
      name: 'Rustic Barn',
      bgDeep: Color(0xFF33220F),
      bgMid: Color(0xFF54391B),
      tile: Color(0xFF6B4A24),
      tileEdge: Color(0xFF221507),
      pipe: Color(0xFFB08D5A),
      pipeHi: Color(0x44FFE9C4),
      water: Color(0xFF5AA9E6),
      waterHi: Color(0x735AA9E6),
      endpoint: Color(0xFFD4AF37),
      pump: Color(0xFF8A5A2E),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      text: Color(0xFFF8F1E2),
      muted: Color(0x99F8F1E2),
    ),
    PipeThemeDef(
      id: 'brassworks',
      name: 'Brass Fittings',
      bgDeep: Color(0xFF241D0E),
      bgMid: Color(0xFF42341A),
      tile: Color(0xFF54431F),
      tileEdge: Color(0xFF191207),
      pipe: Color(0xFFC2A35C),
      pipeHi: Color(0x55FFF2C9),
      water: Color(0xFF49B8D8),
      waterHi: Color(0x7349B8D8),
      endpoint: Color(0xFFE8CE7A),
      pump: Color(0xFF9A7B2E),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      text: Color(0xFFF5EFE0),
      muted: Color(0x99F5EFE0),
    ),
    // ---------------- PRO ----------------
    PipeThemeDef(
      id: 'porcelain',
      name: 'Porcelain Bath',
      bgDeep: Color(0xFF2C3E44),
      bgMid: Color(0xFF47646C),
      tile: Color(0xFFDEE8E4),
      tileEdge: Color(0xFF8FA5A0),
      pipe: Color(0xFF9FB4AE),
      pipeHi: Color(0x55FFFFFF),
      water: Color(0xFF2E86C1),
      waterHi: Color(0x662E86C1),
      endpoint: Color(0xFFC9A227),
      pump: Color(0xFF2E5A88),
      accent: Color(0xFF2E86C1),
      accentLight: Color(0xFF7FB8DC),
      text: Color(0xFF16303A),
      muted: Color(0x9916303A),
    ),
    PipeThemeDef(
      id: 'jade',
      name: 'Jade Steamworks',
      bgDeep: Color(0xFF14291F),
      bgMid: Color(0xFF264433),
      tile: Color(0xFF33563F),
      tileEdge: Color(0xFF0D1A13),
      pipe: Color(0xFFB08D5A),
      pipeHi: Color(0x44FFE9C4),
      water: Color(0xFF7FD1B9),
      waterHi: Color(0x667FD1B9),
      endpoint: Color(0xFFE8CE7A),
      pump: Color(0xFF7E6A3E),
      accent: Color(0xFF7FD1B9),
      accentLight: Color(0xFFBFE8DA),
      text: Color(0xFFF0EDE2),
      muted: Color(0x99F0EDE2),
    ),
    PipeThemeDef(
      id: 'obsidian',
      name: 'Obsidian Forge',
      bgDeep: Color(0xFF100D14),
      bgMid: Color(0xFF241D2E),
      tile: Color(0xFF2E2638),
      tileEdge: Color(0xFF0A0810),
      pipe: Color(0xFF6E5A7E),
      pipeHi: Color(0x55D9C8EE),
      water: Color(0xFFB388EB),
      waterHi: Color(0x66B388EB),
      endpoint: Color(0xFFC0C6D4),
      pump: Color(0xFF4A3E5C),
      accent: Color(0xFFB388EB),
      accentLight: Color(0xFFD9C2F5),
      text: Color(0xFFF2EEE4),
      muted: Color(0x99F2EEE4),
    ),
    PipeThemeDef(
      id: 'marble',
      name: 'Marble Spa',
      bgDeep: Color(0xFF3A3430),
      bgMid: Color(0xFF5C534B),
      tile: Color(0xFFEDE6DA),
      tileEdge: Color(0xFFA89C8C),
      pipe: Color(0xFFB0A08E),
      pipeHi: Color(0x66FFFFFF),
      water: Color(0xFF3FA7D6),
      waterHi: Color(0x663FA7D6),
      endpoint: Color(0xFFC9A227),
      pump: Color(0xFF8A7A68),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      text: Color(0xFF2A231E),
      muted: Color(0x992A231E),
    ),
    PipeThemeDef(
      id: 'sandstone',
      name: 'Sandstone Desert',
      bgDeep: Color(0xFF3B2A18),
      bgMid: Color(0xFF5E442A),
      tile: Color(0xFFC9A86A),
      tileEdge: Color(0xFF7A5E34),
      pipe: Color(0xFF8A6A42),
      pipeHi: Color(0x55FFE9C4),
      water: Color(0xFF2E9E97),
      waterHi: Color(0x662E9E97),
      endpoint: Color(0xFFD4AF37),
      pump: Color(0xFF6E4A1E),
      accent: Color(0xFF2E9E97),
      accentLight: Color(0xFF8AD8D2),
      text: Color(0xFF2E2118),
      muted: Color(0x992E2118),
    ),
    PipeThemeDef(
      id: 'teak',
      name: 'Teak Steam Room',
      bgDeep: Color(0xFF221408),
      bgMid: Color(0xFF3E2612),
      tile: Color(0xFF54402A),
      tileEdge: Color(0xFF150D05),
      pipe: Color(0xFFD4A94E),
      pipeHi: Color(0x66FFE9C4),
      water: Color(0xFF5AC8E0),
      waterHi: Color(0x665AC8E0),
      endpoint: Color(0xFFF3DC8E),
      pump: Color(0xFF8A6A2E),
      accent: Color(0xFFD4A94E),
      accentLight: Color(0xFFF3DC8E),
      text: Color(0xFFF5EFE0),
      muted: Color(0x99F5EFE0),
    ),
    PipeThemeDef(
      id: 'deepsea',
      name: 'Deepsea Valve',
      bgDeep: Color(0xFF0E2233),
      bgMid: Color(0xFF1B3A52),
      tile: Color(0xFF274A63),
      tileEdge: Color(0xFF08141D),
      pipe: Color(0xFF8FA5B5),
      pipeHi: Color(0x55FFFFFF),
      water: Color(0xFF7FE3F0),
      waterHi: Color(0x667FE3F0),
      endpoint: Color(0xFFE8CE7A),
      pump: Color(0xFF3E6A8A),
      accent: Color(0xFF7FE3F0),
      accentLight: Color(0xFFC2F2FA),
      text: Color(0xFFEFF6FA),
      muted: Color(0x99EFF6FA),
    ),
    PipeThemeDef(
      id: 'ivory',
      name: 'Ivory Lathe',
      bgDeep: Color(0xFF4A4238),
      bgMid: Color(0xFF6E6355),
      tile: Color(0xFFFBF6E9),
      tileEdge: Color(0xFFB5A88E),
      pipe: Color(0xFFA89C86),
      pipeHi: Color(0x66FFFFFF),
      water: Color(0xFF4A90D9),
      waterHi: Color(0x664A90D9),
      endpoint: Color(0xFFB87333),
      pump: Color(0xFF7A6A52),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      text: Color(0xFF2A2318),
      muted: Color(0x992A2318),
    ),
  ];

  static PipeThemeDef byId(String id, {PipeThemeDef? custom}) {
    if (id == 'custom') {
      return custom ?? all.first;
    }
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}

/// Pipe rendering styles — how each pipe is drawn. 0-3 = FREE, 4+ = PRO.
class PipeStyles {
  static const names = [
    'Rounded Steel',
    'Copper Coil',
    'Industrial Ribbed',
    'Hex Fitting',
    'Glass Tube',
    'Ceramic Gloss',
    'Wood Inlay',
    'Brass Flanged',
  ];
  static const descriptions = [
    'Smooth rounded metal pipe',
    'Coiled thread rings along the body',
    'Ribbed industrial segments',
    'Hexagonal machined flats',
    'Clear tube — water glows inside',
    'Glossy glazed ceramic',
    'Carved wooden casing',
    'Flanged brass joints',
  ];

  /// Styles free players may use.
  static const freeCount = 4;
  static bool isPro(int index) => index >= freeCount;
}
