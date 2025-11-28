import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

class HighLowGameScreen extends StatefulWidget {
  const HighLowGameScreen({super.key});

  @override
  State<HighLowGameScreen> createState() => _HighLowGameScreenState();
}

class _HighLowGameScreenState extends State<HighLowGameScreen> {
  int _currentCard = 1;
  int _betAmount = 10;
  bool _isPlaying = false;
  String _message = "Will the next card be Higher or Lower?";

  @override
  void initState() {
    super.initState();
    _currentCard = Random().nextInt(13) + 1;
  }

  void _guess(bool higher) {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount); // Deduct bet

    int nextCard = Random().nextInt(13) + 1;
    bool win = false;

    if (higher && nextCard > _currentCard) win = true;
    if (!higher && nextCard < _currentCard) win = true;
    if (nextCard == _currentCard) win = false; // Tie loses for simplicity

    setState(() {
      _currentCard = nextCard;
      if (win) {
        _message = "WIN! Card was $nextCard";
        provider.winPrize(_betAmount * 2);
      } else {
        _message = "LOSE! Card was $nextCard";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("High-Low ⬆️⬇️")),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Current Card", style: TextStyle(fontSize: 20, color: Colors.grey)),
                    const SizedBox(height: 10),
                    _buildCard(_currentCard),
                    const SizedBox(height: 30),
                    Text(_message, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
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
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _guess(true),
                          icon: const Icon(Icons.arrow_upward),
                          label: const Text("HIGHER"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _guess(false),
                          icon: const Icon(Icons.arrow_downward),
                          label: const Text("LOWER"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(20)),
                        ),
                      ),
                    ],
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
      width: 120,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Center(child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 60, fontWeight: FontWeight.bold))),
    );
  }
}
