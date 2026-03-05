import 'package:flutter_test/flutter_test.dart';
import 'package:ksr_tactical_football/game/models/game_config.dart';
import 'package:ksr_tactical_football/game/models/grid_pos.dart';
import 'package:ksr_tactical_football/game/models/player_model.dart';

PlayerModel makePlayer({
  int teamId = teamHome,
  int shooting = 7,
  int passing = 7,
  int dribbling = 7,
  int defending = 7,
  GridPos gridPos = const GridPos(5, 5),
  bool hasBall = false,
}) =>
    PlayerModel(
      teamId: teamId,
      shirtNumber: 1,
      role: PositionRole.cm,
      shooting: shooting,
      passing: passing,
      dribbling: dribbling,
      defending: defending,
      gridPos: gridPos,
      hasBall: hasBall,
    );

void main() {
  // ------------------------------------------------------------------
  // getMoveRange
  // ------------------------------------------------------------------
  group('getMoveRange', () {
    test('dice 1 → range 1', () {
      expect(makePlayer().getMoveRange(1), 1);
    });

    test('dice 2 → range 1', () {
      expect(makePlayer().getMoveRange(2), 1);
    });

    test('dice 3 → range 2', () {
      expect(makePlayer().getMoveRange(3), 2);
    });

    test('dice 6 → range 2', () {
      expect(makePlayer().getMoveRange(6), 2);
    });

    test('extra_movement bonus adds to range', () {
      final p = makePlayer()..bonuses['extra_movement'] = 1;
      expect(p.getMoveRange(2), 2); // base 1 + bonus 1
      expect(p.getMoveRange(3), 3); // base 2 + bonus 1
    });
  });

  // ------------------------------------------------------------------
  // getPassRange
  // ------------------------------------------------------------------
  group('getPassRange', () {
    test('short pass base is 2', () {
      expect(makePlayer().getPassRange('short', 2), 2);
    });

    test('medium pass base is 4', () {
      expect(makePlayer().getPassRange('medium', 2), 4);
    });

    test('long pass base is 6 when passing >= 7', () {
      expect(makePlayer(passing: 7).getPassRange('long', 2), 6);
      expect(makePlayer(passing: 10).getPassRange('long', 2), 6);
    });

    test('long pass returns 0 when passing < 7', () {
      expect(makePlayer(passing: 6).getPassRange('long', 2), 0);
    });

    test('dice 4 adds +2 to all pass types', () {
      expect(makePlayer().getPassRange('short',  4), 4);
      expect(makePlayer().getPassRange('medium', 4), 6);
      expect(makePlayer().getPassRange('long',   4), 8);
    });

    test('pass_bonus bonus adds to range', () {
      final p = makePlayer()..bonuses['pass_bonus'] = 2;
      expect(p.getPassRange('short', 2), 4);
    });

    test('unknown pass type returns 0', () {
      expect(makePlayer().getPassRange('mega', 2), 0);
    });
  });

  // ------------------------------------------------------------------
  // getShootProbability
  // ------------------------------------------------------------------
  group('getShootProbability', () {
    test('base probabilities: 80/60/40/20 for distances 1–4', () {
      final p = makePlayer(shooting: 5); // neutral stat → no modifier
      expect(p.getShootProbability(1), closeTo(0.80, 0.001));
      expect(p.getShootProbability(2), closeTo(0.60, 0.001));
      expect(p.getShootProbability(3), closeTo(0.40, 0.001));
      expect(p.getShootProbability(4), closeTo(0.20, 0.001));
    });

    test('distance 5+ uses 0.20 base', () {
      final p = makePlayer(shooting: 5);
      expect(p.getShootProbability(6), closeTo(0.20, 0.001));
    });

    test('high shooting stat increases probability', () {
      final low  = makePlayer(shooting: 5);
      final high = makePlayer(shooting: 9);
      expect(high.getShootProbability(2), greaterThan(low.getShootProbability(2)));
    });

    test('low shooting stat decreases probability', () {
      final avg = makePlayer(shooting: 5);
      final bad = makePlayer(shooting: 1);
      expect(bad.getShootProbability(2), lessThan(avg.getShootProbability(2)));
    });

    test('probability is clamped to [0.05, 0.99]', () {
      // Very poor shooter at long range
      final bad = makePlayer(shooting: 1);
      expect(bad.getShootProbability(10), greaterThanOrEqualTo(0.05));

      // Best shooter at closest range
      final great = makePlayer(shooting: 10)
        ..bonuses['shoot_bonus'] = 1.0;
      expect(great.getShootProbability(1), lessThanOrEqualTo(0.99));
    });

    test('shoot_bonus bonus is applied', () {
      final p = makePlayer(shooting: 5)..bonuses['shoot_bonus'] = 0.1;
      expect(p.getShootProbability(2), closeTo(0.70, 0.001));
    });
  });

  // ------------------------------------------------------------------
  // getDribbleSuccessProb
  // ------------------------------------------------------------------
  group('getDribbleSuccessProb', () {
    test('base prob for neutral dribbling=5', () {
      final p = makePlayer(dribbling: 5);
      expect(p.getDribbleSuccessProb(2), closeTo(0.50, 0.001));
    });

    test('dice 5 adds 0.25', () {
      final p = makePlayer(dribbling: 5);
      expect(p.getDribbleSuccessProb(5), closeTo(0.75, 0.001));
    });

    test('higher dribbling gives better probability', () {
      final avg  = makePlayer(dribbling: 5);
      final good = makePlayer(dribbling: 9);
      expect(good.getDribbleSuccessProb(2), greaterThan(avg.getDribbleSuccessProb(2)));
    });

    test('clamped to [0.10, 0.95]', () {
      final bad = makePlayer(dribbling: 1);
      expect(bad.getDribbleSuccessProb(2), greaterThanOrEqualTo(0.10));

      final ace = makePlayer(dribbling: 10)..bonuses['dribble_bonus'] = 1.0;
      expect(ace.getDribbleSuccessProb(5), lessThanOrEqualTo(0.95));
    });
  });

  // ------------------------------------------------------------------
  // getTackleProbAgainst
  // ------------------------------------------------------------------
  group('getTackleProbAgainst', () {
    test('equal stats gives 0.5', () {
      final tackler  = makePlayer(defending: 5);
      final opponent = makePlayer(dribbling: 5);
      expect(tackler.getTackleProbAgainst(opponent), closeTo(0.50, 0.001));
    });

    test('superior defending increases probability', () {
      final tackler  = makePlayer(defending: 9);
      final opponent = makePlayer(dribbling: 5);
      expect(tackler.getTackleProbAgainst(opponent), greaterThan(0.5));
    });

    test('inferior defending decreases probability', () {
      final tackler  = makePlayer(defending: 3);
      final opponent = makePlayer(dribbling: 9);
      expect(tackler.getTackleProbAgainst(opponent), lessThan(0.5));
    });

    test('clamped to [0.15, 0.90]', () {
      final elite     = makePlayer(defending: 10);
      final rubbish   = makePlayer(dribbling: 1);
      expect(elite.getTackleProbAgainst(rubbish), lessThanOrEqualTo(0.90));

      final awful  = makePlayer(defending: 1);
      final wizard = makePlayer(dribbling: 10);
      expect(awful.getTackleProbAgainst(wizard), greaterThanOrEqualTo(0.15));
    });
  });

  // ------------------------------------------------------------------
  // Snapshot / restore
  // ------------------------------------------------------------------
  group('snapshot / restore', () {
    test('snapshot captures current state', () {
      final p = makePlayer(gridPos: const GridPos(3, 4), hasBall: true);
      p.bonuses['extra_movement'] = 2;
      final snap = p.snapshot();
      expect(snap.gridPos, const GridPos(3, 4));
      expect(snap.hasBall, isTrue);
      expect(snap.bonuses['extra_movement'], 2);
    });

    test('restoreSnapshot reverts mutations', () {
      final p    = makePlayer(gridPos: const GridPos(3, 4));
      final snap = p.snapshot();

      p.gridPos = const GridPos(9, 9);
      p.hasBall = true;
      p.bonuses['extra_movement'] = 5;

      p.restoreSnapshot(snap);

      expect(p.gridPos, const GridPos(3, 4));
      expect(p.hasBall, isFalse);
      expect(p.bonuses.containsKey('extra_movement'), isFalse);
    });

    test('snapshot is a deep copy – mutating original does not change snap', () {
      final p    = makePlayer();
      final snap = p.snapshot();
      p.bonuses['x'] = 99;
      expect(snap.bonuses.containsKey('x'), isFalse);
    });
  });
}
