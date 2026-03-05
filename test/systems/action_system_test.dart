import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ksr_tactical_football/game/models/game_config.dart';
import 'package:ksr_tactical_football/game/models/grid_pos.dart';
import 'package:ksr_tactical_football/game/models/move_data.dart';
import 'package:ksr_tactical_football/game/models/player_model.dart';
import 'package:ksr_tactical_football/game/systems/action_system.dart';
import 'package:ksr_tactical_football/game/systems/game_manager.dart';

// ---------------------------------------------------------------------------
// Seeded Random helpers
// ---------------------------------------------------------------------------

/// Always returns 0.0 – every probabilistic check passes.
class _AlwaysSucceedRandom implements Random {
  @override double nextDouble() => 0.0;
  @override int    nextInt(int max) => 0;
  @override bool   nextBool() => true;
}

/// Always returns 1.0 – every probabilistic check fails.
class _AlwaysFailRandom implements Random {
  @override double nextDouble() => 1.0;
  @override int    nextInt(int max) => max - 1;
  @override bool   nextBool() => false;
}

// ---------------------------------------------------------------------------
// Setup helpers
// ---------------------------------------------------------------------------
GameManager freshGM() {
  final gm = GameManager();
  gm.setup(format: GameFormat.f11v11, vsAI: false, difficulty: 1);
  return gm;
}

PlayerModel addPlayer(GameManager gm, int team, GridPos pos,
    {bool hasBall = false,
    int shooting = 7,
    int passing  = 7,
    int dribbling = 7,
    int defending = 7,
    PositionRole role = PositionRole.cm}) {
  final p = PlayerModel(
    teamId: team,
    shirtNumber: gm.allPlayers.length + 1,
    role: role,
    gridPos: pos,
    hasBall: hasBall,
    shooting: shooting,
    passing: passing,
    dribbling: dribbling,
    defending: defending,
  );
  gm.registerPlayer(p);
  if (hasBall) gm.setBallCarrier(p);
  return p;
}

ActionSystem successAS(GameManager gm) =>
    ActionSystem(gm, rng: _AlwaysSucceedRandom());

