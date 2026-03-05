import '../models/game_config.dart';
import '../models/move_data.dart';
import '../models/player_model.dart';
import '../models/grid_pos.dart';
import 'action_system.dart';
import 'board_evaluator.dart';
import 'dice_system.dart';
import 'game_manager.dart';
import 'move_generator.dart';

const _depthMap = {1: 1, 2: 2, 3: 3};

/// Minimax AI controller with alpha-beta pruning.
class AIController {
  final GameManager gm;
  final DiceSystem  dice;

  AIController(this.gm, this.dice);

  // ---------------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------------

  /// Executes the full AI turn for [teamId].  Mutates [gm] in place.
  /// Returns true if a goal was scored during this turn.
  bool executeAITurn(int teamId, int difficulty) {
    final diceResult  = dice.roll();
    final actionsLeft = dice.totalActions(diceResult);
    final depth       = _depthMap[difficulty] ?? 2;
    final action      = ActionSystem(gm);

    for (int i = 0; i < actionsLeft; i++) {
      final best = _findBest(teamId, depth, diceResult);
      if (best == null) break;
      final result = action.execute(best, diceResult);
      if (result.goalScored) return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  MoveData? _findBest(int teamId, int depth, int diceResult) {
    final moves = MoveGenerator.generateAll(gm, teamId, diceResult);
    if (moves.isEmpty) return null;

    double bestScore = double.negativeInfinity;
    MoveData? bestMove;

    for (final move in moves) {
      final snap = gm.takeSnapshot();
      _applySimulated(move, diceResult);
      final score = _minimax(
        depth - 1,
        gm.opponentTeam(teamId),
        diceResult,
        double.negativeInfinity,
        double.infinity,
        false,
        teamId,
      );
      gm.restoreSnapshot(snap);

      if (score > bestScore) {
        bestScore = score;
        bestMove  = move;
      }
    }
    return bestMove;
  }

  double _minimax(
    int depth,
    int currentTeam,
    int diceResult,
    double alpha,
    double beta,
    bool maximising,
    int aiTeam,
  ) {
    if (depth == 0 || gm.state == GameState.gameOver) {
      return BoardEvaluator.evaluate(gm, aiTeam, diceResult);
    }

    final moves    = MoveGenerator.generateAll(gm, currentTeam, diceResult);
    if (moves.isEmpty) return BoardEvaluator.evaluate(gm, aiTeam, diceResult);

    final nextTeam = gm.opponentTeam(currentTeam);

    if (maximising) {
      double maxEval = double.negativeInfinity;
      for (final move in moves) {
        final snap = gm.takeSnapshot();
        _applySimulated(move, diceResult);
        final eval = _minimax(depth - 1, nextTeam, diceResult, alpha, beta, false, aiTeam);
        gm.restoreSnapshot(snap);
        maxEval = eval > maxEval ? eval : maxEval;
        alpha   = alpha > eval  ? alpha : eval;
        if (beta <= alpha) break;
      }
      return maxEval;
    } else {
      double minEval = double.infinity;
      for (final move in moves) {
        final snap = gm.takeSnapshot();
        _applySimulated(move, diceResult);
        final eval = _minimax(depth - 1, nextTeam, diceResult, alpha, beta, true, aiTeam);
        gm.restoreSnapshot(snap);
        minEval = eval < minEval ? eval : minEval;
        beta    = beta  < eval  ? beta  : eval;
        if (beta <= alpha) break;
      }
      return minEval;
    }
  }

  // ---------------------------------------------------------------------------
  // Deterministic simulation (no RNG, no notifications)
  // ---------------------------------------------------------------------------

  void _applySimulated(MoveData move, int diceResult) {
    final player = move.player;

    switch (move.action) {
      case ActionType.move:
        player.gridPos = move.target as GridPos;
        if (player.hasBall) gm.ballPos = player.gridPos;

      case ActionType.pass:
        final target = move.target;
        final recipient = target is PlayerModel
            ? target
            : gm.playerAt(target as GridPos);
        if (recipient != null) {
          player.hasBall    = false;
          recipient.hasBall = true;
          gm.ballPos        = recipient.gridPos;
          gm.ballCarrier    = recipient;
        }

      case ActionType.dribble:
        // Optimistic: assume success for AI evaluation
        player.gridPos = move.target as GridPos;
        if (player.hasBall) gm.ballPos = player.gridPos;

      case ActionType.shoot:
        final dist = player.gridPos.manhattanTo(move.target as GridPos);
        if (player.getShootProbability(dist) > 0.5) {
          if (player.teamId == teamHome) {
            gm.homeScore++;
          } else {
            gm.awayScore++;
          }
        }

      case ActionType.tackle:
        final opp = move.target as PlayerModel;
        if (opp.hasBall) {
          opp.hasBall    = false;
          player.hasBall = true;
          gm.ballPos     = player.gridPos;
          gm.ballCarrier = player;
        }
    }
  }
}
