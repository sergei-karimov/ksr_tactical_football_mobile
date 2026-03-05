import 'package:flutter/foundation.dart';
import '../models/game_config.dart';
import '../models/grid_pos.dart';
import '../models/player_model.dart';

/// Central game state.  Holds the player registry, ball state, score,
/// and grid metadata.  Notifies listeners on score/state changes.
class GameManager extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------
  GameFormat format;
  bool isVsAI;
  int aiDifficulty; // 1–3

  // Grid
  int gridWidth  = 15;
  int gridHeight = 11;
  int get homeGoalCol => 0;
  int get awayGoalCol => gridWidth - 1;
  late List<int> homeGoalRows;
  late List<int> awayGoalRows;

  // Score / turn
  int homeScore    = 0;
  int awayScore    = 0;
  int turnNumber   = 0;
  int maxTurns     = 30;
  GameState state  = GameState.menu;

  // Players
  final List<PlayerModel> allPlayers  = [];
  final List<PlayerModel> homePlayers = [];
  final List<PlayerModel> awayPlayers = [];

  // Ball
  GridPos  ballPos     = const GridPos(7, 5);
  PlayerModel? ballCarrier; // null = loose ball

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  GameManager({
    this.format      = GameFormat.f11v11,
    this.isVsAI      = true,
    this.aiDifficulty = 2,
  });

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------
  void setup({
    required GameFormat format,
    required bool vsAI,
    required int difficulty,
  }) {
    this.format   = format;
    isVsAI        = vsAI;
    aiDifficulty  = difficulty;
    homeScore     = 0;
    awayScore     = 0;
    turnNumber    = 0;
    state         = GameState.playing;
    allPlayers.clear();
    homePlayers.clear();
    awayPlayers.clear();
    ballCarrier   = null;

    final cfg     = formatConfigs[format]!;
    gridWidth     = cfg.gridW;
    gridHeight    = cfg.gridH;
    final mid     = gridHeight ~/ 2;
    homeGoalRows  = [mid - 1, mid, mid + 1];
    awayGoalRows  = [mid - 1, mid, mid + 1];
    ballPos       = GridPos(gridWidth ~/ 2, gridHeight ~/ 2);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Player registry
  // ---------------------------------------------------------------------------
  void registerPlayer(PlayerModel p) {
    allPlayers.add(p);
    if (p.teamId == teamHome) {
      homePlayers.add(p);
    } else {
      awayPlayers.add(p);
    }
  }

  PlayerModel? playerAt(GridPos pos) {
    for (final p in allPlayers) {
      if (p.gridPos == pos) return p;
    }
    return null;
  }

  List<PlayerModel> getTeamPlayers(int team) =>
      team == teamHome ? List.unmodifiable(homePlayers) : List.unmodifiable(awayPlayers);

  int opponentTeam(int team) => team == teamHome ? teamAway : teamHome;

  // ---------------------------------------------------------------------------
  // Ball
  // ---------------------------------------------------------------------------
  void setBallCarrier(PlayerModel? player) {
    ballCarrier?.hasBall = false;
    ballCarrier = player;
    if (player != null) {
      player.hasBall = true;
      ballPos = player.gridPos;
    }
    notifyListeners();
  }

  void dropBallAt(GridPos pos) {
    ballCarrier?.hasBall = false;
    ballCarrier = null;
    ballPos = pos;
    notifyListeners();
  }

  void syncBallWithCarrier() {
    if (ballCarrier != null) {
      ballPos = ballCarrier!.gridPos;
    }
  }

  // ---------------------------------------------------------------------------
  // Scoring / game flow
  // ---------------------------------------------------------------------------

  /// Returns the scoring team if `pos` is a goal, else null.
  int? checkGoal(GridPos pos) {
    if (pos.x <= homeGoalCol && homeGoalRows.contains(pos.y)) return teamAway;
    if (pos.x >= awayGoalCol && awayGoalRows.contains(pos.y)) return teamHome;
    return null;
  }

  void recordGoal(int team) {
    if (team == teamHome) { homeScore++; } else { awayScore++; }
    // Kick-off: return ball to centre
    ballPos = GridPos(gridWidth ~/ 2, gridHeight ~/ 2);
    setBallCarrier(null);
    notifyListeners();
  }

  void advanceTurn() {
    turnNumber++;
    if (turnNumber >= maxTurns) {
      state = GameState.gameOver;
    }
    notifyListeners();
  }

  bool isValidCell(GridPos pos) =>
      pos.x >= 0 && pos.x < gridWidth && pos.y >= 0 && pos.y < gridHeight;

  // ---------------------------------------------------------------------------
  // Snapshot for AI
  // ---------------------------------------------------------------------------
  BoardSnapshot takeSnapshot() {
    return BoardSnapshot(
      playerSnaps: {for (final p in allPlayers) p: p.snapshot()},
      ballPos: ballPos,
      ballCarrier: ballCarrier,
      homeScore: homeScore,
      awayScore: awayScore,
    );
  }

  void restoreSnapshot(BoardSnapshot snap) {
    for (final entry in snap.playerSnaps.entries) {
      entry.key.restoreSnapshot(entry.value);
    }
    ballPos     = snap.ballPos;
    ballCarrier = snap.ballCarrier;
    homeScore   = snap.homeScore;
    awayScore   = snap.awayScore;
  }
}

class BoardSnapshot {
  final Map<PlayerModel, PlayerSnapshot> playerSnaps;
  final GridPos ballPos;
  final PlayerModel? ballCarrier;
  final int homeScore;
  final int awayScore;

  const BoardSnapshot({
    required this.playerSnaps,
    required this.ballPos,
    required this.ballCarrier,
    required this.homeScore,
    required this.awayScore,
  });
}
