import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class SlotsGameScreen extends StatefulWidget {
  const SlotsGameScreen({super.key});

  @override
  State<SlotsGameScreen> createState() => _SlotsGameScreenState();
}

class _SlotsGameScreenState extends State<SlotsGameScreen> {
  final List<String> _symbols = ["🍒", "🍋", "🔔", "🍀", "7️⃣", "💎"];
  List<String> _currentSymbols = ["7️⃣", "7️⃣", "7️⃣"];
  bool _isSpinning = false;
  int _betAmount = 10;

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

    final finalSymbols = _determineResult();

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _currentSymbols = [
          _symbols[Random().nextInt(_symbols.length)],
          _symbols[Random().nextInt(_symbols.length)],
          _symbols[Random().nextInt(_symbols.length)],
        ];
      });
    }

    if (mounted) {
      setState(() {
        _currentSymbols = finalSymbols;
        _isSpinning = false;
      });

      _checkWin();
    }
  }

  List<String> _determineResult() {
    int r = Random().nextInt(1000);

    if (r < 5) {
      return ["7️⃣", "7️⃣", "7️⃣"];
    } else if (r < 15) {
      return ["💎", "💎", "💎"];
    } else if (r < 50) {
      final symbol = _symbols[Random().nextInt(_symbols.length - 2)];
      return [symbol, symbol, symbol];
    } else if (r < 250) {
      final symbol = _symbols[Random().nextInt(_symbols.length)];
      final otherSymbol = _symbols.where((s) => s != symbol).toList()[Random().nextInt(_symbols.length - 1)];
      final positions = [0, 1, 2]..shuffle();
      return [
        positions[0] < 2 ? symbol : otherSymbol,
        positions[1] < 2 ? symbol : otherSymbol,
        positions[2] < 2 ? symbol : otherSymbol,
      ];
    } else {
      List<String> result;
      do {
        result = [
          _symbols[Random().nextInt(_symbols.length)],
          _symbols[Random().nextInt(_symbols.length)],
          _symbols[Random().nextInt(_symbols.length)],
        ];
      } while (result[0] == result[1] || result[1] == result[2] || result[0] == result[2]);
      return result;
    }
  }

  void _checkWin() {
    final localization = context.read<LocalizationService>();
    int winAmount = 0;
    if (_currentSymbols[0] == _currentSymbols[1] && _currentSymbols[1] == _currentSymbols[2]) {
      if (_currentSymbols[0] == "7️⃣") winAmount = _betAmount * 50;
      else if (_currentSymbols[0] == "💎") winAmount = _betAmount * 20;
      else winAmount = _betAmount * 10;
    } else if (_currentSymbols[0] == _currentSymbols[1] || _currentSymbols[1] == _currentSymbols[2] || _currentSymbols[0] == _currentSymbols[2]) {
      winAmount = _betAmount * 2;
    }

    if (winAmount > 0) {
      context.read<GameProvider>().winPrize(winAmount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            localization.translate({'en': 'WIN! +$winAmount coins', 'ko': '당첨! +$winAmount 코인'}),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(localization.translate({'en': 'Better luck next time!', 'ko': '다음 기회에!'})),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(AppStrings.slots)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            onPressed: () => showHowToPlayDialog(context, AppStrings.slotsDescription),
          ),
        ],
      ),
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
                    children: _currentSymbols
                        .map(
                          (s) => Container(
                            width: 80,
                            height: 100,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Center(child: Text(s, style: const TextStyle(fontSize: 50))),
                          ),
                        )
                        .toList(),
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isSpinning ? null : _spin,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      child: Text(
                        tr({'en': 'SPIN', 'ko': '스핀'}),
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
