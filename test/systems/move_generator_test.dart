import 'package:flutter_test/flutter_test.dart';
import 'package:ksr_tactical_football/game/models/game_config.dart';
import 'package:ksr_tactical_football/game/models/grid_pos.dart';
import 'package:ksr_tactical_football/game/models/player_model.dart';
import 'package:ksr_tactical_football/game/systems/game_manager.dart';
import 'package:ksr_tactical_football/game/systems/move_generator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
GameManager freshGM() {
  final gm = GameManager();
  gm.setup(format: GameFormat.f11v11, vsAI: false, difficulty: 1);
  return gm;
}

PlayerModel addPlayer(GameManager gm, int team, GridPos pos,
    {bool hasBall = false, int passing = 7}) {
  final p = PlayerModel(
    teamId: team,
    shirtNumber: gm.allPlayers.length + 1,
    role: PositionRole.cm,
    gridPos: pos,
    hasBall: hasBall,
    passing: passing,
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
  // getMoveCells
  // ------------------------------------------------------------------
  group('getMoveCells', () {
    test('dice 2 (range 1) gives 4 cardinal cells', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(7, 5));
      final cells = MoveGenerator.getMoveCells(gm, p, 2);
      expect(cells.length, 4);
      expect(cells, containsAll([
        const GridPos(8, 5),
        const GridPos(6, 5),
        const GridPos(7, 6),
        const GridPos(7, 4),
      ]));
    });

    test('dice 3 (range 2) gives more cells than dice 2', () {
      final gm  = freshGM();
      final p   = addPlayer(gm, teamHome, const GridPos(7, 5));
      final c2  = MoveGenerator.getMoveCells(gm, p, 2);
      final c3  = MoveGenerator.getMoveCells(gm, p, 3);
      expect(c3.length, greaterThan(c2.length));
    });

    test('range 1: all cells are adjacent (manhattan == 1)', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(7, 5));
      for (final cell in MoveGenerator.getMoveCells(gm, p, 2)) {
        expect(p.gridPos.manhattanTo(cell), 1);
      }
    });

    test('cells at grid edge do not go out of bounds', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(0, 0)); // top-left corner
      for (final cell in MoveGenerator.getMoveCells(gm, p, 3)) {
        expect(gm.isValidCell(cell), isTrue);
      }
    });

    test('occupied cells are still returned (blocking is not filtered here)', () {
      // getMoveCells is raw geometry; move generation filters occupied cells
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(7, 5));
      addPlayer(gm, teamAway, const GridPos(8, 5)); // occupies right cell
      final cells = MoveGenerator.getMoveCells(gm, p, 2);
      // occupied cell still in flood result
      expect(cells.contains(const GridPos(8, 5)), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // getPassCells
  // ------------------------------------------------------------------
  group('getPassCells', () {
    test('returns cells in straight lines', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(7, 5));
      final cells = MoveGenerator.getPassCells(gm, p, 2);
      expect(cells, isNotEmpty);
    });

    test('pass cells further than short range exist for medium dice', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(7, 5));
      final cells = MoveGenerator.getPassCells(gm, p, 2);
      final hasFarCell = cells.any((c) => p.gridPos.manhattanTo(c) > 2);
      expect(hasFarCell, isTrue);
    });

    test('player with passing < 7 gets 0 long range', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(7, 5), passing: 5);
      // Long range is disabled; max step count along any line is medium (4).
      // _lineCells counts Chebyshev steps, so check max(|dx|, |dy|) <= 4.
      final cells = MoveGenerator.getPassCells(gm, p, 2);
      for (final c in cells) {
        final chebyshev = [
          (c.x - p.gridPos.x).abs(),
          (c.y - p.gridPos.y).abs(),
        ].reduce((a, b) => a > b ? a : b);
        expect(chebyshev, lessThanOrEqualTo(4),
            reason: 'cell $c is further than medium range');
      }
    });
  });

  // ------------------------------------------------------------------
  // getShootCells
  // ------------------------------------------------------------------
  group('getShootCells', () {
    test('home team shoots at away goal column', () {
      final gm = freshGM(); // gridWidth=15, awayGoalCol=14
      final p  = addPlayer(gm, teamHome, const GridPos(12, 5));
      final cells = MoveGenerator.getShootCells(gm, p);
      expect(cells, isNotEmpty);
      for (final c in cells) {
        expect(c.x, gm.awayGoalCol);
      }
    });

    test('away team shoots at home goal column', () {
      final gm = freshGM(); // homeGoalCol=0
      final p  = addPlayer(gm, teamAway, const GridPos(3, 5));
      final cells = MoveGenerator.getShootCells(gm, p);
      expect(cells, isNotEmpty);
      for (final c in cells) {
        expect(c.x, gm.homeGoalCol);
      }
    });

    test('returns empty when player is too far from goal', () {
      final gm = freshGM();
      // Put home player far from away goal (distance > 6)
      final p  = addPlayer(gm, teamHome, const GridPos(1, 5));
      // distance to away goal col 14 = 13 > 6
      final cells = MoveGenerator.getShootCells(gm, p);
      expect(cells, isEmpty);
    });

    test('shot cells are only goal rows', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(12, 5));
      for (final c in MoveGenerator.getShootCells(gm, p)) {
        expect(gm.awayGoalRows.contains(c.y), isTrue);
      }
    });
  });

  // ------------------------------------------------------------------
  // getTackleTargets
  // ------------------------------------------------------------------
  group('getTackleTargets', () {
    test('returns adjacent opponent', () {
      final gm  = freshGM();
      final p   = addPlayer(gm, teamHome, const GridPos(5, 5));
      final opp = addPlayer(gm, teamAway, const GridPos(6, 5)); // 1 step away
      final targets = MoveGenerator.getTackleTargets(gm, p);
      expect(targets, contains(opp));
    });

    test('ignores own team player', () {
      final gm       = freshGM();
      final p        = addPlayer(gm, teamHome, const GridPos(5, 5));
      final teammate = addPlayer(gm, teamHome, const GridPos(6, 5));
      final targets  = MoveGenerator.getTackleTargets(gm, p);
      expect(targets, isNot(contains(teammate)));
    });

    test('ignores opponent that is 2 steps away', () {
      final gm  = freshGM();
      final p   = addPlayer(gm, teamHome, const GridPos(5, 5));
      final opp = addPlayer(gm, teamAway, const GridPos(7, 5)); // 2 steps
      final targets = MoveGenerator.getTackleTargets(gm, p);
      expect(targets, isNot(contains(opp)));
    });

    test('returns empty when no adjacent opponents', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(5, 5));
      expect(MoveGenerator.getTackleTargets(gm, p), isEmpty);
    });

    test('can have multiple tackle targets', () {
      final gm   = freshGM();
      final p    = addPlayer(gm, teamHome, const GridPos(5, 5));
      final opp1 = addPlayer(gm, teamAway, const GridPos(6, 5));
      final opp2 = addPlayer(gm, teamAway, const GridPos(4, 5));
      final targets = MoveGenerator.getTackleTargets(gm, p);
      expect(targets, containsAll([opp1, opp2]));
    });
  });

  // ------------------------------------------------------------------
  // generateForPlayer
  // ------------------------------------------------------------------
  group('generateForPlayer', () {
    test('player without ball generates move and tackle moves, no passes', () {
      final gm    = freshGM();
      final p     = addPlayer(gm, teamHome, const GridPos(5, 5));
      addPlayer(gm, teamAway, const GridPos(6, 5)); // adjacent opp enables tackle
      final moves = MoveGenerator.generateForPlayer(gm, p, 2);
      final actionTypes = moves.map((m) => m.action).toSet();
      expect(actionTypes.contains(ActionType.move),   isTrue);
      expect(actionTypes.contains(ActionType.tackle), isTrue);
      expect(actionTypes.contains(ActionType.pass),   isFalse);
      expect(actionTypes.contains(ActionType.shoot),  isFalse);
    });

    test('player with ball generates passes and shots, no tackle', () {
      final gm = freshGM();
      final p  = addPlayer(gm, teamHome, const GridPos(12, 5), hasBall: true);
      // Teammate to pass to
      addPlayer(gm, teamHome, const GridPos(11, 5));
      final moves       = MoveGenerator.generateForPlayer(gm, p, 2);
      final actionTypes = moves.map((m) => m.action).toSet();
      expect(actionTypes.contains(ActionType.pass),   isTrue);
      expect(actionTypes.contains(ActionType.shoot),  isTrue);
      expect(actionTypes.contains(ActionType.tackle), isFalse);
    });

    test('move actions do not target occupied cells', () {
      final gm   = freshGM();
      final p    = addPlayer(gm, teamHome, const GridPos(5, 5));
      addPlayer(gm, teamAway, const GridPos(6, 5)); // blocks right cell
      final moves = MoveGenerator.generateForPlayer(gm, p, 2)
          .where((m) => m.action == ActionType.move);
      for (final m in moves) {
        expect(gm.playerAt(m.target as GridPos), isNull);
      }
    });

    test('generates no moves for a player trapped on all sides', () {
      final gm = freshGM();
      // Place player in a corner
      final p = addPlayer(gm, teamHome, const GridPos(0, 0));
      // Block both adjacent cells
      addPlayer(gm, teamHome, const GridPos(1, 0));
      addPlayer(gm, teamHome, const GridPos(0, 1));
      final moveMoves = MoveGenerator.generateForPlayer(gm, p, 2)
          .where((m) => m.action == ActionType.move)
          .toList();
      expect(moveMoves, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // generateAll
  // ------------------------------------------------------------------
  group('generateAll', () {
    test('returns moves for all players on a team', () {
      final gm = freshGM();
      addPlayer(gm, teamHome, const GridPos(2, 2));
      addPlayer(gm, teamHome, const GridPos(4, 4));
      final moves = MoveGenerator.generateAll(gm, teamHome, 2);
      expect(moves, isNotEmpty);
    });

    test('returns empty when team has no players', () {
      final gm = freshGM();
      expect(MoveGenerator.generateAll(gm, teamHome, 2), isEmpty);
    });
  });
}
