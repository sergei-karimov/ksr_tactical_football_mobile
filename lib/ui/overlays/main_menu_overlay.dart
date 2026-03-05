import 'package:flutter/material.dart';
import '../../game/models/game_config.dart';
import '../../game/tactical_football_game.dart';

class MainMenuOverlay extends StatefulWidget {
  final TacticalFootballGame game;
  const MainMenuOverlay({super.key, required this.game});

  @override
  State<MainMenuOverlay> createState() => _MainMenuOverlayState();
}

class _MainMenuOverlayState extends State<MainMenuOverlay> {
  GameFormat _format     = GameFormat.f11v11;
  bool       _vsAI       = true;
  int        _difficulty = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xDD0A1628),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'KSR TACTICAL FOOTBALL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'TURN-BASED TACTICS',
                  style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2),
                ),
                const SizedBox(height: 16),

                // Format
                _Section(title: 'FORMAT', child: DropdownButtonFormField<GameFormat>(
                  value: _format,
                  dropdownColor: const Color(0xFF1a2a3a),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco(),
                  items: GameFormat.values.map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(formatLabels[f]!),
                  )).toList(),
                  onChanged: (v) => setState(() => _format = v!),
                )),
                const SizedBox(height: 8),

                // VS AI toggle
                SwitchListTile(
                  title: const Text('Play vs AI', style: TextStyle(color: Colors.white)),
                  value: _vsAI,
                  activeColor: const Color(0xFFFFD700),
                  onChanged: (v) => setState(() => _vsAI = v),
                  contentPadding: EdgeInsets.zero,
                ),

                // Difficulty
                if (_vsAI) ...[
                  const SizedBox(height: 4),
                  _Section(title: 'AI DIFFICULTY', child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final d in [1, 2, 3])
                        _DifficultyBtn(
                          label: ['Easy', 'Medium', 'Hard'][d - 1],
                          selected: _difficulty == d,
                          onTap: () => setState(() => _difficulty = d),
                        ),
                    ],
                  )),
                ],
                const SizedBox(height: 16),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      widget.game.startGame(
                        format:     _format,
                        vsAI:       _vsAI,
                        difficulty: _difficulty,
                      );
                    },
                    child: const Text('⚽  KICK OFF'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco() => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1a2a3a),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          child,
        ],
      );
}

class _DifficultyBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DifficultyBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: selected ? Colors.black : Colors.white70,
              backgroundColor: selected ? const Color(0xFFFFD700) : Colors.transparent,
              side: BorderSide(
                color: selected ? const Color(0xFFFFD700) : Colors.white30,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: onTap,
            child: Text(label),
          ),
        ),
      );
}
