import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_strings.dart';
import '../providers/game_provider.dart';
import '../services/firebase_service.dart';
import '../services/localization_service.dart';

class DonationRankingScreen extends StatefulWidget {
  const DonationRankingScreen({super.key});

  @override
  State<DonationRankingScreen> createState() => _DonationRankingScreenState();
}

class _DonationRankingScreenState extends State<DonationRankingScreen> {
  final TextEditingController _donateController = TextEditingController();
  bool _isDonating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _donateController.dispose();
    super.dispose();
  }

  Future<void> _donate() async {
    if (_isDonating) return;

    final gameProvider = context.read<GameProvider>();
    final localization = context.read<LocalizationService>();

    final text = _donateController.text.trim();

    // Validate input
    if (text.isEmpty) {
      setState(() => _errorMessage = localization.translate({
        'en': 'Please enter an amount',
        'ko': '금액을 입력하세요',
      }));
      return;
    }

    final amount = int.tryParse(text);

    if (amount == null) {
      setState(() => _errorMessage = localization.translate({
        'en': 'Please enter a valid number',
        'ko': '유효한 숫자를 입력하세요',
      }));
      return;
    }

    if (amount <= 0) {
      setState(() => _errorMessage = localization.translate({
        'en': 'Amount must be greater than 0',
        'ko': '금액은 0보다 커야 합니다',
      }));
      return;
    }

    if (amount > gameProvider.balance) {
      setState(() => _errorMessage = localization.translate(AppStrings.insufficientFunds));
      return;
    }

    setState(() {
      _isDonating = true;
      _errorMessage = null;
    });

    try {
      await gameProvider.donate(amount);
      _donateController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(localization.translate({
              'en': 'Donation Successful! Rank Updated.',
              'ko': '기부 완료! 랭킹이 업데이트되었습니다.',
            })),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(localization.translate({
              'en': 'Donation failed. Please try again.',
              'ko': '기부 실패. 다시 시도해주세요.',
            })),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDonating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final firebaseService = context.read<FirebaseService>();
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr({'en': 'Hall of Fame 🏆', 'ko': '명예의 전당 🏆'})),
      ),
      body: Column(
        children: [
          // Donation Area
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF252525),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${tr(AppStrings.balance)}: 🪙 ${gameProvider.balance}",
                  style: const TextStyle(fontSize: 18, color: Colors.amber),
                ),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _donateController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            enabled: !_isDonating,
                            decoration: InputDecoration(
                              labelText: tr({'en': 'Amount to Donate', 'ko': '기부 금액'}),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.volunteer_activism),
                              errorText: _errorMessage,
                            ),
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() => _errorMessage = null);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isDonating ? null : _donate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: _isDonating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : Text(
                                tr({'en': 'DONATE', 'ko': '기부'}),
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr({
                    'en': 'Donating coins removes them from your wallet but increases your Ranking Score.',
                    'ko': '코인을 기부하면 지갑에서 차감되지만 랭킹 점수가 올라갑니다.',
                  }),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Ranking List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firebaseService.getRankingStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(tr({'en': 'Error loading rankings', 'ko': '랭킹 로딩 오류'})),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emoji_events, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          tr({'en': 'No donations yet. Be the first!', 'ko': '아직 기부자가 없습니다. 첫 번째가 되어보세요!'}),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final uid = data['uid'] as String;
                    final totalDonated = data['totalDonated'] ?? 0;
                    final isMe = uid == firebaseService.user?.uid;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.amber.withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: _buildRankBadge(index),
                        title: Text(
                          isMe
                              ? tr({'en': 'YOU', 'ko': '나'})
                              : "${tr({'en': 'Player', 'ko': '플레이어'})} ${uid.substring(0, 4)}...",
                          style: TextStyle(
                            color: isMe ? Colors.amber : Colors.white,
                            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              "$totalDonated",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amberAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int index) {
    IconData? icon;
    Color bgColor;
    Color textColor;

    switch (index) {
      case 0:
        icon = Icons.looks_one;
        bgColor = Colors.amber;
        textColor = Colors.black;
        break;
      case 1:
        icon = Icons.looks_two;
        bgColor = Colors.grey.shade400;
        textColor = Colors.black;
        break;
      case 2:
        icon = Icons.looks_3;
        bgColor = Colors.brown.shade400;
        textColor = Colors.white;
        break;
      default:
        bgColor = Colors.grey.shade800;
        textColor = Colors.white;
    }

    return CircleAvatar(
      backgroundColor: bgColor,
      child: icon != null
          ? Icon(icon, color: textColor, size: 24)
          : Text(
              "${index + 1}",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
    );
  }
}
