import 'package:flutter/material.dart';
import '../../game/models/game_config.dart';
import '../../game/tactical_football_game.dart';

/// Full HUD: wraps TopPanel + BottomPanel + floating message.
class HudOverlay extends StatefulWidget {
  final TacticalFootballGame game;
  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  TacticalFootballGame get g => widget.game;

  @override
  void initState() {
    super.initState();
    g.turnManager.addListener(_rebuild);
    g.gameManager.addListener(_rebuild);
    g.diceSystem.addListener(_rebuild);
  }

  @override
  void dispose() {
    g.turnManager.removeListener(_rebuild);
    g.gameManager.removeListener(_rebuild);
    g.diceSystem.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final gm = g.gameManager;
    final tm = g.turnManager;
    final ds = g.diceSystem;

    return Column(
      children: [
        // ── Top Panel ───────────────────────────────────────────────────
        _TopPanel(
          homeScore:   gm.homeScore,
          awayScore:   gm.awayScore,
          turn:        gm.turnNumber,
          maxTurns:    gm.maxTurns,
          diceResult:  ds.lastResult,
          actionsLeft: tm.actionsLeft,
          activeTeam:  tm.currentTeam,
          phase:       tm.phase,
          message:     tm.lastMessage,
        ),

        const Spacer(),

        // ── Bottom Panel ─────────────────────────────────────────────────
        _BottomPanel(
          game:  g,
          phase: tm.phase,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Top Panel
// ---------------------------------------------------------------------------
class _TopPanel extends StatelessWidget {
  final int    homeScore, awayScore, turn, maxTurns, diceResult, actionsLeft, activeTeam;
  final TurnPhase phase;
  final String message;

  const _TopPanel({
    required this.homeScore,
    required this.awayScore,
    required this.turn,
    required this.maxTurns,
    required this.diceResult,
    required this.actionsLeft,
    required this.activeTeam,
    required this.phase,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xDD0A1628),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Home score
          _TeamScore(label: 'HOME', score: homeScore, active: activeTeam == teamHome,
              color: homeColor),
          // Centre info
          Expanded(
            child: Column(
              children: [
                Text(
                  'Turn $turn / $maxTurns',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                if (diceResult > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _diceFace(diceResult),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Actions: $actionsLeft',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Away score
          _TeamScore(label: 'AWAY', score: awayScore, active: activeTeam == teamAway,
              color: awayColor),
        ],
      ),
    );
  }

  String _diceFace(int n) => ['⚀', '⚁', '⚂', '⚃', '⚄', '⚅'][n - 1];
}

class _TeamScore extends StatelessWidget {
  final String label;
  final int    score;
  final bool   active;
  final Color  color;

  const _TeamScore(
      {required this.label, required this.score, required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: active ? Border.all(color: color, width: 2) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: active ? color : Colors.white38,
                  fontSize: 9,
                  letterSpacing: 1)),
          Text('$score',
              style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Panel
// ---------------------------------------------------------------------------
class _BottomPanel extends StatelessWidget {
  final TacticalFootballGame game;
  final TurnPhase phase;

  const _BottomPanel({required this.game, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xDD0A1628),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: _buildButtons(context),
    );
  }

  Widget _buildButtons(BuildContext context) {
    switch (phase) {
      case TurnPhase.awaitingRoll:
        return _row([_actionBtn('🎲  ROLL', () => game.onRollDice(),
            color: const Color(0xFFFFD700), textColor: Colors.black)]);

      case TurnPhase.selectingPlayer:
        return _row([
          _actionBtn('Skip', () => game.onSkipAction(), compact: true),
        ]);

      case TurnPhase.selectingAction:
        final hasBall = game.turnManager.selectedPlayer?.hasBall ?? false;
        return _row([
          _actionBtn('Move',    () => game.onActionSelected(ActionType.move)),
          if (hasBall) _actionBtn('Pass',    () => game.onActionSelected(ActionType.pass)),
          if (hasBall) _actionBtn('Dribble', () => game.onActionSelected(ActionType.dribble)),
          if (hasBall) _actionBtn('Shoot',   () => game.onActionSelected(ActionType.shoot),
              color: const Color(0xFFFF6633)),
          if (!hasBall) _actionBtn('Tackle',  () => game.onActionSelected(ActionType.tackle),
              color: const Color(0xFF6633FF)),
          if (!game.turnManager.tacticCardUsed)
            _actionBtn('Card', () {
              game.overlays.add(TacticalFootballGame.overlayCardPanel);
            }, compact: true),
          _actionBtn('Cancel', () => game.onCancelSelection(), compact: true),
        ]);

      case TurnPhase.awaitingTarget:
        return _row([
          const Expanded(
            child: Center(
              child: Text('Tap a highlighted tile',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ),
          _actionBtn('Cancel', () => game.onCancelSelection(), compact: true),
        ]);

      case TurnPhase.aiThinking:
        return _row([
          const Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                  SizedBox(width: 10),
                  Text('Opponent thinking…',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
          ),
        ]);

      default:
        return const SizedBox(height: 44);
    }
  }

  Widget _row(List<Widget> children) => SizedBox(
        height: 44,
        child: Row(children: children),
      );

  Widget _actionBtn(String label, VoidCallback onPressed,
      {bool compact = false, Color? color, Color? textColor}) {
    final btn = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF1E3A5F),
        foregroundColor: textColor ?? Colors.white,
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 10)
            : const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 38),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
    if (compact) return Padding(padding: const EdgeInsets.only(left: 4), child: btn);
    return Expanded(child: Padding(padding: const EdgeInsets.only(left: 4), child: btn));
  }
}
