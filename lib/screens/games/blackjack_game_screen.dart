import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class BlackjackGameScreen extends StatefulWidget {
  const BlackjackGameScreen({super.key});

  @override
  State<BlackjackGameScreen> createState() => _BlackjackGameScreenState();
}

class _BlackjackGameScreenState extends State<BlackjackGameScreen> {
  int _betAmount = 10;
  bool _isPlaying = false;
  bool _isStand = false;
  
  List<int> _playerHand = [];
  List<int> _dealerHand = [];
  
  String _message = "Place your bet";

  void _startGame() async {
    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    final success = await provider.placeBet(_betAmount);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
      );
      return;
    }

    setState(() {
      _isPlaying = true;
      _isStand = false;
      _message = localization.translate({'en': 'Hit or Stand?', 'ko': '히트 또는 스탠드?'});
      _playerHand = [_drawCard(), _drawCard()];
      _dealerHand = [_drawCard(), _drawCard()];
    });
    
    if (_calculateScore(_playerHand) == 21) {
      _stand(); // Blackjack!
    }
  }

  int _drawCard() {
    return Random().nextInt(13) + 1;
  }

  int _calculateScore(List<int> hand) {
    int score = 0;
    int aces = 0;
    for (var card in hand) {
      if (card == 1) {
        aces++;
        score += 11;
      } else if (card >= 10) {
        score += 10;
      } else {
        score += card;
      }
    }
    while (score > 21 && aces > 0) {
      score -= 10;
      aces--;
    }
    return score;
  }

  void _hit() {
    setState(() {
      _playerHand.add(_drawCard());
    });
    if (_calculateScore(_playerHand) > 21) {
      _endGame(false); // Bust
    }
  }

  void _stand() async {
    setState(() {
      _isStand = true;
    });
    
    while (_calculateScore(_dealerHand) < 17) {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _dealerHand.add(_drawCard());
      });
    }
    
    int playerScore = _calculateScore(_playerHand);
    int dealerScore = _calculateScore(_dealerHand);
    
    if (dealerScore > 21 || playerScore > dealerScore) {
      _endGame(true);
    } else if (playerScore == dealerScore) {
      _endGame(null); // Push
    } else {
      _endGame(false);
    }
  }

  void _endGame(bool? win) {
    final localization = context.read<LocalizationService>();
    setState(() {
      _isPlaying = false;
    });
    
    if (win == true) {
      _message = localization.translate({'en': 'YOU WIN!', 'ko': '승리!'});
      context.read<GameProvider>().winPrize(_betAmount * 2);
    } else if (win == false) {
      _message = localization.translate({'en': 'YOU LOSE!', 'ko': '패배!'});
    } else {
      _message = localization.translate({'en': 'PUSH (Tie)', 'ko': '무승부 (푸시)'});
      context.read<GameProvider>().winPrize(_betAmount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(AppStrings.blackjack)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            onPressed: () => showHowToPlayDialog(context, AppStrings.blackjackDescription),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dealer Area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("${tr({'en': 'Dealer', 'ko': '딜러'})}: ${_isStand ? _calculateScore(_dealerHand) : "?"}", style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _dealerHand.asMap().entries.map((entry) {
                      int idx = entry.key;
                      int card = entry.value;
                      if (!_isStand && idx == 1) return _buildCardBack();
                      return _buildCard(card);
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            // Message
            Text(
              _message == "Place your bet" ? tr({'en': 'Place your bet', 'ko': '베팅하세요'}) : _message,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            
            // Player Area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("${tr({'en': 'You', 'ko': '플레이어'})}: ${_calculateScore(_playerHand)}", style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _playerHand.map((c) => _buildCard(c)).toList(),
                  ),
                ],
              ),
            ),
            
            // Controls
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF252525),
              child: Column(
                children: [
                  if (!_isPlaying)
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
                    child: _isPlaying
                        ? Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _hit,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: Text(tr({'en': 'HIT', 'ko': '히트'})),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _stand,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: Text(tr({'en': 'STAND', 'ko': '스탠드'})),
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            child: Text(
                              tr({'en': 'DEAL', 'ko': '딜'}),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
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

  Widget _buildCardBack() {
    return Container(
      width: 60,
      height: 90,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.red.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
