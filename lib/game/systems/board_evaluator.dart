import '../models/game_config.dart';
import 'game_manager.dart';
import 'move_generator.dart';

/// Stateless heuristic board evaluator for minimax.
/// Returns score relative to [aiTeam]: positive = good for AI.
class BoardEvaluator {
  const BoardEvaluator._();

  static const _wBallProgress   = 3.0;
  static const _wShotProb       = 10.0;
  static const _wPassOptions    = 0.5;
  static const _wDefPressure    = 2.0;
  static const _wSpread         = 0.3;

  static double evaluate(GameManager gm, int aiTeam, int diceHint) {
    if (gm.state == GameState.gameOver) {
      return _terminalScore(gm, aiTeam);
    }
    return _ballProgress(gm, aiTeam)
         + _shotOpportunity(gm, aiTeam, diceHint)
         + _passingOptions(gm, aiTeam, diceHint)
         - _defensivePressure(gm, aiTeam)
         + _spreadBonus(gm, aiTeam);
  }

  static double _terminalScore(GameManager gm, int aiTeam) {
    final mine   = aiTeam == teamHome ? gm.homeScore : gm.awayScore;
    final theirs = aiTeam == teamHome ? gm.awayScore : gm.homeScore;
    if (mine > theirs) return 1000.0;
    if (mine < theirs) return -1000.0;
    return 0.0;
  }

  static double _ballProgress(GameManager gm, int aiTeam) {
    final bx = gm.ballPos.x.toDouble();
    final w  = gm.gridWidth.toDouble();
    double progress = aiTeam == teamHome ? bx / w : (w - bx) / w;
    if (gm.ballCarrier?.teamId == aiTeam) progress *= 1.5;
    return progress * _wBallProgress;
  }

  static double _shotOpportunity(GameManager gm, int aiTeam, int dice) {
    double reward = 0.0;
    for (final p in gm.getTeamPlayers(aiTeam)) {
      if (!p.hasBall) continue;
      for (final cell in MoveGenerator.getShootCells(gm, p)) {
        final dist = p.gridPos.manhattanTo(cell);
        reward += p.getShootProbability(dist);
      }
    }
    return reward * _wShotProb;
  }

  static double _passingOptions(GameManager gm, int aiTeam, int dice) {
    int count = 0;
    for (final p in gm.getTeamPlayers(aiTeam)) {
      if (!p.hasBall) continue;
      for (final cell in MoveGenerator.getPassCells(gm, p, dice)) {
        final occ = gm.playerAt(cell);
        if (occ != null && occ.teamId == aiTeam) count++;
      }
    }
    return count * _wPassOptions;
  }

  static double _defensivePressure(GameManager gm, int aiTeam) {
    final oppTeam = gm.opponentTeam(aiTeam);
    final goalCol = aiTeam == teamHome ? gm.homeGoalCol : gm.awayGoalCol;
    double pressure = 0.0;
    for (final opp in gm.getTeamPlayers(oppTeam)) {
      final dist = (opp.gridPos.x - goalCol).abs().toDouble();
      if (dist < 4) pressure += (4 - dist) / 4;
    }
    return pressure * _wDefPressure;
  }

  static double _spreadBonus(GameManager gm, int aiTeam) {
    final cols = <int>{};
    for (final p in gm.getTeamPlayers(aiTeam)) {
      cols.add(p.gridPos.x);
    }
    return cols.length * _wSpread;
  }
}
