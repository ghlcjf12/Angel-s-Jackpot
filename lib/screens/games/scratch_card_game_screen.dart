import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scratcher/scratcher.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

class ScratchCardGameScreen extends StatefulWidget {
  const ScratchCardGameScreen({super.key});

  @override
  State<ScratchCardGameScreen> createState() => _ScratchCardGameScreenState();
}

class _ScratchCardGameScreenState extends State<ScratchCardGameScreen> {
  int _betAmount = 20;
  int _prize = 0;
  bool _isScratched = false;
  final GlobalKey<ScratcherState> _scratcherKey = GlobalKey<ScratcherState>();

  void _buyTicket() {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount);

    setState(() {
      _isScratched = false;
      // Determine prize
      int r = Random().nextInt(100);
      if (r < 50) _prize = 0; // 50% lose
      else if (r < 80) _prize = _betAmount; // 30% money back
      else if (r < 95) _prize = _betAmount * 2; // 15% double
      else _prize = _betAmount * 10; // 5% jackpot
    });
    
    _scratcherKey.currentState?.reset(duration: const Duration(milliseconds: 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scratch Card 🎫")),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Scratch to Win!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Scratcher(
                      key: _scratcherKey,
                      brushSize: 50,
                      threshold: 50,
                      color: Colors.grey,
                      onThreshold: () {
                        if (!_isScratched) {
                          setState(() => _isScratched = true);
                          if (_prize > 0) {
                            context.read<GameProvider>().winPrize(_prize);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, content: Text("WON $_prize COINS!")));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Better luck next time!")));
                          }
                        }
                      },
                      child: Container(
                        width: 300,
                        height: 200,
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_prize > 0 ? "WINNER!" : "TRY AGAIN", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _prize > 0 ? Colors.green : Colors.red)),
                              if (_prize > 0) Text("+$_prize", style: const TextStyle(fontSize: 24, color: Colors.black)),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                  Text("Ticket Price: $_betAmount", style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _buyTicket,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                      child: const Text("BUY TICKET", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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
