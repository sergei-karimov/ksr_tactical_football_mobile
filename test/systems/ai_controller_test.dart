import 'package:flutter_test/flutter_test.dart';
import 'package:ksr_tactical_football/game/models/game_config.dart';
import 'package:ksr_tactical_football/game/models/grid_pos.dart';
import 'package:ksr_tactical_football/game/models/player_model.dart';
import 'package:ksr_tactical_football/game/systems/ai_controller.dart';
import 'package:ksr_tactical_football/game/systems/dice_system.dart';
import 'package:ksr_tactical_football/game/systems/game_manager.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
GameManager freshGM({GameFormat format = GameFormat.f5v5}) {
  final gm = GameManager();
  gm.setup(format: format, vsAI: true, difficulty: 2);
  return gm;
}

PlayerModel addPlayer(GameManager gm, int team, GridPos pos,
    {bool hasBall = false, PositionRole role = PositionRole.cm}) {
  final p = PlayerModel(
    teamId: team, shirtNumber: gm.allPlayers.length + 1,
    role: role, gridPos: pos, hasBall: hasBall,
  );
  gm.registerPlayer(p);
  if (hasBall) gm.setBallCarrier(p);
  return p;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  // ------------------------------------------------------------------
  // Snapshot / restore integrity (via GameManager, used by AI)
  // ------------------------------------------------------------------
  group('snapshot / restore (board-level)', () {
    test('restoring snapshot after all mutations returns to original state', () {
      final gm = freshGM();
      final p1 = addPlayer(gm, teamHome, const GridPos(3, 3));
      final p2 = addPlayer(gm, teamAway, const GridPos(6, 3), hasBall: true);
      gm.homeScore = 1;
      gm.awayScore = 0;

      final snap = gm.takeSnapshot();

      // Mutate everything
      p1.gridPos = const GridPos(9, 9);
      p2.hasBall = false;
      gm.ballPos     = const GridPos(0, 0);
      gm.ballCarrier = null;
      gm.homeScore   = 99;
      gm.awayScore   = 88;

      gm.restoreSnapshot(snap);

      expect(p1.gridPos,   const GridPos(3, 3));
      expect(p2.hasBall,   isTrue);
      expect(gm.ballPos,   p2.gridPos);
      expect(gm.homeScore, 1);
      expect(gm.awayScore, 0);
    });

    test('double snapshot/restore is idempotent', () {
      final gm   = freshGM();
      final p    = addPlayer(gm, teamHome, const GridPos(4, 4));
      final snap = gm.takeSnapshot();

      // First restore
      p.gridPos = const GridPos(0, 0);
      gm.restoreSnapshot(snap);
      expect(p.gridPos, const GridPos(4, 4));

      // Mutate again and restore again
      p.gridPos = const GridPos(8, 8);
      gm.restoreSnapshot(snap);
      expect(p.gridPos, const GridPos(4, 4));
    });
  });

  // ------------------------------------------------------------------
  // executeAITurn – smoke tests (does not crash, valid state after)
  // ------------------------------------------------------------------
  group('executeAITurn', () {
    test('does not throw at depth 1', () {
      final gm = freshGM();
      _addMinimalTeams(gm);
      final ai = AIController(gm, DiceSystem());
      expect(() => ai.executeAITurn(teamAway, 1), returnsNormally);
    });

    test('does not throw at depth 2', () {
      final gm = freshGM();
      _addMinimalTeams(gm);
      final ai = AIController(gm, DiceSystem());
      expect(() => ai.executeAITurn(teamAway, 2), returnsNormally);
    });

    test('does not throw at depth 3', () {
      final gm = freshGM();
      _addMinimalTeams(gm);
      final ai = AIController(gm, DiceSystem());
      expect(() => ai.executeAITurn(teamAway, 3), returnsNormally);
    });

    test('game state remains valid after AI turn', () {
      final gm = freshGM();
      _addMinimalTeams(gm);
      final ai = AIController(gm, DiceSystem());
      ai.executeAITurn(teamAway, 2);

      // All players should still be in valid cells
      for (final p in gm.allPlayers) {
        expect(gm.isValidCell(p.gridPos), isTrue,
            reason: 'Player ${p.shirtNumber} at ${p.gridPos} is out of bounds');
      }
    });

    test('exactly one player has ball or ball is loose after AI turn', () {
      final gm = freshGM();
      _addMinimalTeams(gm);
      final ai = AIController(gm, DiceSystem());
      ai.executeAITurn(teamAway, 2);

      final playersWithBall = gm.allPlayers.where((p) => p.hasBall).toList();
      expect(playersWithBall.length, lessThanOrEqualTo(1));
    });

    test('AI with no available moves does not crash', () {
      final gm = freshGM();
      // Only add home team – away team has nothing to move
      addPlayer(gm, teamHome, const GridPos(4, 3), hasBall: true);
      final ai = AIController(gm, DiceSystem());
      expect(() => ai.executeAITurn(teamAway, 2), returnsNormally);
    });
  });

  // ------------------------------------------------------------------
  // AI moves toward goal (directional preference)
  // ------------------------------------------------------------------
  group('AI directional preference', () {
    test('AI with ball carrier moves ball closer to home goal (depth 1)', () {
      final gm = freshGM();
      // Away team ball carrier near home goal
      final carrier = addPlayer(gm, teamAway, const GridPos(5, 3), hasBall: true);
      // Add home GK
      addPlayer(gm, teamHome, const GridPos(0, 3), role: PositionRole.gk);

      final startX = carrier.gridPos.x;
      final ai     = AIController(gm, DiceSystem());
      ai.executeAITurn(teamAway, 1); // depth 1

      // Away attacks leftward; expect ball to have moved left (smaller x)
      // or a goal was scored (ball reset)
      final movedLeft  = gm.ballPos.x < startX;
      final goalScored = gm.awayScore > 0;
      expect(movedLeft || goalScored, isTrue,
          reason: 'Expected ball to move toward home goal. '
              'ballPos=${gm.ballPos}, startX=$startX, goals=${gm.awayScore}');
    });
  });
}

// ---------------------------------------------------------------------------
// Helper: add minimal teams (3 players each) for smoke tests
// ---------------------------------------------------------------------------
void _addMinimalTeams(GameManager gm) {
  // Home
  addPlayer(gm, teamHome, const GridPos(1, 3), role: PositionRole.gk);
  addPlayer(gm, teamHome, const GridPos(2, 3));
  addPlayer(gm, teamHome, const GridPos(3, 3));

  // Away – carrier has ball
  addPlayer(gm, teamAway, const GridPos(7, 3), hasBall: true);
  addPlayer(gm, teamAway, const GridPos(6, 3));
  addPlayer(gm, teamAway, const GridPos(5, 3));
}
