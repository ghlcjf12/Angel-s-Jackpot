import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

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
    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    setState(() => _isRolling = true);

    final success = await provider.placeBet(_betAmount);

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
        );
        setState(() => _isRolling = false);
      }
      return;
    }

    final finalResult = Random().nextInt(6) + 1;

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _result = Random().nextInt(6) + 1);
    }

    if (mounted) {
      setState(() {
        _result = finalResult;
        _isRolling = false;
      });

      if (_result == _selectedNumber) {
        provider.winPrize(_betAmount * 6);
        _showResult(localization.translate({'en': 'WIN! +${_betAmount * 6} coins', 'ko': '당첨! +${_betAmount * 6} 코인'}), Colors.green);
      } else {
        _showResult(localization.translate({'en': 'LOSE - Better luck next time!', 'ko': '패배 - 다음 기회에!'}), Colors.red);
      }
    }
  }

  void _showResult(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: color, content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(AppStrings.dice)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            onPressed: () => showHowToPlayDialog(context, AppStrings.diceDescription),
          ),
        ],
      ),
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
                    Text(tr({'en': 'Predict the number (Payout 6x)', 'ko': '숫자를 맞추세요 (6배 배당)'}), style: const TextStyle(color: Colors.grey)),
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
                      Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isRolling ? null : () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                      child: Text(
                        tr({'en': 'ROLL DICE', 'ko': '주사위 굴리기'}),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
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
}
