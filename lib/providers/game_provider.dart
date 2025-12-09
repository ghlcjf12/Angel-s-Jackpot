import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class GameProvider extends ChangeNotifier {
  final FirebaseService _firebaseService;
  int _localBalance = 0;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  GameProvider(this._firebaseService) {
    _firebaseService.addListener(_onFirebaseUserChanged);
    _refreshUserSubscription();
  }

  void _onFirebaseUserChanged() {
    // When Firebase user changes (login/logout), refresh the subscription
    _refreshUserSubscription();
  }

  int get balance => _localBalance;

  /// Place a bet using transaction-based deduction
  /// Returns true if successful, false if insufficient balance
  Future<bool> placeBet(int betAmount) async {
    if (_localBalance < betAmount) return false;

    final success = await _firebaseService.deductBalance(betAmount);

    if (!success) {
      // Transaction failed, sync with server
      return false;
    }

    // Update successful - local balance will be updated via stream
    return true;
  }

  /// Add winnings using transaction-based addition
  Future<void> winPrize(int amount) async {
    await _firebaseService.addBalance(amount);
    // Local balance will be updated via stream
  }

  Future<void> donate(int amount) async {
    if (_localBalance < amount) return;
    _localBalance -= amount;
    notifyListeners();
    await _firebaseService.donate(amount);
  }

  void _refreshUserSubscription() {
    _userSubscription?.cancel();
    _userSubscription = _firebaseService.getUserStream().listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          _localBalance = data['balance'] ?? 0;
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint("User stream error: $error");
        // Don't crash if Firestore fails, just log it
      },
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _firebaseService.removeListener(_onFirebaseUserChanged);
    super.dispose();
  }
}
