import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class VideoPokerGameScreen extends StatefulWidget {
  const VideoPokerGameScreen({super.key});

  @override
  State<VideoPokerGameScreen> createState() => _VideoPokerGameScreenState();
}

class _VideoPokerGameScreenState extends State<VideoPokerGameScreen> {
  int _betAmount = 10;
  List<int> _hand = [];
  List<bool> _held = [false, false, false, false, false];
  bool _isFirstDeal = true;
  String _message = "Press DEAL to start";

  @override
  void initState() {
    super.initState();
  }

  Future<void> _deal() async {
    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();

    if (_isFirstDeal) {
      if (provider.balance < _betAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
        );
        return;
      }

      final success = await provider.placeBet(_betAmount);

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
          );
        }
        return;
      }

      setState(() {
        _hand = List.generate(5, (_) => _drawCard());
        _held = [false, false, false, false, false];
        _isFirstDeal = false;
        _message = localization.translate({'en': 'Hold cards and Draw', 'ko': '홀드할 카드를 선택하고 드로우'});
      });
    } else {
      setState(() {
        for (int i = 0; i < 5; i++) {
          if (!_held[i]) {
            _hand[i] = _drawCard();
          }
        }
        _isFirstDeal = true;
      });

      _checkWin();
    }
  }
  
  int _drawCard() => Random().nextInt(13) + 1; // Simplified suits for now

  void _checkWin() {
    final localization = context.read<LocalizationService>();
    Map<int, int> counts = {};
    for (var card in _hand) {
      counts[card] = (counts[card] ?? 0) + 1;
    }

    final countValues = counts.values.toList()..sort((a, b) => b.compareTo(a));

    int winAmount = 0;
    String handName = "";

    if (countValues.length == 1 && countValues[0] == 5) {
      winAmount = _betAmount * 100;
      handName = localization.translate({'en': 'Five of a Kind!', 'ko': '포커드(5장 같은 숫자)!'});
    } else if (countValues.length == 2 && countValues[0] == 4) {
      winAmount = _betAmount * 25;
      handName = localization.translate({'en': 'Four of a Kind!', 'ko': '포카드!'});
    } else if (countValues.length == 2 && countValues[0] == 3) {
      winAmount = _betAmount * 9;
      handName = localization.translate({'en': 'Full House!', 'ko': '풀 하우스!'});
    } else if (countValues[0] == 3) {
      winAmount = _betAmount * 3;
      handName = localization.translate({'en': 'Three of a Kind!', 'ko': '트리플!'});
    } else if (countValues.length >= 2 && countValues[0] == 2 && countValues[1] == 2) {
      winAmount = _betAmount * 2;
      handName = localization.translate({'en': 'Two Pair!', 'ko': '투 페어!'});
    } else if (countValues[0] == 2) {
      final pairCard = counts.entries.firstWhere((e) => e.value == 2).key;
      if (pairCard >= 11 || pairCard == 1) {
        winAmount = _betAmount;
        handName = localization.translate({'en': 'Jacks or Better!', 'ko': '잭 이상 원 페어!'});
      } else {
        handName = localization.translate({'en': 'Pair (too low)', 'ko': '낮은 페어'});
      }
    } else {
      handName = localization.translate({'en': 'No Win', 'ko': '노 윈'});
    }

    if (winAmount > 0) {
      context.read<GameProvider>().winPrize(winAmount);
      setState(() => _message = "${localization.translate(AppStrings.win)} $handName (+$winAmount)");
    } else {
      setState(() => _message = handName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(AppStrings.videoPoker)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            onPressed: () => showHowToPlayDialog(context, AppStrings.videoPokerDescription),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Hand Area
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _hand.isEmpty 
                      ? [Text(tr({'en': 'Press DEAL', 'ko': '딜을 눌러 시작'}) )] 
                      : _hand.asMap().entries.map((entry) {
                          int idx = entry.key;
                          int card = entry.value;
                          return GestureDetector(
                            onTap: _isFirstDeal ? null : () => setState(() => _held[idx] = !_held[idx]),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCard(card),
                                const SizedBox(height: 5),
                                Text(
                                  _held[idx] ? tr({'en': 'HELD', 'ko': '홀드'}) : "",
                                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),
            ),
            
            Text(
              _message == "Press DEAL to start"
                  ? tr({'en': 'Press DEAL to start', 'ko': '딜을 눌러 시작하세요'})
                  : _message,
              style: const TextStyle(fontSize: 20, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            
            // Controls
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF252525),
              child: Column(
                children: [
                  if (_isFirstDeal)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(onPressed: () => setState(() => _betAmount = max(10, _betAmount - 10)), icon: const Icon(Icons.remove)),
                        Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                        IconButton(onPressed: () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                      ],
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _deal,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                      child: Text(
                        _isFirstDeal ? tr({'en': 'DEAL', 'ko': '딜'}) : tr({'en': 'DRAW', 'ko': '드로우'}),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Banner Ad
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(int value) {
    String label = value.toString();
    if (value == 1) label = "A";
    if (value == 11) label = "J";
    if (value == 12) label = "Q";
    if (value == 13) label = "K";
    
    return Container(
      width: 60,
      height: 90,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold))),
    );
  }
}
