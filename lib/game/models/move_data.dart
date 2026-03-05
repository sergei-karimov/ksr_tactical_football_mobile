import 'game_config.dart';
import 'grid_pos.dart';
import 'player_model.dart';

class MoveData {
  final ActionType action;
  final PlayerModel player;
  final Object target; // GridPos or PlayerModel
  final Map<String, Object> metadata;

  const MoveData({
    required this.action,
    required this.player,
    required this.target,
    this.metadata = const {},
  });

  GridPos get targetCell {
    if (target is GridPos) return target as GridPos;
    if (target is PlayerModel) return (target as PlayerModel).gridPos;
    throw StateError('Unexpected target type: ${target.runtimeType}');
  }

  @override
  String toString() => 'MoveData(${action.name}, ${player.shirtNumber}, $target)';
}
