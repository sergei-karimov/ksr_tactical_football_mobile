import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import '../models/game_config.dart';
import '../models/player_model.dart';
import '../tactical_football_game.dart';

/// Renders a footballer as a coloured circle with shirt number.
class PlayerComponent extends Component {
  final PlayerModel          model;
  final TacticalFootballGame game;

  PlayerComponent({required this.model, required this.game});

  @override
  void render(Canvas canvas) {
    final pos    = game.gridToWorld(model.gridPos);
    final ts     = game.tileSize;
    final radius = ts * 0.38;

    // Body
    final bodyColor = model.teamId == teamHome ? homeColor : awayColor;
    canvas.drawCircle(
      ui.Offset(pos.x, pos.y),
      radius,
      ui.Paint()..color = bodyColor,
    );

    // Selection ring
    if (game.turnManager.selectedPlayer == model) {
      canvas.drawCircle(
        ui.Offset(pos.x, pos.y),
        radius + 3,
        ui.Paint()
          ..color       = const Color(0xFFFFFF00)
          ..style       = ui.PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Ball dot (small white circle offset)
    if (model.hasBall) {
      canvas.drawCircle(
        ui.Offset(pos.x + radius * 0.6, pos.y - radius * 0.6),
        radius * 0.3,
        ui.Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    // Shirt number
    final tp = TextPainter(
      text: TextSpan(
        text: model.shirtNumber.toString(),
        style: TextStyle(
          color:      const Color(0xFFFFFFFF),
          fontSize:   ts * 0.32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      ui.Offset(pos.x - tp.width / 2, pos.y - tp.height / 2),
    );
  }

  void syncPosition() {
    // Nothing to sync — render() reads model.gridPos dynamically.
  }
}
