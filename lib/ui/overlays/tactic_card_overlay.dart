import 'package:flutter/material.dart';
import '../../game/models/tactic_card.dart';
import '../../game/tactical_football_game.dart';

class TacticCardOverlay extends StatelessWidget {
  final TacticalFootballGame game;
  const TacticCardOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => game.overlays.remove(TacticalFootballGame.overlayCardPanel),
      child: Container(
        color: const Color(0xCC000000),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('TACTIC CARDS',
                    style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 16,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: game.cardHand
                    .map((card) => _CardWidget(card: card, game: game))
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    game.overlays.remove(TacticalFootballGame.overlayCardPanel),
                child: const Text('CLOSE',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final TacticCard card;
  final TacticalFootballGame game;
  const _CardWidget({required this.card, required this.game});

  @override
  Widget build(BuildContext context) {
    final used = game.turnManager.tacticCardUsed;
    return GestureDetector(
      onTap: used ? null : () => game.onTacticCard(card),
      child: Opacity(
        opacity: used ? 0.4 : 1.0,
        child: Container(
          width: 120,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF3A6A9F), width: 1.5),
          ),
          child: Column(
            children: [
              const Icon(Icons.sports_soccer, color: Color(0xFFFFD700), size: 36),
              const SizedBox(height: 8),
              Text(card.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const SizedBox(height: 6),
              Text(card.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 9),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              if (!used)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('USE',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
