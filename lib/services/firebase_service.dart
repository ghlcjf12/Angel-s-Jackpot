import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get user => _auth.currentUser;

  Future<void> signInAnonymously() async {
    try {
      if (user == null) {
        await _auth.signInAnonymously();
        await _initializeUser();
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
  }

  Future<void> _initializeUser() async {
    if (user == null) return;
    final userRef = _db.collection('users').doc(user!.uid);
    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        'uid': user!.uid,
        'balance': 1000, // Initial coins
        'totalDonated': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<DocumentSnapshot> getUserStream() {
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user!.uid).snapshots();
  }

  Future<void> donate(int amount) async {
    if (user == null) return;
    final userRef = _db.collection('users').doc(user!.uid);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final currentBalance = snapshot.get('balance') as int;
      final currentDonated = snapshot.get('totalDonated') as int;

      if (currentBalance >= amount) {
        transaction.update(userRef, {
          'balance': currentBalance - amount,
          'totalDonated': currentDonated + amount,
        });
      } else {
        throw Exception("Insufficient balance");
      }
    });
  }

  Future<void> updateBalance(int amount) async {
    if (user == null) return;
    final userRef = _db.collection('users').doc(user!.uid);
    await userRef.update({
      'balance': FieldValue.increment(amount),
    });
  }

  Stream<QuerySnapshot> getRankingStream() {
    return _db
        .collection('users')
        .orderBy('totalDonated', descending: true)
        .limit(100)
        .snapshots();
  }
}
