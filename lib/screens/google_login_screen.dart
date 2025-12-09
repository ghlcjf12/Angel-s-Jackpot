import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/firebase_service.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() => _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final success = await context.read<FirebaseService>().signInWithGoogle();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!success) {
        _showMessage("Google 로그인에 실패했습니다. Firebase 설정을 확인하세요.");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage("오류: ${e.toString()}");
      }
    }
  }

  Future<void> _playAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await context.read<FirebaseService>().signInAnonymously();
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage("게스트로 로그인 되었습니다. 즐겁게 플레이 해보세요!");
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage("게스트 로그인 실패: ${e.toString()}");
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(color: Colors.white))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF111111), Color(0xFF1E1E1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Text(
                  "Angel's Jackpot",
                  style: TextStyle(
                    fontSize: 36,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "구글 계정으로 로그인하면 데이터가 안전하게 저장되고 첫 가입 시 \$1,000 보너스를 드립니다.",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    minimumSize: const Size.fromHeight(56),
                  ),
                  icon: const Icon(Icons.g_mobiledata, color: Colors.black, size: 32),
                  label: const Text(
                    "Google로 계속하기",
                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading ? null : _playAsGuest,
                  child: const Text("게스트로 진입하기", style: TextStyle(color: Colors.white70)),
                ),
                if (_isLoading) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(color: Colors.amber),
                ],
                const Spacer(),
                const Text(
                  "처음 로그인 시 게임 머니 \$1,000가 자동으로 충전되며, 로그인 상태는 자동으로 유지됩니다.",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