ActionSystem failAS(GameManager gm) =>
    ActionSystem(gm, rng: _AlwaysFailRandom());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  // ====================================================================
  // MOVE
  // ====================================================================
  group('Move action', () {
    test('valid move updates player position', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5));
      final target = const GridPos(6, 5);
      final result = successAS(gm).execute(
        MoveData(action: ActionType.move, player: player, target: target), 2);
      expect(result.success, isTrue);
      expect(player.gridPos, target);
    });

    test('move syncs ball position when player has ball', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      final target = const GridPos(6, 5);
      successAS(gm).execute(
        MoveData(action: ActionType.move, player: player, target: target), 2);
      expect(gm.ballPos, target);
    });

    test('move fails when target cell is out of bounds', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(0, 0));
      final result = successAS(gm).execute(
        MoveData(action: ActionType.move, player: player, target: const GridPos(-1, 0)), 2);
      expect(result.success, isFalse);
      expect(player.gridPos, const GridPos(0, 0)); // unchanged
    });

    test('move fails when target is occupied', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5));
      addPlayer(gm, teamAway, const GridPos(6, 5)); // block
      final result = successAS(gm).execute(
        MoveData(action: ActionType.move, player: player, target: const GridPos(6, 5)), 2);
      expect(result.success, isFalse);
    });

    test('move fails when target is out of move range', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5));
      // dice 2 → range 1, but target is 3 tiles away
      final result = successAS(gm).execute(
        MoveData(action: ActionType.move, player: player, target: const GridPos(8, 5)), 2);
      expect(result.success, isFalse);
    });

    test('dice 3 allows 2-tile move', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5));
      final target = const GridPos(7, 5); // 2 tiles
      final result = successAS(gm).execute(
        MoveData(action: ActionType.move, player: player, target: target), 3);
      expect(result.success, isTrue);
      expect(player.gridPos, target);
    });
  });

  // ====================================================================
  // PASS
  // ====================================================================
  group('Pass action', () {
    test('valid short pass transfers ball to teammate', () {
      final gm       = freshGM();
      final passer   = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      final receiver = addPlayer(gm, teamHome, const GridPos(7, 5)); // 2 tiles = short
      final result   = successAS(gm).execute(
        MoveData(action: ActionType.pass, player: passer, target: receiver), 2);
      expect(result.success, isTrue);
      expect(receiver.hasBall, isTrue);
      expect(passer.hasBall, isFalse);
    });

    test('pass fails when player does not have ball', () {
      final gm       = freshGM();
      final passer   = addPlayer(gm, teamHome, const GridPos(5, 5));
      final receiver = addPlayer(gm, teamHome, const GridPos(6, 5));
      final result   = successAS(gm).execute(
        MoveData(action: ActionType.pass, player: passer, target: receiver), 2);
      expect(result.success, isFalse);
    });

    test('pass fails to opponent player', () {
      final gm     = freshGM();
      final passer = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      final target = addPlayer(gm, teamAway, const GridPos(6, 5));
      final result = successAS(gm).execute(
        MoveData(action: ActionType.pass, player: passer, target: target), 2);
      expect(result.success, isFalse);
    });

    test('pass fails when target is out of range', () {
      final gm       = freshGM();
      final passer   = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true, passing: 5);
      // passing < 7 so long pass = 0; medium = 4 tiles
      final receiver = addPlayer(gm, teamHome, const GridPos(5, 10)); // 5 tiles – out of range
      final result   = successAS(gm).execute(
        MoveData(action: ActionType.pass, player: passer, target: receiver), 2);
      expect(result.success, isFalse);
    });

    test('interception: ball goes to interceptor when rng always fails passer', () {
      final gm         = freshGM();
      final passer     = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      final receiver   = addPlayer(gm, teamHome, const GridPos(5, 9)); // 4 tiles
      final interceptor = addPlayer(gm, teamAway, const GridPos(5, 7)); // on the line
      // AlwaysSucceedRandom means interceptor roll (nextDouble=0.0) is < prob → intercepts
      final result = successAS(gm).execute(
        MoveData(action: ActionType.pass, player: passer, target: receiver), 2);
      expect(result.success, isTrue);
      expect(result.ballTaken, isTrue);
      expect(gm.ballCarrier, interceptor);
    });

    test('no_intercept bonus bypasses interception', () {
      final gm         = freshGM();
      final passer     = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      passer.bonuses['no_intercept'] = true;
      final receiver   = addPlayer(gm, teamHome, const GridPos(5, 9));
      addPlayer(gm, teamAway, const GridPos(5, 7)); // on line but ignored
      final result = successAS(gm).execute(
        MoveData(action: ActionType.pass, player: passer, target: receiver), 2);
      expect(result.ballTaken, isFalse);
      expect(gm.ballCarrier, receiver);
    });
  });

  // ====================================================================
  // DRIBBLE
  // ====================================================================
  group('Dribble action', () {
    test('uncontested dribble moves player and ball', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      final target = const GridPos(6, 5);
      final result = successAS(gm).execute(
        MoveData(action: ActionType.dribble, player: player, target: target), 2);
      expect(result.success, isTrue);
      expect(player.gridPos, target);
      expect(gm.ballPos, target);
    });

    test('dribble fails when player has no ball', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5));
      final result = successAS(gm).execute(
        MoveData(action: ActionType.dribble, player: player, target: const GridPos(6, 5)), 2);
      expect(result.success, isFalse);
    });

    test('dribble fails when blocked by teammate', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      addPlayer(gm, teamHome, const GridPos(6, 5)); // teammate blocks
      final result = successAS(gm).execute(
        MoveData(action: ActionType.dribble, player: player, target: const GridPos(6, 5)), 2);
      expect(result.success, isFalse);
    });

    test('contested dribble success: player moves past defender', () {
      final gm       = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      addPlayer(gm, teamAway, const GridPos(6, 5)); // defender must be present
      final result = successAS(gm).execute(  // AlwaysSucceed → prob check passes
        MoveData(action: ActionType.dribble, player: player, target: const GridPos(6, 5)), 2);
      expect(result.success, isTrue);
      expect(result.ballTaken, isFalse);
      expect(player.gridPos, const GridPos(6, 5));
    });

    test('contested dribble failure: ball goes to defender', () {
      final gm       = freshGM();
      final player   = addPlayer(gm, teamHome, const GridPos(5, 5), hasBall: true);
      final defender = addPlayer(gm, teamAway, const GridPos(6, 5));
      final result   = failAS(gm).execute(  // AlwaysFail → prob check fails
        MoveData(action: ActionType.dribble, player: player, target: const GridPos(6, 5)), 2);
      expect(result.success, isTrue);
      expect(result.ballTaken, isTrue);
      expect(gm.ballCarrier, defender);
      expect(player.hasBall, isFalse);
    });
  });

  // ====================================================================
  // SHOOT
  // ====================================================================
  group('Shoot action', () {
    test('successful shot records a goal', () {
      final gm     = freshGM(); // awayGoalCol=14, goalRows=[4,5,6]
      final player = addPlayer(gm, teamHome, const GridPos(13, 5), hasBall: true);
      final target = GridPos(gm.awayGoalCol, 5);
      final result = successAS(gm).execute(
        MoveData(action: ActionType.shoot, player: player, target: target), 2);
      expect(result.success, isTrue);
      expect(result.goalScored, isTrue);
      expect(gm.homeScore, 1);
    });

    test('missed shot does not score', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(13, 5), hasBall: true);
      final target = GridPos(gm.awayGoalCol, 5);
      final result = failAS(gm).execute(
        MoveData(action: ActionType.shoot, player: player, target: target), 2);
      expect(result.goalScored, isFalse);
      expect(gm.homeScore, 0);
    });

    test('shoot fails when player has no ball', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(13, 5));
      final target = GridPos(gm.awayGoalCol, 5);
      final result = successAS(gm).execute(
        MoveData(action: ActionType.shoot, player: player, target: target), 2);
      expect(result.success, isFalse);
    });

    test('shoot fails when aimed at wrong goal', () {
      final gm     = freshGM();
      // Home player aiming at home goal (wrong direction)
      final player = addPlayer(gm, teamHome, const GridPos(1, 5), hasBall: true);
      final target = GridPos(gm.homeGoalCol, 5); // own goal target
      final result = successAS(gm).execute(
        MoveData(action: ActionType.shoot, player: player, target: target), 2);
      expect(result.success, isFalse);
    });

    test('sweeper keeper blocks long shots', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(11, 5), hasBall: true);
      // Away GK with sweeper keeper bonus
      final gk     = addPlayer(gm, teamAway, const GridPos(14, 5),
          role: PositionRole.gk);
      gk.bonuses['block_long_shots'] = true;

      final target = GridPos(gm.awayGoalCol, 5); // dist = 3 → blocked
      // Even with always-succeed rng, prob is set to 0 by sweeper keeper
      final result = successAS(gm).execute(
        MoveData(action: ActionType.shoot, player: player, target: target), 2);
      expect(result.goalScored, isFalse);
    });

    test('goal resets ball to centre', () {
      final gm     = freshGM();
      final player = addPlayer(gm, teamHome, const GridPos(13, 5), hasBall: true);
      final target = GridPos(gm.awayGoalCol, 5);
      successAS(gm).execute(
        MoveData(action: ActionType.shoot, player: player, target: target), 2);
      expect(gm.ballPos, GridPos(gm.gridWidth ~/ 2, gm.gridHeight ~/ 2));
      expect(gm.ballCarrier, isNull);
    });
  });

  // ====================================================================
  // TACKLE
  // ====================================================================
  group('Tackle action', () {
    test('successful tackle steals ball from opponent', () {
      final gm       = freshGM();
      final tackler  = addPlayer(gm, teamHome, const GridPos(5, 5));
      final opponent = addPlayer(gm, teamAway, const GridPos(6, 5), hasBall: true);
      final result   = successAS(gm).execute(
        MoveData(action: ActionType.tackle, player: tackler, target: opponent), 2);
      expect(result.success, isTrue);
      expect(gm.ballCarrier, tackler);
      expect(opponent.hasBall, isFalse);
    });

    test('failed tackle does not steal ball', () {
      final gm       = freshGM();
      final tackler  = addPlayer(gm, teamHome, const GridPos(5, 5));
      final opponent = addPlayer(gm, teamAway, const GridPos(6, 5), hasBall: true);
      final result   = failAS(gm).execute(
        MoveData(action: ActionType.tackle, player: tackler, target: opponent), 2);
      expect(result.success, isTrue); // action consumed
      expect(gm.ballCarrier, opponent); // ball unchanged
    });

    test('tackle fails when target is on same team', () {
      final gm       = freshGM();
      final tackler  = addPlayer(gm, teamHome, const GridPos(5, 5));
      final teammate = addPlayer(gm, teamHome, const GridPos(6, 5));
      final result   = successAS(gm).execute(
        MoveData(action: ActionType.tackle, player: tackler, target: teammate), 2);
      expect(result.success, isFalse);
    });

    test('tackle fails when opponent is 2+ tiles away', () {
      final gm       = freshGM();
      final tackler  = addPlayer(gm, teamHome, const GridPos(5, 5));
      final opponent = addPlayer(gm, teamAway, const GridPos(7, 5)); // 2 tiles
      final result   = successAS(gm).execute(
        MoveData(action: ActionType.tackle, player: tackler, target: opponent), 2);
      expect(result.success, isFalse);
    });

    test('tackle_bonus increases success probability in repeated attempts', () {
      // Statistical test: bonus should give high success rate when bonus=0.5
      final gm       = freshGM();
      final tackler  = addPlayer(gm, teamHome, const GridPos(5, 5),
          defending: 5)..bonuses['tackle_bonus'] = 0.4;
      final opponent = addPlayer(gm, teamAway, const GridPos(6, 5),
          dribbling: 5, hasBall: true);

      int successes = 0;
      const trials  = 200;
      for (int i = 0; i < trials; i++) {
        // Reset positions and ball each trial
        tackler.gridPos  = const GridPos(5, 5);
        opponent.gridPos = const GridPos(6, 5);
        opponent.hasBall = true;
        gm.ballCarrier   = opponent;

        final result = ActionSystem(gm).execute(
          MoveData(action: ActionType.tackle, player: tackler, target: opponent), 2);
        if (result.success && gm.ballCarrier == tackler) successes++;
      }
      // base 0.5 + bonus 0.4 = 0.90 → expect ~85%+ successes
      expect(successes, greaterThan(trials * 0.75));
    });
  });
}
