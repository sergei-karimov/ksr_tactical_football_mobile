import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'components/ball_component.dart';
import 'components/board_component.dart';
import 'components/player_component.dart';
import 'models/game_config.dart';
import 'models/grid_pos.dart';
import 'models/move_data.dart';
import 'models/player_model.dart';
import 'models/tactic_card.dart';
import 'systems/dice_system.dart';
import 'systems/game_manager.dart';
import 'systems/turn_manager.dart';

class TacticalFootballGame extends FlameGame with TapCallbacks {
  // ---------------------------------------------------------------------------
  // Systems (public so overlays can read them)
  // ---------------------------------------------------------------------------
  final GameManager gameManager = GameManager();
  final DiceSystem  diceSystem  = DiceSystem();
  late final TurnManager turnManager;

  // ---------------------------------------------------------------------------
  // Components
  // ---------------------------------------------------------------------------
  BoardComponent?      board;
  BallComponent?       ballComp;
  final List<PlayerComponent> playerComps = [];

  // Tactic card hand for this match
  List<TacticCard> cardHand = [];

  // Tile layout (computed per format + screen size)
  double tileSize     = 40.0;
  double boardOffsetX = 0;
  double boardOffsetY = 0;

  // ---------------------------------------------------------------------------
  // Overlay IDs
  // ---------------------------------------------------------------------------
  static const overlayMainMenu  = 'MainMenu';
  static const overlayHUD       = 'HUD';
  static const overlayCardPanel = 'CardPanel';

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  Color backgroundColor() => const Color(0xFF0A1628);

  @override
  Future<void> onLoad() async {
    turnManager = TurnManager(gameManager, diceSystem);
    overlays.add(overlayMainMenu);
  }

  // ---------------------------------------------------------------------------
  // Start a new game (called from MainMenuOverlay)
  // ---------------------------------------------------------------------------
  void startGame({
    required GameFormat format,
    required bool vsAI,
    required int difficulty,
  }) {
    gameManager.setup(format: format, vsAI: vsAI, difficulty: difficulty);

    _computeTileSize();
    _rebuildBoard();

    cardHand = TacticCardFactory.randomHand(3);

    overlays.remove(overlayMainMenu);
    overlays.add(overlayHUD);

    turnManager.startTurn(teamHome);
  }

  // ---------------------------------------------------------------------------
  // Layout helpers
  // ---------------------------------------------------------------------------
  void _computeTileSize() {
    // Reserve 14% top + 14% bottom for Flutter HUD overlays
    final availW = size.x * 0.98;
    final availH = size.y * 0.72;
    final tsW    = availW / gameManager.gridWidth;
    final tsH    = availH / gameManager.gridHeight;
    tileSize     = tsW < tsH ? tsW : tsH;

    boardOffsetX = (size.x - tileSize * gameManager.gridWidth)  / 2;
    boardOffsetY = size.y * 0.14;
  }

  GridPos screenToGrid(Vector2 pos) => GridPos(
        ((pos.x - boardOffsetX) / tileSize).floor(),
        ((pos.y - boardOffsetY) / tileSize).floor(),
      );

  Vector2 gridToWorld(GridPos pos) => Vector2(
        boardOffsetX + pos.x * tileSize + tileSize / 2,
        boardOffsetY + pos.y * tileSize + tileSize / 2,
      );

  // ---------------------------------------------------------------------------
  // Board rebuild
  // ---------------------------------------------------------------------------
  void _rebuildBoard() {
    // Remove old components
    board?.removeFromParent();
    ballComp?.removeFromParent();
    for (final pc in playerComps) { pc.removeFromParent(); }
    playerComps.clear();
    gameManager.allPlayers.clear();
    gameManager.homePlayers.clear();
    gameManager.awayPlayers.clear();

    // Add board
    final newBoard = BoardComponent(game: this);
    add(newBoard);
    board = newBoard;

    // Spawn players
    final cfg = formatConfigs[gameManager.format]!;
    _spawnTeam(teamHome, cfg.playerCount);
    _spawnTeam(teamAway, cfg.playerCount);

    // Give ball to first home player
    final home = gameManager.homePlayers;
    if (home.isNotEmpty) gameManager.setBallCarrier(home.first);

    // Spawn ball
    final newBall = BallComponent(game: this);
    add(newBall);
    ballComp = newBall;
  }

