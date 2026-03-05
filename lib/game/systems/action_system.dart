import 'dart:math';
import '../models/game_config.dart';
import '../models/grid_pos.dart';
import '../models/move_data.dart';
import '../models/player_model.dart';
import 'game_manager.dart';

/// Result of executing an action.
class ActionResult {
  final bool success;
  final String message;
  final bool ballTaken;     // opponent intercepted/tackled
  final bool goalScored;
  final int? scoringTeam;

  const ActionResult({
    required this.success,
    this.message = '',
    this.ballTaken = false,
    this.goalScored = false,
    this.scoringTeam,
  });
}

/// Validates and executes all game actions, mutating GameManager state.
class ActionSystem {
  final GameManager gm;
  final Random _rng;

  ActionSystem(this.gm, {Random? rng}) : _rng = rng ?? Random();

  ActionResult execute(MoveData move, int diceResult) {
    switch (move.action) {
      case ActionType.move:    return _doMove(move.player, move.target as GridPos, diceResult);
      case ActionType.pass:    return _doPass(move.player, move.target, diceResult);
      case ActionType.dribble: return _doDribble(move.player, move.target as GridPos, diceResult);
      case ActionType.shoot:   return _doShoot(move.player, move.target as GridPos);
      case ActionType.tackle:  return _doTackle(move.player, move.target as PlayerModel);
    }
  }

  // ---------------------------------------------------------------------------
  // Move
  // ---------------------------------------------------------------------------
  ActionResult _doMove(PlayerModel player, GridPos target, int diceResult) {
    if (!gm.isValidCell(target)) return _fail('Invalid cell');
    if (gm.playerAt(target) != null) return _fail('Cell occupied');
    if (player.gridPos.manhattanTo(target) > player.getMoveRange(diceResult)) {
      return _fail('Out of range');
    }
    player.gridPos = target;
    gm.syncBallWithCarrier();
    return const ActionResult(success: true, message: 'Moved');
  }

  // ---------------------------------------------------------------------------
  // Pass
  // ---------------------------------------------------------------------------
  ActionResult _doPass(PlayerModel player, Object target, int diceResult) {
    if (!player.hasBall) return _fail('Player has no ball');

    final PlayerModel? targetPlayer;
    if (target is PlayerModel) {
      targetPlayer = target;
    } else if (target is GridPos) {
      targetPlayer = gm.playerAt(target);
    } else {
      return _fail('Invalid target');
    }
    if (targetPlayer == null || targetPlayer.teamId != player.teamId) {
      return _fail('Invalid pass target');
    }

    final dist     = player.gridPos.manhattanTo(targetPlayer.gridPos);
    final passType = _classifyPass(dist);
    final maxDist  = player.getPassRange(passType, diceResult);
    if (dist > maxDist) return _fail('Pass out of range');

    // Interception
    final noIntercept = player.bonuses['no_intercept'] == true;
    if (!noIntercept) {
      final interceptor = _findInterceptor(player.gridPos, targetPlayer.gridPos, player.teamId);
      if (interceptor != null) {
        gm.setBallCarrier(interceptor);
        return ActionResult(
          success: true,
          message: 'Pass intercepted by #${interceptor.shirtNumber}!',
          ballTaken: true,
        );
      }
    }

    gm.setBallCarrier(targetPlayer);
    return const ActionResult(success: true, message: 'Pass successful');
  }

  String _classifyPass(int dist) {
    if (dist <= 2) return 'short';
    if (dist <= 4) return 'medium';
    return 'long';
  }

  PlayerModel? _findInterceptor(GridPos from, GridPos to, int passerTeam) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final steps = [dx.abs(), dy.abs()].reduce((a, b) => a > b ? a : b);
    if (steps == 0) return null;
    final sx = dx == 0 ? 0 : dx ~/ dx.abs();
    final sy = dy == 0 ? 0 : dy ~/ dy.abs();

    final oppTeam = gm.opponentTeam(passerTeam);
    for (int i = 1; i < steps; i++) {
      final cell = GridPos(from.x + sx * i, from.y + sy * i);
      final occ  = gm.playerAt(cell);
      if (occ != null && occ.teamId == oppTeam) {
        final prob = (0.3 + (occ.defending - 5) * 0.04).clamp(0.1, 0.7);
        if (_rng.nextDouble() < prob) return occ;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Dribble
  // ---------------------------------------------------------------------------
  ActionResult _doDribble(PlayerModel player, GridPos target, int diceResult) {
    if (!player.hasBall) return _fail('Player has no ball');
    if (!gm.isValidCell(target)) return _fail('Invalid cell');
    if (player.gridPos.manhattanTo(target) > player.getMoveRange(diceResult)) {
      return _fail('Out of range');
    }

    final occupant = gm.playerAt(target);
    if (occupant != null && occupant.teamId == player.teamId) return _fail('Cell blocked');

    if (occupant != null) {
      // Contested dribble
      final prob = player.getDribbleSuccessProb(diceResult);
      if (_rng.nextDouble() < prob) {
        player.gridPos = target;
        gm.syncBallWithCarrier();
        return const ActionResult(success: true, message: 'Dribble past defender!');
      } else {
        gm.setBallCarrier(occupant);
        return const ActionResult(success: true, message: 'Dribble failed – ball lost!', ballTaken: true);
      }
    }

    player.gridPos = target;
    gm.syncBallWithCarrier();
    return const ActionResult(success: true, message: 'Dribbled');
  }

  // ---------------------------------------------------------------------------
  // Shoot
  // ---------------------------------------------------------------------------
  ActionResult _doShoot(PlayerModel player, GridPos target) {
    if (!player.hasBall) return _fail('Player has no ball');

    final scoringTeam = gm.checkGoal(target);
    if (scoringTeam != player.teamId) return _fail('Not aimed at goal');

    final dist = player.gridPos.manhattanTo(target);
    double prob = player.getShootProbability(dist);

    // GK sweeper keeper check
    final opp = gm.opponentTeam(player.teamId);
    for (final gkCandidate in gm.getTeamPlayers(opp)) {
      if (gkCandidate.role == PositionRole.gk &&
          gkCandidate.bonuses['block_long_shots'] == true &&
          dist >= 3) {
        prob = 0.0; // blocked
      }
    }

    if (_rng.nextDouble() < prob) {
      gm.recordGoal(player.teamId);
      return ActionResult(
        success: true,
        message: 'GOAL!',
        goalScored: true,
        scoringTeam: player.teamId,
      );
    } else {
      gm.dropBallAt(target);
      return const ActionResult(success: true, message: 'Saved / off target');
    }
  }

  // ---------------------------------------------------------------------------
  // Tackle
  // ---------------------------------------------------------------------------
  ActionResult _doTackle(PlayerModel player, PlayerModel target) {
    if (target.teamId == player.teamId) return _fail('Cannot tackle own player');
    if (player.gridPos.manhattanTo(target.gridPos) > 1) return _fail('Too far to tackle');

    double prob = player.getTackleProbAgainst(target);
    prob += player.bonuses['tackle_bonus'] as double? ?? 0.0;
    prob = prob.clamp(0.15, 0.90);

    if (_rng.nextDouble() < prob) {
      if (target.hasBall) gm.setBallCarrier(player);
      return const ActionResult(success: true, message: 'Tackle SUCCESS!');
    } else {
      return const ActionResult(success: true, message: 'Tackle missed');
    }
  }

  ActionResult _fail(String msg) => ActionResult(success: false, message: msg);
}
