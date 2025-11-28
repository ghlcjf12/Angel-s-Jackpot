import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

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

  int? _finalResult;
  String? _finalColor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() async {
    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    setState(() => _isSpinning = true);

    final success = await provider.placeBet(_betAmount);

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
        );
        setState(() => _isSpinning = false);
      }
      return;
    }

    _finalResult = Random().nextInt(37); // 0-36
    _finalColor = "GREEN";
    if (_finalResult != 0) {
      _finalColor = _finalResult! % 2 == 0 ? "RED" : "BLACK";
    }

    final double targetAngle = (_finalResult! * 2 * pi / 37);
    final double totalRotation = 4 * pi + targetAngle;

    final animation = Tween<double>(
      begin: 0,
      end: totalRotation,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      setState(() {
        _angle = animation.value;
      });
    });

    _controller.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _isSpinning = false);
        _checkWin();
      }
    });
  }

  void _checkWin() {
    final localization = context.read<LocalizationService>();
    if (_finalResult == null || _finalColor == null) return;

    bool win = false;
    int multiplier = 0;

    if (_selectedBet == "RED" && _finalColor == "RED") {
      win = true;
      multiplier = 2;
    } else if (_selectedBet == "BLACK" && _finalColor == "BLACK") {
      win = true;
      multiplier = 2;
    } else if (_selectedBet == "NUMBER" && _selectedNumber == _finalResult) {
      win = true;
      multiplier = 35;
    }

    final colorLabel = _colorLabel(_finalColor!, localization);

    if (win) {
      context.read<GameProvider>().winPrize(_betAmount * multiplier);
      _showResultDialog(
        "${localization.translate(AppStrings.win)} $colorLabel $_finalResult",
        localization.translate({'en': 'You won ${_betAmount * multiplier} coins!', 'ko': '${_betAmount * multiplier} 코인 당첨!'}),
      );
    } else {
      _showResultDialog(
        "${localization.translate(AppStrings.lose)} $colorLabel $_finalResult",
        localization.translate({'en': 'Better luck next time.', 'ko': '다음 기회에.'}),
      );
    }

    _finalResult = null;
    _finalColor = null;
  }

  void _showResultDialog(String title, String content) {
    final localization = context.read<LocalizationService>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localization.translate(AppStrings.close)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(AppStrings.roulette)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            onPressed: () => showHowToPlayDialog(context, AppStrings.rouletteDescription),
          ),
        ],
      ),
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
                      image: DecorationImage(image: NetworkImage("https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Roulette_wheel.svg/1200px-Roulette_wheel.svg.png")),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 5),
                        gradient: const SweepGradient(
                          colors: [Colors.red, Colors.black, Colors.red, Colors.black, Colors.green, Colors.red],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          tr({'en': 'SPIN', 'ko': '스핀'}),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
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
                      IconButton(onPressed: _isSpinning ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)), icon: const Icon(Icons.remove)),
                      Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isSpinning ? null : () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Bet Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBetOption(tr({'en': 'RED', 'ko': '레드'}), "RED", Colors.red),
                      _buildBetOption(tr({'en': 'BLACK', 'ko': '블랙'}), "BLACK", Colors.grey[900]!),
                      _buildBetOption(tr({'en': 'NUMBER', 'ko': '숫자'}), "NUMBER", Colors.blue),
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
                      child: Text(
                        tr({'en': 'SPIN', 'ko': '스핀'}),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
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

  Widget _buildBetOption(String label, String key, Color color) {
    bool selected = _selectedBet == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedBet = key),
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

  String _colorLabel(String color, LocalizationService localization) {
    switch (color) {
      case "RED":
        return localization.translate({'en': 'RED', 'ko': '빨강'});
      case "BLACK":
        return localization.translate({'en': 'BLACK', 'ko': '검정'});
      default:
        return localization.translate({'en': 'GREEN', 'ko': '초록'});
    }
  }
}
