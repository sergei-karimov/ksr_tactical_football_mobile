import 'dart:ui';
import 'package:flame/components.dart';
import '../models/game_config.dart';
import '../models/grid_pos.dart';
import '../systems/move_generator.dart';
import '../tactical_football_game.dart';

/// Draws the pitch grid.  Also owns the highlighted-cell overlay.
class BoardComponent extends Component {
  final TacticalFootballGame game;

  List<GridPos> highlightedCells = [];

  static const _lineColor    = Color(0x44FFFFFF);
  static const _centreColor  = Color(0x33FFFFFF);
  static const _highlightCol = Color(0xAAFFFF33);

  BoardComponent({required this.game});

  @override
  void render(Canvas canvas) {
    final gm = game.gameManager;
    final ts  = game.tileSize;
    final ox  = game.boardOffsetX;
    final oy  = game.boardOffsetY;

    for (int x = 0; x < gm.gridWidth; x++) {
      for (int y = 0; y < gm.gridHeight; y++) {
        final rect = Rect.fromLTWH(ox + x * ts, oy + y * ts, ts, ts);

        // Base grass colour
        Color fill;
        if (gm.homeGoalRows.contains(y) && x == gm.homeGoalCol) {
          fill = goalHomeColor;
        } else if (gm.awayGoalRows.contains(y) && x == gm.awayGoalCol) {
          fill = goalAwayColor;
        } else {
          fill = (x + y).isEven ? grassColor : grassDarkColor;
        }

        // Highlight override
        if (highlightedCells.contains(GridPos(x, y))) fill = _highlightCol;

        canvas.drawRect(rect, Paint()..color = fill);
        canvas.drawRect(rect, Paint()
          ..color       = _lineColor
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.5);
      }
    }

    // Centre circle & halfway line
    _drawMarkings(canvas, ox, oy, gm.gridWidth, gm.gridHeight, ts);
  }

  void _drawMarkings(Canvas canvas, double ox, double oy,
      int w, int h, double ts) {
    final midX = ox + w / 2 * ts;
    final midY = oy + h / 2 * ts;
    final mark = Paint()
      ..color       = _centreColor
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Halfway line
    canvas.drawLine(Offset(midX, oy), Offset(midX, oy + h * ts), mark);
    // Centre circle
    canvas.drawCircle(Offset(midX, midY), ts * 1.5, mark);
  }

  // ---------------------------------------------------------------------------
  // Highlight helpers (called by the game on action selection)
  // ---------------------------------------------------------------------------

  void clearHighlights() {
    highlightedCells.clear();
  }

  void showHighlightsForAction(ActionType action) {
    clearHighlights();
    final sp   = game.turnManager.selectedPlayer;
    final dice = game.diceSystem.lastResult;
    if (sp == null) return;

    switch (action) {
      case ActionType.move:
      case ActionType.dribble:
        highlightedCells = MoveGenerator.getMoveCells(game.gameManager, sp, dice);
      case ActionType.pass:
        highlightedCells = MoveGenerator.getPassCells(game.gameManager, sp, dice);
      case ActionType.shoot:
        highlightedCells = MoveGenerator.getShootCells(game.gameManager, sp);
      case ActionType.tackle:
        highlightedCells = [
          for (final t in MoveGenerator.getTackleTargets(game.gameManager, sp)) t.gridPos
        ];
    }
  }

  void refreshLayout() {
    // No children to reposition; render() reads game.tileSize directly.
  }
}
