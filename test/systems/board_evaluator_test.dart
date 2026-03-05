import 'package:flutter_test/flutter_test.dart';
import 'package:ksr_tactical_football/game/models/game_config.dart';
import 'package:ksr_tactical_football/game/models/grid_pos.dart';
import 'package:ksr_tactical_football/game/models/player_model.dart';
import 'package:ksr_tactical_football/game/systems/board_evaluator.dart';
import 'package:ksr_tactical_football/game/systems/game_manager.dart';

GameManager freshGM() {
  final gm = GameManager();
  gm.setup(format: GameFormat.f11v11, vsAI: false, difficulty: 1);
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

void main() {
  // ------------------------------------------------------------------
  // Ball progress
  // ------------------------------------------------------------------
  group('ball progress scoring', () {
    test('home team scores higher when ball is near away goal', () {
      final gmNear = freshGM();
      addPlayer(gmNear, teamHome, const GridPos(13, 5), hasBall: true);

      final gmFar = freshGM();
      addPlayer(gmFar, teamHome, const GridPos(2, 5), hasBall: true);

      final near = BoardEvaluator.evaluate(gmNear, teamHome, 2);
      final far  = BoardEvaluator.evaluate(gmFar,  teamHome, 2);
      expect(near, greaterThan(far));
    });

    test('away team scores higher when ball is near home goal', () {
      final gmNear = freshGM();
      addPlayer(gmNear, teamAway, const GridPos(1, 5), hasBall: true);

      final gmFar = freshGM();
      addPlayer(gmFar, teamAway, const GridPos(13, 5), hasBall: true);

      expect(
        BoardEvaluator.evaluate(gmNear, teamAway, 2),
        greaterThan(BoardEvaluator.evaluate(gmFar, teamAway, 2)),
      );
    });

    test('carrying team scores higher than non-carrying team for same ball pos', () {
      final gmCarrying = freshGM();
      addPlayer(gmCarrying, teamHome, const GridPos(10, 5), hasBall: true);

      final gmLoose = freshGM();
      addPlayer(gmLoose, teamHome, const GridPos(10, 5));
      gmLoose.ballPos = const GridPos(10, 5); // ball loose at same spot

      expect(
        BoardEvaluator.evaluate(gmCarrying, teamHome, 2),
        greaterThan(BoardEvaluator.evaluate(gmLoose, teamHome, 2)),
      );
    });
  });

  // ------------------------------------------------------------------
  // Shot opportunity
  // ------------------------------------------------------------------
  group('shot opportunity scoring', () {
    test('player in shooting range increases score', () {
      final gmInRange = freshGM();
      addPlayer(gmInRange, teamHome, const GridPos(12, 5), hasBall: true);

      final gmFar = freshGM();
      addPlayer(gmFar, teamHome, const GridPos(3, 5), hasBall: true);

      expect(
        BoardEvaluator.evaluate(gmInRange, teamHome, 2),
        greaterThan(BoardEvaluator.evaluate(gmFar, teamHome, 2)),
      );
    });
  });

  // ------------------------------------------------------------------
  // Defensive pressure
  // ------------------------------------------------------------------
  group('defensive pressure', () {
    test('opponents near own goal reduces score', () {
      final gmSafe = freshGM();
      // Opponent far from home goal
      addPlayer(gmSafe, teamHome, const GridPos(7, 5));
      addPlayer(gmSafe, teamAway, const GridPos(13, 5));

      final gmDanger = freshGM();
      // Opponent right at home goal
      addPlayer(gmDanger, teamHome, const GridPos(7, 5));
      addPlayer(gmDanger, teamAway, const GridPos(1, 5));

      expect(
        BoardEvaluator.evaluate(gmSafe, teamHome, 2),
        greaterThan(BoardEvaluator.evaluate(gmDanger, teamHome, 2)),
      );
    });
  });

  // ------------------------------------------------------------------
  // Terminal score
  // ------------------------------------------------------------------
  group('terminal score', () {
    test('winning team at game over gets large positive score', () {
      final gm = freshGM();
      gm.state     = GameState.gameOver;
      gm.homeScore = 2;
      gm.awayScore = 0;
      final score = BoardEvaluator.evaluate(gm, teamHome, 2);
      expect(score, greaterThan(500.0));
    });

    test('losing team at game over gets large negative score', () {
      final gm = freshGM();
      gm.state     = GameState.gameOver;
      gm.homeScore = 0;
      gm.awayScore = 2;
      final score = BoardEvaluator.evaluate(gm, teamHome, 2);
      expect(score, lessThan(-500.0));
    });

    test('draw at game over gives 0', () {
      final gm = freshGM();
      gm.state     = GameState.gameOver;
      gm.homeScore = 1;
      gm.awayScore = 1;
      expect(BoardEvaluator.evaluate(gm, teamHome, 2), 0.0);
    });
  });

  // ------------------------------------------------------------------
  // Player spread bonus
  // ------------------------------------------------------------------
  group('spread bonus', () {
    test('wider spread gives higher score', () {
      final gmSpread = freshGM();
      addPlayer(gmSpread, teamHome, const GridPos(2, 5));
      addPlayer(gmSpread, teamHome, const GridPos(7, 5));
      addPlayer(gmSpread, teamHome, const GridPos(12, 5));

      final gmBunched = freshGM();
      addPlayer(gmBunched, teamHome, const GridPos(7, 4));
      addPlayer(gmBunched, teamHome, const GridPos(7, 5));
      addPlayer(gmBunched, teamHome, const GridPos(7, 6));

      expect(
        BoardEvaluator.evaluate(gmSpread, teamHome, 2),
        greaterThan(BoardEvaluator.evaluate(gmBunched, teamHome, 2)),
      );
    });
  });
}
