import 'package:flutter/foundation.dart';
import '../models/game_config.dart';
import '../models/grid_pos.dart';
import '../models/move_data.dart';
import '../models/player_model.dart';
import '../models/tactic_card.dart';
import 'action_system.dart';
import 'ai_controller.dart';
import 'dice_system.dart';
import 'game_manager.dart';

/// Turn flow finite-state machine.  Drives all phase transitions.
class TurnManager extends ChangeNotifier {
  final GameManager gm;
  final DiceSystem  dice;

  TurnManager(this.gm, this.dice);

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------
  TurnPhase phase          = TurnPhase.awaitingRoll;
  int       currentTeam    = teamHome;
  int       actionsLeft    = 2;
  bool      tacticCardUsed = false;

  PlayerModel? selectedPlayer;
  ActionType?  selectedAction;

  // Last action feedback
  String lastMessage = '';

  // ---------------------------------------------------------------------------
  // Turn start
  // ---------------------------------------------------------------------------
  void startTurn(int team) {
    currentTeam    = team;
    actionsLeft    = 2;
    tacticCardUsed = false;
    selectedPlayer = null;
    selectedAction = null;
    lastMessage    = '';
    _clearBonuses(team);
    _setPhase(TurnPhase.awaitingRoll);
  }

  void _clearBonuses(int team) {
    for (final p in gm.getTeamPlayers(team)) {
      p.bonuses.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // Dice
  // ---------------------------------------------------------------------------
  void requestRoll() {
    if (phase != TurnPhase.awaitingRoll) return;
    dice.roll();
    actionsLeft = dice.totalActions(dice.lastResult);
    lastMessage = DiceSystem.effectLabel(dice.lastResult);
    _setPhase(TurnPhase.selectingPlayer);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Player / action selection
  // ---------------------------------------------------------------------------
  void selectPlayer(PlayerModel player) {
    if (phase != TurnPhase.selectingPlayer) return;
    if (player.teamId != currentTeam) return;

    selectedPlayer?.bonuses.remove('selected');
    selectedPlayer = player;
    _setPhase(TurnPhase.selectingAction);
  }

  void selectAction(ActionType action) {
    if (phase != TurnPhase.selectingAction) return;
    selectedAction = action;
    _setPhase(TurnPhase.awaitingTarget);
  }

  void cancelSelection() {
    selectedPlayer = null;
    selectedAction = null;
    _setPhase(TurnPhase.selectingPlayer);
  }

  // ---------------------------------------------------------------------------
  // Execute
  // ---------------------------------------------------------------------------
  void executeAction(MoveData move) {
    if (phase != TurnPhase.awaitingTarget) return;

    final result = ActionSystem(gm).execute(move, dice.lastResult);
    lastMessage = result.message;
    selectedPlayer = null;
    selectedAction = null;

    if (result.goalScored) {
      // End turn immediately; conceding team gets kick-off at centre
      _setPhase(TurnPhase.turnEnd);
      final concedingTeam = gm.opponentTeam(result.scoringTeam!);
      _assignKickOff(concedingTeam);
      gm.advanceTurn();
      if (gm.state != GameState.playing) return;
      if (gm.isVsAI && concedingTeam == teamAway) {
        _runAITurn();
      } else {
        startTurn(concedingTeam);
      }
      return;
    }

    if (result.success) {
      actionsLeft--;
      if (actionsLeft <= 0) {
        _endTurn();
      } else {
        _setPhase(TurnPhase.selectingPlayer);
      }
    } else {
      _setPhase(TurnPhase.selectingPlayer);
    }
  }

  void _assignKickOff(int team) {
    final centre  = GridPos(gm.gridWidth ~/ 2, gm.gridHeight ~/ 2);
    final players = gm.getTeamPlayers(team);
    if (players.isEmpty) return;
    final nearest = players.reduce((a, b) =>
        a.gridPos.manhattanTo(centre) <= b.gridPos.manhattanTo(centre) ? a : b);
    gm.setBallCarrier(nearest);
  }

  void skipAction() {
    actionsLeft--;
    lastMessage = 'Action skipped';
    if (actionsLeft <= 0) {
      _endTurn();
    } else {
      _setPhase(TurnPhase.selectingPlayer);
    }
  }

  bool useTacticCard(TacticCard card) {
    if (tacticCardUsed) return false;
    final ok = card.applyEffect(gm, currentTeam);
    if (ok) {
      tacticCardUsed = true;
      lastMessage    = 'Card played: ${card.name}';
      notifyListeners();
    }
    return ok;
  }

  // ---------------------------------------------------------------------------
  // Turn end / switch
  // ---------------------------------------------------------------------------
  void _endTurn() {
    _setPhase(TurnPhase.turnEnd);
    gm.advanceTurn();
    if (gm.state != GameState.playing) return;

    final next = gm.opponentTeam(currentTeam);
    if (gm.isVsAI && next == teamAway) {
      _runAITurn();
    } else {
      startTurn(next);
    }
  }

  Future<void> _runAITurn() async {
    _setPhase(TurnPhase.aiThinking);
    // Give the UI a frame to show "thinking"
    await Future.delayed(const Duration(milliseconds: 400));
    final ai        = AIController(gm, dice);
    final goalScored = ai.executeAITurn(teamAway, gm.aiDifficulty);
    if (goalScored) _assignKickOff(teamHome);
    startTurn(teamHome);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  void _setPhase(TurnPhase p) {
    phase = p;
    notifyListeners();
  }

  String get phaseName => phase.name;
  bool get isHumanTurn => currentTeam == teamHome || !gm.isVsAI;
}
