import '../models/game_config.dart';
import '../models/grid_pos.dart';
import '../models/move_data.dart';
import '../models/player_model.dart';
import 'game_manager.dart';

/// Stateless move generator.  All methods are static.
class MoveGenerator {
  const MoveGenerator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  static List<MoveData> generateAll(GameManager gm, int teamId, int diceResult) {
    final moves = <MoveData>[];
    for (final p in gm.getTeamPlayers(teamId)) {
      moves.addAll(generateForPlayer(gm, p, diceResult));
    }
    return moves;
  }

  static List<MoveData> generateForPlayer(
      GameManager gm, PlayerModel player, int diceResult) {
    final moves = <MoveData>[];
    moves.addAll(_generateMoves(gm, player, diceResult));
    if (player.hasBall) {
      moves.addAll(_generatePasses(gm, player, diceResult));
      moves.addAll(_generateDribbles(gm, player, diceResult));
      moves.addAll(_generateShots(gm, player));
    } else {
      moves.addAll(_generateTackles(gm, player));
    }
    return moves;
  }

  /// Cells reachable by a Move action.
  static List<GridPos> getMoveCells(GameManager gm, PlayerModel p, int diceResult) {
    return _floodCells(gm, p.gridPos, p.getMoveRange(diceResult));
  }

  /// Cells reachable by a Pass action (all pass types).
  static List<GridPos> getPassCells(GameManager gm, PlayerModel p, int diceResult) {
    final cells = <GridPos>{};
    for (final type in ['short', 'medium', 'long']) {
      final range = p.getPassRange(type, diceResult);
      if (range > 0) cells.addAll(_lineCells(gm, p.gridPos, range));
    }
    return cells.toList();
  }

  /// Goal cells the player can shoot at.
  static List<GridPos> getShootCells(GameManager gm, PlayerModel p) {
    final targetCol = p.teamId == teamHome ? gm.awayGoalCol : gm.homeGoalCol;
    final targetRows = p.teamId == teamHome ? gm.awayGoalRows : gm.homeGoalRows;
    return [
      for (final row in targetRows)
        if (p.gridPos.manhattanTo(GridPos(targetCol, row)) <= 6)
          GridPos(targetCol, row)
    ];
  }

  /// Adjacent opponents that can be tackled.
  static List<PlayerModel> getTackleTargets(GameManager gm, PlayerModel p) {
    final oppTeam = gm.opponentTeam(p.teamId);
    return [
      for (final opp in gm.getTeamPlayers(oppTeam))
        if (p.gridPos.manhattanTo(opp.gridPos) == 1) opp
    ];
  }

  // ---------------------------------------------------------------------------
  // Private generators
  // ---------------------------------------------------------------------------

  static List<MoveData> _generateMoves(
      GameManager gm, PlayerModel p, int diceResult) {
    return [
      for (final cell in getMoveCells(gm, p, diceResult))
        if (gm.playerAt(cell) == null)
          MoveData(action: ActionType.move, player: p, target: cell),
    ];
  }

  static List<MoveData> _generatePasses(
      GameManager gm, PlayerModel p, int diceResult) {
    final moves = <MoveData>[];
    for (final type in ['short', 'medium', 'long']) {
      final range = p.getPassRange(type, diceResult);
      if (range == 0) continue;
      for (final cell in _lineCells(gm, p.gridPos, range)) {
        final occ = gm.playerAt(cell);
        if (occ != null && occ.teamId == p.teamId) {
          if (!_passIntercepted(gm, p.gridPos, cell, p.teamId)) {
            moves.add(MoveData(
              action: ActionType.pass,
              player: p,
              target: occ,
              metadata: {'pass_type': type},
            ));
          }
        }
      }
    }
    return moves;
  }

  static List<MoveData> _generateDribbles(
      GameManager gm, PlayerModel p, int diceResult) {
    final moves = <MoveData>[];
    for (final cell in getMoveCells(gm, p, diceResult)) {
      final occ = gm.playerAt(cell);
      if (occ == null) {
        moves.add(MoveData(action: ActionType.dribble, player: p, target: cell));
      } else if (occ.teamId != p.teamId) {
        moves.add(MoveData(
          action: ActionType.dribble,
          player: p,
          target: cell,
          metadata: {'contested': true, 'defender': occ},
        ));
      }
    }
    return moves;
  }

  static List<MoveData> _generateShots(GameManager gm, PlayerModel p) {
    return [
      for (final cell in getShootCells(gm, p))
        MoveData(
          action: ActionType.shoot,
          player: p,
          target: cell,
          metadata: {'distance': p.gridPos.manhattanTo(cell)},
        ),
    ];
  }

  static List<MoveData> _generateTackles(GameManager gm, PlayerModel p) {
    return [
      for (final opp in getTackleTargets(gm, p))
        MoveData(action: ActionType.tackle, player: p, target: opp),
    ];
  }

  // ---------------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------------

  /// BFS flood-fill: all reachable cells within [maxRange] steps.
  static List<GridPos> _floodCells(GameManager gm, GridPos origin, int maxRange) {
    final visited = <GridPos>{origin};
    final queue   = <({GridPos pos, int steps})>[
      (pos: origin, steps: 0)
    ];
    final result  = <GridPos>[];

    while (queue.isNotEmpty) {
      final item = queue.removeAt(0);
      if (item.steps > 0) result.add(item.pos);
      if (item.steps >= maxRange) continue;

      for (final neighbor in item.pos.cardinalNeighbors) {
        if (gm.isValidCell(neighbor) && !visited.contains(neighbor)) {
          visited.add(neighbor);
          queue.add((pos: neighbor, steps: item.steps + 1));
        }
      }
    }
    return result;
  }

  /// Straight-line cells (8 directions) up to [maxDist] – stops at first blocker.
  static List<GridPos> _lineCells(GameManager gm, GridPos origin, int maxDist) {
    const dirs = [
      (1, 0), (-1, 0), (0, 1), (0, -1),
      (1, 1), (1, -1), (-1, 1), (-1, -1),
    ];
    final result = <GridPos>[];
    for (final (dx, dy) in dirs) {
      for (int step = 1; step <= maxDist; step++) {
        final cell = GridPos(origin.x + dx * step, origin.y + dy * step);
        if (!gm.isValidCell(cell)) break;
        result.add(cell);
        if (gm.playerAt(cell) != null) break;
      }
    }
    return result;
  }

  /// Returns true if an opponent stands on the direct line between [from] and [to].
  static bool _passIntercepted(
      GameManager gm, GridPos from, GridPos to, int passerTeam) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final steps = [dx.abs(), dy.abs()].reduce((a, b) => a > b ? a : b);
    if (steps == 0) return false;
    final sx = dx == 0 ? 0 : dx ~/ dx.abs();
    final sy = dy == 0 ? 0 : dy ~/ dy.abs();

    for (int i = 1; i < steps; i++) {
      final cell = GridPos(from.x + sx * i, from.y + sy * i);
      final occ = gm.playerAt(cell);
      if (occ != null && occ.teamId != passerTeam) return true;
    }
    return false;
  }
}
