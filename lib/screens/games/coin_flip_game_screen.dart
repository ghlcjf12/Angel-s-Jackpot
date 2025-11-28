import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

class CoinFlipGameScreen extends StatefulWidget {
  const CoinFlipGameScreen({super.key});

  @override
  State<CoinFlipGameScreen> createState() => _CoinFlipGameScreenState();
}

class _CoinFlipGameScreenState extends State<CoinFlipGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _betAmount = 10;
  bool _isFlipping = false;
  bool _isHeads = true;
  String _selectedSide = "HEADS";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount);

    setState(() => _isFlipping = true);
    _controller.forward(from: 0).then((_) {
      setState(() {
        _isFlipping = false;
        _isHeads = Random().nextBool();
      });
      
      bool win = (_selectedSide == "HEADS" && _isHeads) || (_selectedSide == "TAILS" && !_isHeads);
      
      if (win) {
        provider.winPrize(_betAmount * 2);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("WIN!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("LOSE!")));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Coin Flip 🪙")),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: RotationTransition(
                  turns: _controller,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 20)],
                    ),
                    child: Center(
                      child: Text(
                        _isFlipping ? "?" : (_isHeads ? "H" : "T"),
                        style: const TextStyle(fontSize: 100, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
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
                      IconButton(onPressed: _isFlipping ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)), icon: const Icon(Icons.remove)),
                      Text("Bet: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isFlipping ? null : () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSide = "HEADS"),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: _selectedSide == "HEADS" ? Colors.amber : Colors.grey[800],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(child: Text("HEADS", style: TextStyle(fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedSide = "TAILS"),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: _selectedSide == "TAILS" ? Colors.amber : Colors.grey[800],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(child: Text("TAILS", style: TextStyle(fontWeight: FontWeight.bold))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isFlipping ? null : _flip,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
                      child: const Text("FLIP COIN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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
