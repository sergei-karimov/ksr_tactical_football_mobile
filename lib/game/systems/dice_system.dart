import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_config.dart';

class DiceSystem extends ChangeNotifier {
  final _rng = Random();

  int lastResult = 0;
  DiceEffect? lastEffect;

  int roll() {
    lastResult = _rng.nextInt(6) + 1;
    lastEffect = _effectFor(lastResult);
    notifyListeners();
    return lastResult;
  }

  static DiceEffect _effectFor(int result) {
    switch (result) {
      case 1:  return DiceEffect.mistake;
      case 2:  return DiceEffect.normal;
      case 3:  return DiceEffect.extraMovement;
      case 4:  return DiceEffect.extraPass;
      case 5:  return DiceEffect.dribbleBonus;
      case 6:  return DiceEffect.superAction;
      default: return DiceEffect.normal;
    }
  }

  /// How many actions to add/subtract from base 2.
  static int actionModifier(int result) {
    if (result == 1) return -1;
    if (result == 6) return 1;
    return 0;
  }

  static String effectLabel(int result) {
    switch (result) {
      case 1:  return 'Mistake! -1 action';
      case 2:  return 'Normal turn';
      case 3:  return 'Extra movement!';
      case 4:  return 'Extra pass range!';
      case 5:  return 'Dribble bonus!';
      case 6:  return 'Super action! +1 action';
      default: return '';
    }
  }

  int totalActions(int result) => (2 + actionModifier(result)).clamp(1, 3);
}
