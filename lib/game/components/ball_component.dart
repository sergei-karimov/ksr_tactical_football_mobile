import 'dart:ui';
import 'package:flame/components.dart';
import '../tactical_football_game.dart';

/// Renders the football as a white circle with a shadow.
class BallComponent extends Component {
  final TacticalFootballGame game;

  BallComponent({required this.game});

  @override
  void render(Canvas canvas) {
    final gm  = game.gameManager;
    final pos = game.gridToWorld(gm.ballPos);
    final ts  = game.tileSize;
    final r   = ts * 0.22;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.x + r * 0.4, pos.y + r * 0.5),
          width: r * 1.4, height: r * 0.7),
      Paint()..color = const Color(0x55000000),
    );

    // Ball (white with a slight gradient feel via two circles)
    canvas.drawCircle(Offset(pos.x, pos.y), r,
        Paint()..color = const Color(0xFFEEEEEE));
    canvas.drawCircle(Offset(pos.x - r * 0.25, pos.y - r * 0.25), r * 0.4,
        Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(Offset(pos.x, pos.y), r,
        Paint()
          ..color       = const Color(0xFF333333)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.8);
  }

  void syncPosition() {
    // Reads gm.ballPos dynamically – nothing to sync.
  }
}
