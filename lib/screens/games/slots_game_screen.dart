import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

class SlotsGameScreen extends StatefulWidget {
  const SlotsGameScreen({super.key});

  @override
  State<SlotsGameScreen> createState() => _SlotsGameScreenState();
}

class _SlotsGameScreenState extends State<SlotsGameScreen> {
  final List<String> _symbols = ["🍒", "🍋", "🍇", "💎", "7️⃣", "🔔"];
  List<String> _currentSymbols = ["7️⃣", "7️⃣", "7️⃣"];
  bool _isSpinning = false;
  int _betAmount = 10;

  void _spin() async {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount); // Deduct bet

    setState(() {
      _isSpinning = true;
    });

    // Animation effect
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _currentSymbols = [
          _symbols[Random().nextInt(_symbols.length)],
          _symbols[Random().nextInt(_symbols.length)],
          _symbols[Random().nextInt(_symbols.length)],
        ];
      });
    }

    setState(() {
      _isSpinning = false;
    });

    _checkWin();
  }

  void _checkWin() {
    int winAmount = 0;
    if (_currentSymbols[0] == _currentSymbols[1] && _currentSymbols[1] == _currentSymbols[2]) {
      // Jackpot
      if (_currentSymbols[0] == "7️⃣") winAmount = _betAmount * 50;
      else if (_currentSymbols[0] == "💎") winAmount = _betAmount * 20;
      else winAmount = _betAmount * 10;
    } else if (_currentSymbols[0] == _currentSymbols[1] || _currentSymbols[1] == _currentSymbols[2] || _currentSymbols[0] == _currentSymbols[2]) {
      // Small win (2 match)
      winAmount = _betAmount * 2;
    }

    if (winAmount > 0) {
      context.read<GameProvider>().winPrize(winAmount);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("WIN! +$winAmount coins")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Slots 🎰")),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Slot Machine Display
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade900, width: 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _currentSymbols.map((s) => Container(
                      width: 80,
                      height: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Center(child: Text(s, style: const TextStyle(fontSize: 50))),
                    )).toList(),
                  ),
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
                      IconButton(onPressed: _isSpinning ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)), icon: const Icon(Icons.remove)),
                      Text("Bet: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isSpinning ? null : () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isSpinning ? null : _spin,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      child: const Text("SPIN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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
}
