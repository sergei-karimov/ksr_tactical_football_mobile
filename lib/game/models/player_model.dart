import 'game_config.dart';
import 'grid_pos.dart';

class PlayerModel {
  final int teamId;
  final int shirtNumber;
  final PositionRole role;
  final String name;

  // Stats 1–10
  final int speed;
  final int passing;
  final int shooting;
  final int dribbling;
  final int defending;

  // Runtime state (mutable)
  GridPos gridPos;
  bool hasBall;
  Map<String, Object> bonuses;

  PlayerModel({
    required this.teamId,
    required this.shirtNumber,
    required this.role,
    this.name = '',
    this.speed = 7,
    this.passing = 7,
    this.shooting = 7,
    this.dribbling = 7,
    this.defending = 7,
    required this.gridPos,
    this.hasBall = false,
    Map<String, Object>? bonuses,
  }) : bonuses = bonuses ?? {};

  // ---------------------------------------------------------------------------
  // Action probability helpers
  // ---------------------------------------------------------------------------

  int getMoveRange(int diceResult) {
    int base = diceResult >= 3 ? 2 : 1;
    base += (bonuses['extra_movement'] as int? ?? 0);
    return base;
  }

  int getPassRange(String passType, int diceResult) {
    const baseRanges = {'short': 2, 'medium': 4, 'long': 6};
    int range = baseRanges[passType] ?? 0;
    if (passType == 'long' && passing < 7) return 0;
    if (range == 0) return 0;
    // Dice 4 bonus
    if (diceResult == 4) range += 2;
    range += (bonuses['pass_bonus'] as int? ?? 0);
    return range;
  }

  double getShootProbability(int distance) {
    final base = _baseShootProb(distance);
    final statMod = (shooting - 5) * 0.02;
    final bonus = bonuses['shoot_bonus'] as double? ?? 0.0;
    return (base + statMod + bonus).clamp(0.05, 0.99);
  }

  double _baseShootProb(int distance) {
    switch (distance) {
      case 1:  return 0.80;
      case 2:  return 0.60;
      case 3:  return 0.40;
      default: return 0.20;
    }
  }

  double getDribbleSuccessProb(int diceResult) {
    double base = 0.5 + (dribbling - 5) * 0.04;
    if (diceResult == 5) base += 0.25; // dice dribble bonus
    base += bonuses['dribble_bonus'] as double? ?? 0.0;
    return base.clamp(0.10, 0.95);
  }

  double getTackleProbAgainst(PlayerModel opponent) {
    final diff = defending - opponent.dribbling;
    return (0.5 + diff * 0.05).clamp(0.15, 0.90);
  }

  // ---------------------------------------------------------------------------
  // Snapshot for AI rollback
  // ---------------------------------------------------------------------------

  PlayerSnapshot snapshot() => PlayerSnapshot(
        gridPos: gridPos,
        hasBall: hasBall,
        bonuses: Map.from(bonuses),
      );

  void restoreSnapshot(PlayerSnapshot snap) {
    gridPos = snap.gridPos;
    hasBall = snap.hasBall;
    bonuses = Map.from(snap.bonuses);
  }
}

class PlayerSnapshot {
  final GridPos gridPos;
  final bool hasBall;
  final Map<String, Object> bonuses;

  const PlayerSnapshot({
    required this.gridPos,
    required this.hasBall,
    required this.bonuses,
  });
}
