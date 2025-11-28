import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

class DiceGameScreen extends StatefulWidget {
  const DiceGameScreen({super.key});

  @override
  State<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends State<DiceGameScreen> {
  int _betAmount = 10;
  int _selectedNumber = 3; // 1-6
  int _result = 1;
  bool _isRolling = false;

  void _roll() async {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount);

    setState(() => _isRolling = true);
    
    // Animation
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() => _result = Random().nextInt(6) + 1);
    }

    setState(() => _isRolling = false);

    if (_result == _selectedNumber) {
      provider.winPrize(_betAmount * 5); // 1/6 chance, 5x payout
      _showResult("WIN!", Colors.green);
    } else {
      _showResult("LOSE", Colors.red);
    }
  }

  void _showResult(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: color, content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dice 🎲")),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: Center(
                        child: Text(
                          "$_result",
                          style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text("Predict the number (Payout 5x)", style: TextStyle(color: Colors.grey)),
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
                      IconButton(onPressed: _isRolling ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)), icon: const Icon(Icons.remove)),
                      Text("Bet: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isRolling ? null : () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Number Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      int num = index + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedNumber = num),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _selectedNumber == num ? Colors.amber : Colors.grey[800],
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text("$num", style: TextStyle(color: _selectedNumber == num ? Colors.black : Colors.white, fontWeight: FontWeight.bold))),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isRolling ? null : _roll,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      child: const Text("ROLL DICE", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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
