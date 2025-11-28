import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

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

  void _deal() {
    final provider = context.read<GameProvider>();
    
    if (_isFirstDeal) {
      // Initial Deal
      if (provider.balance < _betAmount) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
        return;
      }
      provider.spinSlotMachine(_betAmount);
      
      setState(() {
        _hand = List.generate(5, (_) => _drawCard());
        _held = [false, false, false, false, false];
        _isFirstDeal = false;
        _message = "Hold cards and Draw";
      });
    } else {
      // Second Draw
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
    // Very simplified Poker logic (Pairs, Straights, etc. logic omitted for brevity in this MVP step)
    // Just checking for a pair of Jacks or better for demo
    int pairCount = 0;
    bool jacksOrBetter = false;
    
    Map<int, int> counts = {};
    for (var card in _hand) {
      counts[card] = (counts[card] ?? 0) + 1;
    }
    
    counts.forEach((card, count) {
      if (count >= 2) {
        pairCount++;
        if (card >= 11 || card == 1) jacksOrBetter = true;
      }
    });
    
    if (jacksOrBetter) {
      context.read<GameProvider>().winPrize(_betAmount * 2);
      setState(() => _message = "WIN! Jacks or Better");
    } else {
      setState(() => _message = "Game Over");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Video Poker ♠️")),
      body: SafeArea(
        child: Column(
          children: [
            // Hand Area
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _hand.isEmpty 
                      ? [const Text("Press DEAL")] 
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
                                Text(_held[idx] ? "HELD" : "", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ),
            ),
            
            Text(_message, style: const TextStyle(fontSize: 20, color: Colors.amber)),
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
                        Text("Bet: $_betAmount", style: const TextStyle(fontSize: 24)),
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
                      child: Text(_isFirstDeal ? "DEAL" : "DRAW", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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
