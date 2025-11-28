import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

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

  void _startGame() {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount); // Deduct bet

    setState(() {
      _isPlaying = true;
      _isStand = false;
      _message = "Hit or Stand?";
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
    
    // Dealer AI
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
    setState(() {
      _isPlaying = false;
    });
    
    if (win == true) {
      _message = "YOU WIN!";
      context.read<GameProvider>().winPrize(_betAmount * 2);
    } else if (win == false) {
      _message = "YOU LOSE!";
    } else {
      _message = "PUSH (Tie)";
      context.read<GameProvider>().winPrize(_betAmount); // Refund
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blackjack 🃏")),
      body: SafeArea(
        child: Column(
          children: [
            // Dealer Area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Dealer: ${_isStand ? _calculateScore(_dealerHand) : "?"}", style: const TextStyle(fontSize: 20)),
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
            Text(_message, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
            
            // Player Area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("You: ${_calculateScore(_playerHand)}", style: const TextStyle(fontSize: 20)),
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
                        Text("Bet: $_betAmount", style: const TextStyle(fontSize: 24)),
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
                              Expanded(child: ElevatedButton(onPressed: _hit, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("HIT"))),
                              const SizedBox(width: 20),
                              Expanded(child: ElevatedButton(onPressed: _stand, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("STAND"))),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            child: const Text("DEAL", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
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
