import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

class RouletteGameScreen extends StatefulWidget {
  const RouletteGameScreen({super.key});

  @override
  State<RouletteGameScreen> createState() => _RouletteGameScreenState();
}

class _RouletteGameScreenState extends State<RouletteGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _betAmount = 10;
  bool _isSpinning = false;
  double _angle = 0;
  String _selectedBet = "RED"; // RED, BLACK, NUMBER
  int _selectedNumber = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _controller.addListener(() {
      setState(() {
        _angle = _controller.value * 4 * pi + (_controller.value * 2 * pi); // Spin multiple times
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount); // Deduct bet

    setState(() {
      _isSpinning = true;
    });
    
    _controller.forward(from: 0).then((_) {
      setState(() {
        _isSpinning = false;
      });
      _checkWin();
    });
  }

  void _checkWin() {
    final r = Random();
    int result = r.nextInt(37); // 0-36
    
    // Determine color (Simplified: Even=Red, Odd=Black, 0=Green)
    String color = "GREEN";
    if (result != 0) {
      color = result % 2 == 0 ? "RED" : "BLACK";
    }
    
    bool win = false;
    int multiplier = 0;
    
    if (_selectedBet == "RED" && color == "RED") {
      win = true;
      multiplier = 2;
    } else if (_selectedBet == "BLACK" && color == "BLACK") {
      win = true;
      multiplier = 2;
    } else if (_selectedBet == "NUMBER" && _selectedNumber == result) {
      win = true;
      multiplier = 35;
    }
    
    if (win) {
      context.read<GameProvider>().winPrize(_betAmount * multiplier);
      _showResultDialog("WIN! $color $result", "You won ${_betAmount * multiplier} coins!");
    } else {
      _showResultDialog("LOSE! $color $result", "Better luck next time.");
    }
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Roulette 🎡")),
      body: SafeArea(
        child: Column(
          children: [
            // Wheel Area
            Expanded(
              child: Center(
                child: Transform.rotate(
                  angle: _angle,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(image: NetworkImage("https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Roulette_wheel.svg/1200px-Roulette_wheel.svg.png")), // Placeholder or asset
                    ),
                    // Fallback if image fails or for simplicity
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 5),
                        gradient: const SweepGradient(
                          colors: [Colors.red, Colors.black, Colors.red, Colors.black, Colors.green, Colors.red],
                        ),
                      ),
                      child: const Center(child: Text("SPIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ),
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
                  const SizedBox(height: 10),
                  // Bet Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBetOption("RED", Colors.red),
                      _buildBetOption("BLACK", Colors.grey[900]!),
                      _buildBetOption("NUMBER", Colors.blue),
                    ],
                  ),
                  if (_selectedBet == "NUMBER")
                    Slider(
                      value: _selectedNumber.toDouble(),
                      min: 0,
                      max: 36,
                      divisions: 36,
                      label: _selectedNumber.toString(),
                      onChanged: (v) => setState(() => _selectedNumber = v.toInt()),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isSpinning ? null : _spin,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      child: const Text("SPIN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
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
    return GestureDetector(
      onTap: () => setState(() => _selectedBet = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          border: selected ? Border.all(color: Colors.white, width: 3) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
