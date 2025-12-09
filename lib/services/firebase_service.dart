import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.standard();

  FirebaseService() {
    _auth.authStateChanges().listen((_) => notifyListeners());
  }

  User? get user => _auth.currentUser;

  Future<void> signInAnonymously() async {
    try {
      if (user == null) {
        await _auth.signInAnonymously();
        await _initializeUser();
      }
    } catch (e) {
      debugPrint("Anonymous Auth Error: $e");
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      await _initializeUser();
      return true;
    } catch (e) {
      debugPrint("Google sign-in failed: $e");
      return false;
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

  /// Transaction-based balance deduction for game bets
  /// Returns true if successful, false if insufficient balance
  Future<bool> deductBalance(int amount) async {
    if (user == null) return false;
    final userRef = _db.collection('users').doc(user!.uid);

    try {
      return await _db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return false;

        final currentBalance = snapshot.get('balance') as int;

        if (currentBalance >= amount) {
          transaction.update(userRef, {
            'balance': currentBalance - amount,
          });
          return true;
        } else {
          return false;
        }
      });
    } catch (e) {
      debugPrint("Transaction failed: $e");
      return false;
    }
  }

  /// Transaction-based balance addition for winnings
  Future<bool> addBalance(int amount) async {
    if (user == null) return false;
    final userRef = _db.collection('users').doc(user!.uid);

    try {
      return await _db.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) return false;

        final currentBalance = snapshot.get('balance') as int;
        transaction.update(userRef, {
          'balance': currentBalance + amount,
        });
        return true;
      });
    } catch (e) {
      debugPrint("Transaction failed: $e");
      return false;
    }
  }

  Stream<QuerySnapshot> getRankingStream() {
    return _db
        .collection('users')
        .orderBy('totalDonated', descending: true)
        .limit(100)
        .snapshots();
  }
}
