import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class GameProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  int _localBalance = 0;

  GameProvider(this._firebaseService) {
    _firebaseService.getUserStream().listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        _localBalance = data['balance'] ?? 0;
        notifyListeners();
      }
    });
  }

  int get balance => _localBalance;

  Future<void> spinSlotMachine(int betAmount) async {
    if (_localBalance < betAmount) return;
    // Optimistic update
    _localBalance -= betAmount;
    notifyListeners();
    await _firebaseService.updateBalance(-betAmount);
  }

  Future<void> winPrize(int amount) async {
    _localBalance += amount;
    notifyListeners();
    await _firebaseService.updateBalance(amount);
  }
  
  Future<void> rewardUser(int amount) async {
    _localBalance += amount;
    notifyListeners();
    await _firebaseService.updateBalance(amount);
  }

  Future<void> donate(int amount) async {
    if (_localBalance < amount) return;
    _localBalance -= amount;
    notifyListeners();
    await _firebaseService.donate(amount);
  }
}
