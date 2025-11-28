import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

class BaccaratGameScreen extends StatefulWidget {
  const BaccaratGameScreen({super.key});

  @override
  State<BaccaratGameScreen> createState() => _BaccaratGameScreenState();
}

class _BaccaratGameScreenState extends State<BaccaratGameScreen> {
  int _betAmount = 10;
  String _selectedBet = "PLAYER"; // PLAYER, BANKER, TIE
  
  List<int> _playerHand = [];
  List<int> _bankerHand = [];
  String _resultMessage = "Place your bet";

  void _deal() async {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount);

    setState(() {
      _playerHand = [_drawCard(), _drawCard()];
      _bankerHand = [_drawCard(), _drawCard()];
    });
    
    // Simple Baccarat Logic (No 3rd card rule for simplicity in this MVP, just compare sums % 10)
    int playerSum = _calculateSum(_playerHand);
    int bankerSum = _calculateSum(_bankerHand);
    
    String winner = "TIE";
    if (playerSum > bankerSum) winner = "PLAYER";
    if (bankerSum > playerSum) winner = "BANKER";
    
    bool win = false;
    double multiplier = 0;
    
    if (_selectedBet == winner) {
      win = true;
      if (winner == "TIE") multiplier = 8;
      else multiplier = 2; // 1:1 payout usually (minus commission for banker but ignoring for now)
    }
    
    setState(() {
      _resultMessage = "$winner WINS! (P:$playerSum vs B:$bankerSum)";
    });
    
    if (win) {
      provider.winPrize((_betAmount * multiplier).toInt());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("WIN!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("LOSE!")));
    }
  }
  
  int _drawCard() => Random().nextInt(13) + 1;
  
  int _calculateSum(List<int> hand) {
    int sum = 0;
    for (var card in hand) {
      if (card >= 10) {
        // Face cards = 0
      } else {
        sum += card;
      }
    }
    return sum % 10;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Baccarat 🎴")),
      body: SafeArea(
        child: Column(
          children: [
            // Game Area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildHand("BANKER", _bankerHand),
                  Text(_resultMessage, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                  _buildHand("PLAYER", _playerHand),
                ],
              ),
            ),
            
            // Controls
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF252525),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: () => setState(() => _betAmount = max(10, _betAmount - 10)), icon: const Icon(Icons.remove)),
                      Text("Bet: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildBetOption("PLAYER", Colors.blue),
                      const SizedBox(width: 10),
                      _buildBetOption("TIE", Colors.green),
                      const SizedBox(width: 10),
                      _buildBetOption("BANKER", Colors.red),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _deal,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                      child: const Text("DEAL", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildBetOption(String label, Color color) {
    bool selected = _selectedBet == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedBet = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: color.withOpacity(selected ? 1.0 : 0.3),
            border: selected ? Border.all(color: Colors.white, width: 2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildHand(String label, List<int> hand) {
    return Column(
      children: [
        Text("$label (${_calculateSum(hand)})", style: const TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: hand.isEmpty 
              ? [const SizedBox(height: 90)] 
              : hand.map((c) => _buildCard(c)).toList(),
        ),
      ],
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
