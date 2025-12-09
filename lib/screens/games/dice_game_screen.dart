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

class _DiceGameScreenState extends State<DiceGameScreen> with SingleTickerProviderStateMixin {
  int _betAmount = 10;
  int _selectedNumber = 3;
  int _result = 1;
  bool _isRolling = false;
  String _resultMessage = "";
  bool _lastWin = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // Dice face patterns (positions of dots)
  List<Offset> _getDiceDots(int value) {
    const double s = 0.25; // small offset
    const double c = 0.5; // center
    const double l = 0.75; // large offset

    switch (value) {
      case 1:
        return [const Offset(c, c)];
      case 2:
        return [const Offset(s, s), const Offset(l, l)];
      case 3:
        return [const Offset(s, s), const Offset(c, c), const Offset(l, l)];
      case 4:
        return [const Offset(s, s), const Offset(l, s), const Offset(s, l), const Offset(l, l)];
      case 5:
        return [
          const Offset(s, s),
          const Offset(l, s),
          const Offset(c, c),
          const Offset(s, l),
          const Offset(l, l)
        ];
      case 6:
        return [
          const Offset(s, s),
          const Offset(l, s),
          const Offset(s, c),
          const Offset(l, c),
          const Offset(s, l),
          const Offset(l, l)
        ];
      default:
        return [];
    }
  }

  void _roll() async {
    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();

    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    setState(() {
      _isRolling = true;
      _resultMessage = "";
    });

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

    // Shake animation
    _shakeController.forward(from: 0);

    // Rolling animation
    for (int i = 0; i < 15; i++) {
      await Future.delayed(Duration(milliseconds: 50 + i * 10));
      if (!mounted) return;
      setState(() => _result = Random().nextInt(6) + 1);
    }

    if (mounted) {
      setState(() {
        _result = finalResult;
        _isRolling = false;
        _lastWin = _result == _selectedNumber;
      });

      if (_lastWin) {
        provider.winPrize(_betAmount * 6);
        setState(() {
          _resultMessage = localization.translate({'en': '🎉 WIN! +${_betAmount * 6}', 'ko': '🎉 당첨! +${_betAmount * 6}'});
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(localization.translate({'en': 'WIN! +${_betAmount * 6} coins', 'ko': '당첨! +${_betAmount * 6} 코인'})),
          ),
        );
      } else {
        setState(() {
          _resultMessage = localization.translate({'en': 'Try again!', 'ko': '다시 도전!'});
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(localization.translate({'en': 'Better luck next time!', 'ko': '다음 기회에!'})),
          ),
        );
      }
    }
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
            // Payout info
            Container(
              padding: const EdgeInsets.all(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade900,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tr({'en': '🎲 Guess correct = 6x payout!', 'ko': '🎲 정답 시 6배 배당!'}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Result message
                    AnimatedOpacity(
                      opacity: _resultMessage.isNotEmpty ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: _lastWin ? Colors.green.shade800 : Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _resultMessage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Dice
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            sin(_shakeAnimation.value * pi * 8) * 10 * (1 - _shakeAnimation.value),
                            0,
                          ),
                          child: Transform.rotate(
                            angle: _isRolling ? sin(_shakeAnimation.value * pi * 4) * 0.3 : 0,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _lastWin && !_isRolling
                                  ? Colors.green.withAlpha(150)
                                  : Colors.black38,
                              blurRadius: _lastWin && !_isRolling ? 20 : 15,
                              spreadRadius: _lastWin && !_isRolling ? 5 : 2,
                            ),
                          ],
                          border: Border.all(
                            color: _lastWin && !_isRolling ? Colors.green : Colors.grey.shade400,
                            width: 3,
                          ),
                        ),
                        child: Stack(
                          children: _getDiceDots(_result).map((offset) {
                            return Positioned(
                              left: offset.dx * 140 - 12,
                              top: offset.dy * 140 - 12,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Selected number indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: Text(
                        "${tr({'en': 'Your pick', 'ko': '선택'})}:  $_selectedNumber",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _isRolling ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)),
                        icon: const Icon(Icons.remove),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                      ),
                      IconButton(
                        onPressed: _isRolling ? null : () => setState(() => _betAmount += 10),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Number selection with dice faces
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      int num = index + 1;
                      bool isSelected = _selectedNumber == num;
                      return GestureDetector(
                        onTap: _isRolling ? null : () => setState(() => _selectedNumber = num),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.amber : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.amber.shade700 : Colors.grey.shade600,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.amber.withAlpha(100), blurRadius: 8)]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              "$num",
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isRolling ? null : _roll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isRolling)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          else
                            const Icon(Icons.casino, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            _isRolling
                                ? tr({'en': 'ROLLING...', 'ko': '굴리는 중...'})
                                : tr({'en': 'ROLL DICE', 'ko': '주사위 굴리기'}),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
