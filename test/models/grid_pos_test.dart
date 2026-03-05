import 'package:flutter_test/flutter_test.dart';
import 'package:ksr_tactical_football/game/models/grid_pos.dart';

void main() {
  group('GridPos', () {
    // ------------------------------------------------------------------
    // Equality & hashCode
    // ------------------------------------------------------------------
    group('equality', () {
      test('equal positions are ==', () {
        expect(const GridPos(3, 4), equals(const GridPos(3, 4)));
      });

      test('different x are not equal', () {
        expect(const GridPos(3, 4), isNot(equals(const GridPos(2, 4))));
      });

      test('different y are not equal', () {
        expect(const GridPos(3, 4), isNot(equals(const GridPos(3, 5))));
      });

      test('equal positions have the same hashCode', () {
        expect(const GridPos(5, 7).hashCode, const GridPos(5, 7).hashCode);
      });

      test('can be used as Map key', () {
        final map = {const GridPos(1, 2): 'a'};
        expect(map[const GridPos(1, 2)], 'a');
      });
    });

    // ------------------------------------------------------------------
    // Arithmetic operators
    // ------------------------------------------------------------------
    group('operator +', () {
      test('adds coordinates', () {
        const a = GridPos(1, 2);
        const b = GridPos(3, 4);
        expect(a + b, const GridPos(4, 6));
      });

      test('adding zero vector is identity', () {
        const a = GridPos(5, 3);
        expect(a + const GridPos(0, 0), a);
      });

      test('negative addend works', () {
        const a = GridPos(5, 5);
        const b = GridPos(-2, -3);
        expect(a + b, const GridPos(3, 2));
      });
    });

    group('operator *', () {
      test('scales both components', () {
        const a = GridPos(2, 3);
        expect(a * 3, const GridPos(6, 9));
      });

      test('multiply by 0 gives origin', () {
        expect(const GridPos(7, 8) * 0, const GridPos(0, 0));
      });

      test('multiply by 1 is identity', () {
        const a = GridPos(4, 9);
        expect(a * 1, a);
      });
    });

    // ------------------------------------------------------------------
    // Manhattan distance
    // ------------------------------------------------------------------
    group('manhattanTo', () {
      test('same position is 0', () {
        const a = GridPos(3, 3);
        expect(a.manhattanTo(a), 0);
      });

      test('horizontal distance', () {
        expect(const GridPos(0, 0).manhattanTo(const GridPos(5, 0)), 5);
      });

      test('vertical distance', () {
        expect(const GridPos(0, 0).manhattanTo(const GridPos(0, 4)), 4);
      });

      test('diagonal distance is sum of abs deltas', () {
        expect(const GridPos(0, 0).manhattanTo(const GridPos(3, 4)), 7);
      });

      test('is symmetric', () {
        const a = GridPos(1, 2);
        const b = GridPos(5, 7);
        expect(a.manhattanTo(b), b.manhattanTo(a));
      });

      test('negative direction works', () {
        expect(const GridPos(5, 5).manhattanTo(const GridPos(2, 1)), 7);
      });
    });

    // ------------------------------------------------------------------
    // Cardinal neighbours
    // ------------------------------------------------------------------
    group('cardinalNeighbors', () {
      test('returns exactly 4 neighbours', () {
        expect(const GridPos(3, 3).cardinalNeighbors.length, 4);
      });

      test('contains right, left, down, up', () {
        const p = GridPos(2, 2);
        final n = p.cardinalNeighbors;
        expect(n, containsAll([
          const GridPos(3, 2),
          const GridPos(1, 2),
          const GridPos(2, 3),
          const GridPos(2, 1),
        ]));
      });
    });

    // ------------------------------------------------------------------
    // toString
    // ------------------------------------------------------------------
    test('toString shows coordinates', () {
      expect(const GridPos(4, 7).toString(), 'GridPos(4, 7)');
    });
  });
}
