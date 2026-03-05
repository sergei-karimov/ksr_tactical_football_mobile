import 'package:flutter_test/flutter_test.dart';
import 'package:ksr_tactical_football/game/systems/dice_system.dart';

void main() {
  // ------------------------------------------------------------------
  // roll()
  // ------------------------------------------------------------------
  group('roll', () {
    test('result is in range [1, 6]', () {
      final ds = DiceSystem();
      for (int i = 0; i < 200; i++) {
        final r = ds.roll();
        expect(r, inInclusiveRange(1, 6));
      }
    });

    test('all six faces appear over many rolls', () {
      final ds      = DiceSystem();
      final results = <int>{};
      for (int i = 0; i < 600; i++) {
        results.add(ds.roll());
      }
      expect(results, containsAll([1, 2, 3, 4, 5, 6]));
    });

    test('lastResult updates after roll', () {
      final ds = DiceSystem();
      ds.roll();
      expect(ds.lastResult, inInclusiveRange(1, 6));
    });

    test('lastEffect is set after roll', () {
      final ds = DiceSystem();
      ds.roll();
      expect(ds.lastEffect, isNotNull);
    });
  });

  // ------------------------------------------------------------------
  // totalActions
  // ------------------------------------------------------------------
  group('totalActions', () {
    test('dice 1 → 1 action (mistake)', () {
      expect(DiceSystem.actionModifier(1), -1);
      // total = (2 + (-1)).clamp(1,3) = 1
      expect(DiceSystem().totalActions(1), 1);
    });

    test('dice 2 → 2 actions (normal)', () {
      expect(DiceSystem().totalActions(2), 2);
    });

    test('dice 3 → 2 actions', () {
      expect(DiceSystem().totalActions(3), 2);
    });

    test('dice 4 → 2 actions', () {
      expect(DiceSystem().totalActions(4), 2);
    });

    test('dice 5 → 2 actions', () {
      expect(DiceSystem().totalActions(5), 2);
    });

    test('dice 6 → 3 actions (super action)', () {
      expect(DiceSystem.actionModifier(6), 1);
      expect(DiceSystem().totalActions(6), 3);
    });
  });

  // ------------------------------------------------------------------
  // actionModifier
  // ------------------------------------------------------------------
  group('actionModifier', () {
    test('only 1 gives -1', () {
      expect(DiceSystem.actionModifier(1), -1);
    });
    test('only 6 gives +1', () {
      expect(DiceSystem.actionModifier(6), 1);
    });
    test('all others give 0', () {
      for (final r in [2, 3, 4, 5]) {
        expect(DiceSystem.actionModifier(r), 0, reason: 'dice $r');
      }
    });
  });

  // ------------------------------------------------------------------
  // effectLabel
  // ------------------------------------------------------------------
  group('effectLabel', () {
    test('all six dice faces have a non-empty label', () {
      for (int r = 1; r <= 6; r++) {
        expect(DiceSystem.effectLabel(r), isNotEmpty, reason: 'dice $r');
      }
    });

    test('result 1 mentions mistake or action', () {
      final label = DiceSystem.effectLabel(1).toLowerCase();
      expect(label.contains('mistake') || label.contains('action'), isTrue);
    });

    test('result 6 mentions super or action', () {
      final label = DiceSystem.effectLabel(6).toLowerCase();
      expect(label.contains('super') || label.contains('action'), isTrue);
    });
  });
}
