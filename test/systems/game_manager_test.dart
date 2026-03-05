import 'package:flutter_test/flutter_test.dart';
import 'package:ksr_tactical_football/game/models/game_config.dart';
import 'package:ksr_tactical_football/game/models/grid_pos.dart';
import 'package:ksr_tactical_football/game/models/player_model.dart';
import 'package:ksr_tactical_football/game/systems/game_manager.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
GameManager makeGM({GameFormat format = GameFormat.f5v5}) {
  final gm = GameManager();
  gm.setup(format: format, vsAI: false, difficulty: 1);
  return gm;
}

PlayerModel makePlayer(int team, GridPos pos, {bool hasBall = false}) =>
    PlayerModel(
      teamId: team,
      shirtNumber: 1,
      role: PositionRole.cm,
      gridPos: pos,
      hasBall: hasBall,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  // ------------------------------------------------------------------
  // setup()
  // ------------------------------------------------------------------
  group('setup', () {
    test('resets scores and turn counter', () {
      final gm = makeGM();
      gm.homeScore = 3;
      gm.awayScore = 2;
      gm.turnNumber = 10;
      gm.setup(format: GameFormat.f5v5, vsAI: false, difficulty: 1);
      expect(gm.homeScore, 0);
      expect(gm.awayScore, 0);
      expect(gm.turnNumber, 0);
    });

    test('f5v5 gives 9×7 grid', () {
      final gm = makeGM(format: GameFormat.f5v5);
      expect(gm.gridWidth,  9);
      expect(gm.gridHeight, 7);
    });

    test('f7v7 gives 11×9 grid', () {
      final gm = makeGM(format: GameFormat.f7v7);
      expect(gm.gridWidth,  11);
      expect(gm.gridHeight, 9);
    });

    test('f9v9 gives 13×11 grid', () {
      final gm = makeGM(format: GameFormat.f9v9);
      expect(gm.gridWidth,  13);
      expect(gm.gridHeight, 11);
    });

    test('f11v11 gives 15×11 grid', () {
      final gm = makeGM(format: GameFormat.f11v11);
      expect(gm.gridWidth,  15);
      expect(gm.gridHeight, 11);
    });

    test('goal cols are correct', () {
      final gm = makeGM(format: GameFormat.f11v11);
      expect(gm.homeGoalCol, 0);
      expect(gm.awayGoalCol, 14);
    });

    test('goal rows contain centre 3 rows', () {
      final gm = makeGM(format: GameFormat.f5v5); // height 7, mid = 3
      expect(gm.homeGoalRows, [2, 3, 4]);
      expect(gm.awayGoalRows, [2, 3, 4]);
    });

    test('state becomes playing', () {
      final gm = makeGM();
      expect(gm.state, GameState.playing);
    });

    test('player lists are cleared on re-setup', () {
      final gm = makeGM();
      gm.registerPlayer(makePlayer(teamHome, const GridPos(1, 1)));
      gm.setup(format: GameFormat.f5v5, vsAI: false, difficulty: 1);
      expect(gm.allPlayers, isEmpty);
    });
  });

  // ------------------------------------------------------------------
  // Player registry
  // ------------------------------------------------------------------
  group('registerPlayer', () {
    test('home player goes to homePlayers and allPlayers', () {
      final gm = makeGM();
      final p  = makePlayer(teamHome, const GridPos(1, 1));
      gm.registerPlayer(p);
      expect(gm.allPlayers,  contains(p));
      expect(gm.homePlayers, contains(p));
      expect(gm.awayPlayers, isNot(contains(p)));
    });

    test('away player goes to awayPlayers and allPlayers', () {
      final gm = makeGM();
      final p  = makePlayer(teamAway, const GridPos(8, 1));
      gm.registerPlayer(p);
      expect(gm.allPlayers,  contains(p));
      expect(gm.awayPlayers, contains(p));
      expect(gm.homePlayers, isNot(contains(p)));
    });
  });

  // ------------------------------------------------------------------
  // playerAt
  // ------------------------------------------------------------------
  group('playerAt', () {
    test('returns player at exact position', () {
      final gm  = makeGM();
      final pos = const GridPos(3, 4);
      final p   = makePlayer(teamHome, pos);
      gm.registerPlayer(p);
      expect(gm.playerAt(pos), p);
    });

    test('returns null for empty cell', () {
      final gm = makeGM();
      expect(gm.playerAt(const GridPos(5, 5)), isNull);
    });

    test('returns null after player moves away', () {
      final gm  = makeGM();
      final pos = const GridPos(3, 4);
      final p   = makePlayer(teamHome, pos);
      gm.registerPlayer(p);
      p.gridPos = const GridPos(9, 9);
      expect(gm.playerAt(pos), isNull);
    });
  });

  // ------------------------------------------------------------------
  // isValidCell
  // ------------------------------------------------------------------
  group('isValidCell', () {
    test('centre cell is valid', () {
      final gm = makeGM(); // 9×7
      expect(gm.isValidCell(const GridPos(4, 3)), isTrue);
    });

    test('(0,0) is valid', () {
      expect(makeGM().isValidCell(const GridPos(0, 0)), isTrue);
    });

    test('last cell (8,6) is valid for 9×7 grid', () {
      expect(makeGM().isValidCell(const GridPos(8, 6)), isTrue);
    });

    test('negative x is invalid', () {
      expect(makeGM().isValidCell(const GridPos(-1, 3)), isFalse);
    });

    test('x == gridWidth is invalid', () {
      final gm = makeGM(); // width=9
      expect(gm.isValidCell(GridPos(gm.gridWidth, 3)), isFalse);
    });

    test('negative y is invalid', () {
      expect(makeGM().isValidCell(const GridPos(4, -1)), isFalse);
    });

    test('y == gridHeight is invalid', () {
      final gm = makeGM(); // height=7
      expect(gm.isValidCell(GridPos(4, gm.gridHeight)), isFalse);
    });
  });

  // ------------------------------------------------------------------
  // checkGoal
  // ------------------------------------------------------------------
  group('checkGoal', () {
    test('shot into home goal scores for away team', () {
      final gm = makeGM(); // f5v5, mid=3, rows=[2,3,4]
      expect(gm.checkGoal(const GridPos(0, 3)), teamAway);
    });

    test('shot into away goal scores for home team', () {
      final gm = makeGM();
      expect(gm.checkGoal(GridPos(gm.awayGoalCol, 3)), teamHome);
    });

    test('off-row home goal cell is not a goal', () {
      final gm = makeGM();
      expect(gm.checkGoal(const GridPos(0, 0)), isNull);
    });

    test('non-goal column is not a goal', () {
      final gm = makeGM();
      expect(gm.checkGoal(const GridPos(4, 3)), isNull);
    });
  });

  // ------------------------------------------------------------------
  // Ball management
  // ------------------------------------------------------------------
  group('setBallCarrier', () {
    test('player gains hasBall', () {
      final gm = makeGM();
      final p  = makePlayer(teamHome, const GridPos(2, 2));
      gm.registerPlayer(p);
      gm.setBallCarrier(p);
      expect(p.hasBall, isTrue);
      expect(gm.ballCarrier, p);
    });

    test('previous carrier loses hasBall', () {
      final gm = makeGM();
      final p1 = makePlayer(teamHome, const GridPos(2, 2));
      final p2 = makePlayer(teamHome, const GridPos(3, 2));
      gm.registerPlayer(p1);
      gm.registerPlayer(p2);
      gm.setBallCarrier(p1);
      gm.setBallCarrier(p2);
      expect(p1.hasBall, isFalse);
      expect(p2.hasBall, isTrue);
    });

    test('setting null clears carrier', () {
      final gm = makeGM();
      final p  = makePlayer(teamHome, const GridPos(2, 2));
      gm.setBallCarrier(p);
      gm.setBallCarrier(null);
      expect(gm.ballCarrier, isNull);
      expect(p.hasBall, isFalse);
    });

    test('ballPos syncs to carrier gridPos', () {
      final gm  = makeGM();
      final pos = const GridPos(4, 4);
      final p   = makePlayer(teamHome, pos);
      gm.setBallCarrier(p);
      expect(gm.ballPos, pos);
    });
  });

  group('dropBallAt', () {
    test('sets ballPos and clears carrier', () {
      final gm  = makeGM();
      final p   = makePlayer(teamHome, const GridPos(2, 2));
      final pos = const GridPos(7, 5);
      gm.registerPlayer(p);
      gm.setBallCarrier(p);
      gm.dropBallAt(pos);
      expect(gm.ballPos,    pos);
      expect(gm.ballCarrier, isNull);
      expect(p.hasBall, isFalse);
    });
  });

  group('syncBallWithCarrier', () {
    test('moves ballPos to carrier current position', () {
      final gm  = makeGM();
      final p   = makePlayer(teamHome, const GridPos(2, 2));
      gm.registerPlayer(p);
      gm.setBallCarrier(p);
      p.gridPos = const GridPos(5, 5);
      gm.syncBallWithCarrier();
      expect(gm.ballPos, const GridPos(5, 5));
    });

    test('does nothing when no carrier', () {
      final gm = makeGM();
      gm.ballPos = const GridPos(3, 3);
      gm.syncBallWithCarrier();
      expect(gm.ballPos, const GridPos(3, 3));
    });
  });

  // ------------------------------------------------------------------
  // Scoring
  // ------------------------------------------------------------------
  group('recordGoal', () {
    test('increments home score', () {
      final gm = makeGM();
      gm.recordGoal(teamHome);
      expect(gm.homeScore, 1);
      expect(gm.awayScore, 0);
    });

    test('increments away score', () {
      final gm = makeGM();
      gm.recordGoal(teamAway);
      expect(gm.awayScore, 1);
    });

    test('resets ball to centre after goal', () {
      final gm = makeGM(); // 9×7, centre = (4,3)
      gm.recordGoal(teamHome);
      expect(gm.ballPos, GridPos(gm.gridWidth ~/ 2, gm.gridHeight ~/ 2));
    });

    test('clears ball carrier after goal', () {
      final gm = makeGM();
      final p  = makePlayer(teamHome, const GridPos(2, 2));
      gm.registerPlayer(p);
      gm.setBallCarrier(p);
      gm.recordGoal(teamHome);
      expect(gm.ballCarrier, isNull);
    });
  });

  // ------------------------------------------------------------------
  // advanceTurn
  // ------------------------------------------------------------------
  group('advanceTurn', () {
    test('increments turn number', () {
      final gm = makeGM();
      gm.advanceTurn();
      expect(gm.turnNumber, 1);
    });

    test('transitions to gameOver at maxTurns', () {
      final gm = makeGM();
      gm.maxTurns = 3;
      gm.turnNumber = 2;
      gm.advanceTurn();
      expect(gm.state, GameState.gameOver);
    });

    test('does not transition before maxTurns', () {
      final gm = makeGM();
      gm.maxTurns = 5;
      gm.turnNumber = 3;
      gm.advanceTurn();
      expect(gm.state, GameState.playing);
    });
  });

  // ------------------------------------------------------------------
  // opponentTeam
  // ------------------------------------------------------------------
  group('opponentTeam', () {
    test('home → away', () {
      expect(makeGM().opponentTeam(teamHome), teamAway);
    });
    test('away → home', () {
      expect(makeGM().opponentTeam(teamAway), teamHome);
    });
  });

  // ------------------------------------------------------------------
  // Snapshot / restore
  // ------------------------------------------------------------------
  group('takeSnapshot / restoreSnapshot', () {
    test('restores player positions', () {
      final gm = makeGM();
      final p  = makePlayer(teamHome, const GridPos(3, 3));
      gm.registerPlayer(p);
      final snap = gm.takeSnapshot();

      p.gridPos = const GridPos(9, 9);
      gm.restoreSnapshot(snap);

      expect(p.gridPos, const GridPos(3, 3));
    });

    test('restores ball position', () {
      final gm = makeGM();
      gm.ballPos = const GridPos(4, 4);
      final snap = gm.takeSnapshot();

      gm.ballPos = const GridPos(0, 0);
      gm.restoreSnapshot(snap);

      expect(gm.ballPos, const GridPos(4, 4));
    });

    test('restores scores', () {
      final gm = makeGM();
      gm.homeScore = 2;
      gm.awayScore = 1;
      final snap = gm.takeSnapshot();

      gm.homeScore = 5;
      gm.awayScore = 5;
      gm.restoreSnapshot(snap);

      expect(gm.homeScore, 2);
      expect(gm.awayScore, 1);
    });

    test('restores ball carrier reference', () {
      final gm = makeGM();
      final p  = makePlayer(teamHome, const GridPos(3, 3));
      gm.registerPlayer(p);
      gm.setBallCarrier(p);
      final snap = gm.takeSnapshot();

      gm.dropBallAt(const GridPos(0, 0));
      gm.restoreSnapshot(snap);

      // ballCarrier reference is restored (it's the same object)
      expect(gm.ballCarrier, p);
    });
  });
}