  void _spawnTeam(int team, int count) {
    final positions = _defaultPositions(team, count);
    for (int i = 0; i < count; i++) {
      final model = PlayerModel(
        teamId:      team,
        shirtNumber: i + 1,
        role:        _roleForIndex(i, count),
        gridPos:     positions[i],
      );
      gameManager.registerPlayer(model);
      final comp = PlayerComponent(model: model, game: this);
      add(comp);
      playerComps.add(comp);
    }
  }

  // ---------------------------------------------------------------------------
  // Resize
  // ---------------------------------------------------------------------------
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (gameManager.state == GameState.playing) {
      _computeTileSize();
    }
  }

  // ---------------------------------------------------------------------------
  // Tap input
  // ---------------------------------------------------------------------------
  @override
  void onTapDown(TapDownEvent event) {
    if (gameManager.state != GameState.playing) return;
    if (!turnManager.isHumanTurn) return;
    if (turnManager.phase == TurnPhase.aiThinking) return;

    final gridPos = screenToGrid(event.canvasPosition);
    if (!gameManager.isValidCell(gridPos)) return;

    final player = gameManager.playerAt(gridPos);
    _handleInput(gridPos, player);
  }

  void _handleInput(GridPos gridPos, PlayerModel? player) {
    switch (turnManager.phase) {
      case TurnPhase.awaitingRoll:
        break;

      case TurnPhase.selectingPlayer:
        if (player != null && player.teamId == turnManager.currentTeam) {
          turnManager.selectPlayer(player);
        }

      case TurnPhase.awaitingTarget:
        final sp     = turnManager.selectedPlayer;
        final action = turnManager.selectedAction;
        if (sp == null || action == null) return;

        // Build target: for pass/tackle prefer PlayerModel, else GridPos
        final Object target;
        if ((action == ActionType.pass || action == ActionType.tackle) &&
            player != null) {
          target = player;
        } else {
          target = gridPos;
        }

        final move = MoveData(action: action, player: sp, target: target);
        turnManager.executeAction(move);
        board?.clearHighlights();

      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // HUD callbacks
  // ---------------------------------------------------------------------------
  void onRollDice() => turnManager.requestRoll();

  void onActionSelected(ActionType action) {
    if (turnManager.selectedPlayer == null) return;
    turnManager.selectAction(action);
    board?.showHighlightsForAction(action);
  }

  void onSkipAction() {
    turnManager.skipAction();
    board?.clearHighlights();
  }

  void onCancelSelection() {
    turnManager.cancelSelection();
    board?.clearHighlights();
  }

  void onTacticCard(TacticCard card) {
    turnManager.useTacticCard(card);
    cardHand.remove(card);
    overlays.remove(overlayCardPanel);
  }

  // ---------------------------------------------------------------------------
  // Default starting formations
  // ---------------------------------------------------------------------------
  List<GridPos> _defaultPositions(int team, int count) {
    final mid    = gameManager.gridHeight ~/ 2;
    final startX = team == teamHome ? 1 : gameManager.gridWidth - 2;
    final stepX  = team == teamHome ? 1 : -1;
    final spread = _ySpread(count);
    final out    = <GridPos>[];
    int placed = 0, col = 0;

    while (placed < count) {
      for (int i = 0; i < spread.length && placed < count; i++) {
        out.add(GridPos(startX + col * stepX, mid + spread[i]));
        placed++;
      }
      col++;
    }
    return out;
  }

  List<int> _ySpread(int count) => switch (count) {
        5  => [0, -1, 1, -2, 2],
        7  => [0, -1, 1, -2, 2, -3, 3],
        9  => [0, -1, 1, -2, 2, -3, 3, -4, 4],
        11 => [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5],
        _  => [0],
      };

  PositionRole _roleForIndex(int i, int total) {
    if (i == 0)         return PositionRole.gk;
    if (i == total - 1) return PositionRole.st;
    if (i >= total - 3) return PositionRole.cam;
    return PositionRole.cm;
  }
}
