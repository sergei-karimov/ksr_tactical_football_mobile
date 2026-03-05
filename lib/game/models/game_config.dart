import 'package:flutter/material.dart';

enum GameFormat { f5v5, f7v7, f9v9, f11v11 }
enum GameState { menu, setup, playing, paused, gameOver }
enum TurnPhase {
  awaitingRoll,
  selectingPlayer,
  selectingAction,
  awaitingTarget,
  aiThinking,
  turnEnd,
}
enum ActionType { move, pass, dribble, shoot, tackle }
enum DiceEffect {
  mistake,       // 1
  normal,        // 2
  extraMovement, // 3
  extraPass,     // 4
  dribbleBonus,  // 5
  superAction,   // 6
}
enum PositionRole { gk, cb, lb, rb, cdm, cm, cam, lw, rw, st }

const int teamHome = 0;
const int teamAway = 1;

class FormatConfig {
  final int gridW;
  final int gridH;
  final int playerCount;

  const FormatConfig(this.gridW, this.gridH, this.playerCount);
}

const Map<GameFormat, FormatConfig> formatConfigs = {
  GameFormat.f5v5:   FormatConfig(9,  7,  5),
  GameFormat.f7v7:   FormatConfig(11, 9,  7),
  GameFormat.f9v9:   FormatConfig(13, 11, 9),
  GameFormat.f11v11: FormatConfig(15, 11, 11),
};

const Map<GameFormat, String> formatLabels = {
  GameFormat.f5v5:   '5 vs 5',
  GameFormat.f7v7:   '7 vs 7',
  GameFormat.f9v9:   '9 vs 9',
  GameFormat.f11v11: '11 vs 11',
};

// Team colours
const Color homeColor = Color(0xFF2255CC);
const Color awayColor = Color(0xFFCC3322);
const Color highlightColor = Color(0x88FFFF00);
const Color grassColor = Color(0xFF3A7D44);
const Color grassDarkColor = Color(0xFF2E6438);
const Color goalHomeColor = Color(0xFF7799FF);
const Color goalAwayColor = Color(0xFFFF7755);
