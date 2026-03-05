import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/tactical_football_game.dart';
import 'ui/overlays/hud_overlay.dart';
import 'ui/overlays/main_menu_overlay.dart';
import 'ui/overlays/tactic_card_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const FootballTacticsApp());
}

class FootballTacticsApp extends StatelessWidget {
  const FootballTacticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A1628),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFF3A7D44),
        ),
      ),
      home: const _GameScreen(),
    );
  }
}

class _GameScreen extends StatefulWidget {
  const _GameScreen();

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  late final TacticalFootballGame _game;

  @override
  void initState() {
    super.initState();
    _game = TacticalFootballGame();
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget<TacticalFootballGame>(
      game: _game,
      overlayBuilderMap: {
        TacticalFootballGame.overlayMainMenu: (ctx, game) =>
            MainMenuOverlay(game: game),
        TacticalFootballGame.overlayHUD: (ctx, game) =>
            HudOverlay(game: game),
        TacticalFootballGame.overlayCardPanel: (ctx, game) =>
            TacticCardOverlay(game: game),
      },
      initialActiveOverlays: const [TacticalFootballGame.overlayMainMenu],
    );
  }
}
