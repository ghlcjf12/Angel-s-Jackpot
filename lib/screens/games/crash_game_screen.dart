import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/banner_ad_widget.dart';

class CrashGameScreen extends StatefulWidget {
  const CrashGameScreen({super.key});

  @override
  State<CrashGameScreen> createState() => _CrashGameScreenState();
}

class _CrashGameScreenState extends State<CrashGameScreen> {
  // Game State
  bool _isPlaying = false;
  bool _crashed = false;
  bool _cashedOut = false;
  double _multiplier = 1.0;
  double _crashPoint = 0.0;
  int _betAmount = 10;
  
  // Timer
  Timer? _timer;
  final List<FlSpot> _spots = [const FlSpot(0, 1.0)];
  double _time = 0.0;

  void _startGame() {
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient funds!")));
      return;
    }

    provider.spinSlotMachine(_betAmount); // Deduct bet

    setState(() {
      _isPlaying = true;
      _crashed = false;
      _cashedOut = false;
      _multiplier = 1.0;
      _time = 0.0;
      _spots.clear();
      _spots.add(const FlSpot(0, 1.0));
      
      // Determine crash point (Weighted random)
      // Simple algorithm: 1 / (1-random) but capped or adjusted for house edge
      // E.g. 1% instant crash at 1.0
      final r = Random().nextDouble();
      _crashPoint = 1.0 / (1.0 - r) * 0.96; // 4% House edge roughly
      if (_crashPoint < 1.0) _crashPoint = 1.0;
      // Cap at 100x for sanity in this demo
      if (_crashPoint > 100.0) _crashPoint = 100.0;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _time += 0.1;
        // Exponential growth formula: 1.0 * e^(0.06 * t)
        _multiplier = pow(1.06, _time * 10).toDouble();
        
        _spots.add(FlSpot(_time, _multiplier));

        if (_multiplier >= _crashPoint) {
          _crash();
        }
      });
    });
  }

  void _crash() {
    _timer?.cancel();
    setState(() {
      _crashed = true;
      _isPlaying = false;
    });
  }

  void _cashOut() {
    if (_cashedOut || _crashed) return;
    
    _timer?.cancel();
    final winAmount = (_betAmount * _multiplier).floor();
    context.read<GameProvider>().winPrize(winAmount);
    
    setState(() {
      _cashedOut = true;
      _isPlaying = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Cashed out at ${_multiplier.toStringAsFixed(2)}x! Won $winAmount coins!")),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crash 🚀")),
      body: SafeArea(
        child: Column(
          children: [
            // Graph Area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: _time + 2,
                    minY: 1,
                    maxY: _multiplier * 1.2,
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _spots,
                        isCurved: true,
                        color: _crashed ? Colors.red : Colors.greenAccent,
                        barWidth: 4,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: (_crashed ? Colors.red : Colors.greenAccent).withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Multiplier Display
            Text(
              _crashed ? "CRASHED @ ${_multiplier.toStringAsFixed(2)}x" : "${_multiplier.toStringAsFixed(2)}x",
              style: TextStyle(
                fontSize: 48, 
                fontWeight: FontWeight.bold,
                color: _crashed ? Colors.red : (_cashedOut ? Colors.amber : Colors.white),
              ),
            ),
            
            const SizedBox(height: 20),

            // Controls
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF252525),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: _isPlaying ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)), icon: const Icon(Icons.remove)),
                      Text("Bet: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isPlaying ? null : () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: _isPlaying
                        ? ElevatedButton(
                            onPressed: _cashedOut ? null : _cashOut,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("CASH OUT", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          )
                        : ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            child: const Text("PLACE BET", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
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
