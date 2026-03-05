import '../systems/game_manager.dart';
import 'game_config.dart';

// ---------------------------------------------------------------------------
// Abstract base
// ---------------------------------------------------------------------------
abstract class TacticCard {
  final String name;
  final String description;
  final String iconAsset;

  const TacticCard({
    required this.name,
    required this.description,
    this.iconAsset = '',
  });

  /// Returns true if successfully applied.
  bool applyEffect(GameManager gm, int teamId, {Object? target});
}

// ---------------------------------------------------------------------------
// Concrete cards
// ---------------------------------------------------------------------------

class OverlapCard extends TacticCard {
  const OverlapCard()
      : super(
          name: 'Overlap',
          description: 'Wing/full-back players get +1 movement this turn.',
          iconAsset: 'assets/images/card_overlap.png',
        );

  @override
  bool applyEffect(GameManager gm, int teamId, {Object? target}) {
    const wingRoles = {
      PositionRole.lw, PositionRole.rw, PositionRole.lb, PositionRole.rb
    };
    for (final p in gm.getTeamPlayers(teamId)) {
      if (wingRoles.contains(p.role)) {
        p.bonuses['extra_movement'] = (p.bonuses['extra_movement'] as int? ?? 0) + 1;
      }
    }
    return true;
  }
}

class HighPressCard extends TacticCard {
  const HighPressCard()
      : super(
          name: 'High Press',
          description: 'All players gain +15% tackle success this turn.',
          iconAsset: 'assets/images/card_high_press.png',
        );

  @override
  bool applyEffect(GameManager gm, int teamId, {Object? target}) {
    for (final p in gm.getTeamPlayers(teamId)) {
      p.bonuses['tackle_bonus'] = (p.bonuses['tackle_bonus'] as double? ?? 0.0) + 0.15;
    }
    return true;
  }
}

class CounterAttackCard extends TacticCard {
  const CounterAttackCard()
      : super(
          name: 'Counter Attack',
          description: 'Forwards move +1 extra tile this turn.',
          iconAsset: 'assets/images/card_counter_attack.png',
        );

  @override
  bool applyEffect(GameManager gm, int teamId, {Object? target}) {
    const forwardRoles = {
      PositionRole.st, PositionRole.cam, PositionRole.lw, PositionRole.rw
    };
    for (final p in gm.getTeamPlayers(teamId)) {
      if (forwardRoles.contains(p.role)) {
        p.bonuses['extra_movement'] = (p.bonuses['extra_movement'] as int? ?? 0) + 1;
      }
    }
    return true;
  }
}

class ThroughPassCard extends TacticCard {
  const ThroughPassCard()
      : super(
          name: 'Through Pass',
          description: 'Ball carrier gets +2 pass range this turn.',
          iconAsset: 'assets/images/card_through_pass.png',
        );

  @override
  bool applyEffect(GameManager gm, int teamId, {Object? target}) {
    final carrier = gm.ballCarrier;
    if (carrier == null || carrier.teamId != teamId) return false;
    carrier.bonuses['pass_bonus'] = (carrier.bonuses['pass_bonus'] as int? ?? 0) + 2;
    return true;
  }
}

class TikiTakaCard extends TacticCard {
  const TikiTakaCard()
      : super(
          name: 'Tiki-Taka',
          description: 'Short & medium passes bypass interception this turn.',
          iconAsset: 'assets/images/card_tiki_taka.png',
        );

  @override
  bool applyEffect(GameManager gm, int teamId, {Object? target}) {
    for (final p in gm.getTeamPlayers(teamId)) {
      p.bonuses['no_intercept'] = true;
    }
    return true;
  }
}

class SweeperKeeperCard extends TacticCard {
  const SweeperKeeperCard()
      : super(
          name: 'Sweeper Keeper',
          description: 'GK blocks all shots from distance 3+ this turn.',
          iconAsset: 'assets/images/card_sweeper_keeper.png',
        );

  @override
  bool applyEffect(GameManager gm, int teamId, {Object? target}) {
    for (final p in gm.getTeamPlayers(teamId)) {
      if (p.role == PositionRole.gk) {
        p.bonuses['block_long_shots'] = true;
      }
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Factory
// ---------------------------------------------------------------------------
abstract class TacticCardFactory {
  static List<TacticCard> allCards() => const [
        OverlapCard(),
        HighPressCard(),
        CounterAttackCard(),
        ThroughPassCard(),
        TikiTakaCard(),
        SweeperKeeperCard(),
      ];

  static List<TacticCard> randomHand(int count) {
    final list = List<TacticCard>.from(allCards())..shuffle();
    return list.take(count).toList();
  }
}
