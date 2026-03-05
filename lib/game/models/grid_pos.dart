/// Immutable grid coordinate.
class GridPos {
  final int x;
  final int y;

  const GridPos(this.x, this.y);

  GridPos operator +(GridPos other) => GridPos(x + other.x, y + other.y);
  GridPos operator *(int scalar) => GridPos(x * scalar, y * scalar);

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  int manhattanTo(GridPos other) =>
      (x - other.x).abs() + (y - other.y).abs();

  List<GridPos> get cardinalNeighbors => [
        GridPos(x + 1, y),
        GridPos(x - 1, y),
        GridPos(x, y + 1),
        GridPos(x, y - 1),
      ];

  @override
  String toString() => 'GridPos($x, $y)';
}
