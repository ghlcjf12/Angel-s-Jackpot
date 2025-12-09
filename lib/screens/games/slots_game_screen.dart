import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class SlotsGameScreen extends StatefulWidget {
  const SlotsGameScreen({super.key});

  @override
  State<SlotsGameScreen> createState() => _SlotsGameScreenState();
}

class _SlotsGameScreenState extends State<SlotsGameScreen> with TickerProviderStateMixin {
  final List<String> _symbols = ["🍒", "🍋", "🔔", "🍀", "7️⃣", "💎"];
  List<String> _currentSymbols = ["7️⃣", "7️⃣", "7️⃣"];
  bool _isSpinning = false;
  int _betAmount = 10;
  String _resultMessage = "";
  int _lastWin = 0;

  late List<AnimationController> _reelControllers;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().playGameBgm();
    });
    _reelControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: Duration(milliseconds: 1500 + index * 300),
        vsync: this,
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _reelControllers) {
      controller.dispose();
    }
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

    setState(() {
      _isSpinning = true;
      _resultMessage = "";
      _lastWin = 0;
    });

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

    if (mounted) {
      context.read<AudioService>().playButtonSound();
    }

    final finalSymbols = _determineResult();

    // Start all reel animations
    for (var controller in _reelControllers) {
      controller.reset();
      controller.forward();
    }

    // Animate each reel and wait for all to complete
    await Future.wait([
      for (int i = 0; i < 3; i++) _animateReel(i, finalSymbols[i]),
    ]);

    if (mounted) {
      setState(() {
        _currentSymbols = finalSymbols;
        _isSpinning = false;
      });

      _checkWin();
    }
  }

  Future<void> _animateReel(int reelIndex, String finalSymbol) async {
    final random = Random();
    int iterations = 15 + reelIndex * 5;

    for (int i = 0; i < iterations; i++) {
      await Future.delayed(Duration(milliseconds: 50 + (i * 5)));
      if (!mounted) return;
      if (i < iterations - 1) {
        setState(() {
          _currentSymbols[reelIndex] = _symbols[random.nextInt(_symbols.length)];
        });
      } else {
        setState(() {
          _currentSymbols[reelIndex] = finalSymbol;
        });
      }
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
    String message = "";

    if (_currentSymbols[0] == _currentSymbols[1] && _currentSymbols[1] == _currentSymbols[2]) {
      if (_currentSymbols[0] == "7️⃣") {
        winAmount = _betAmount * 50;
        message = localization.translate({'en': '🎉 JACKPOT! 7-7-7!', 'ko': '🎉 잭팟! 7-7-7!'});
      } else if (_currentSymbols[0] == "💎") {
        winAmount = _betAmount * 20;
        message = localization.translate({'en': '💎 DIAMOND WIN!', 'ko': '💎 다이아몬드 당첨!'});
      } else {
        winAmount = _betAmount * 10;
        message = localization.translate({'en': '🎊 THREE OF A KIND!', 'ko': '🎊 트리플 당첨!'});
      }
    } else if (_currentSymbols[0] == _currentSymbols[1] ||
        _currentSymbols[1] == _currentSymbols[2] ||
        _currentSymbols[0] == _currentSymbols[2]) {
      winAmount = _betAmount * 2;
      message = localization.translate({'en': '✨ PAIR!', 'ko': '✨ 페어!'});
    }

    setState(() {
      _lastWin = winAmount;
      _resultMessage = message;
    });

    if (winAmount > 0) {
      context.read<GameProvider>().winPrize(winAmount);
      context.read<AudioService>().playWinSound();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            localization.translate({'en': 'WIN! +$winAmount coins', 'ko': '당첨! +$winAmount 코인'}),
          ),
        ),
      );
    } else {
      context.read<AudioService>().playFailSound();
      setState(() {
        _resultMessage = localization.translate({'en': 'Try again!', 'ko': '다시 도전!'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<AudioService>().playLobbyBgm();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(AppStrings.slots)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.read<AudioService>().playLobbyBgm();
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.amber),
              onPressed: () => showHowToPlayDialog(context, AppStrings.slotsDescription),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Pay table
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildPayItem('7️⃣7️⃣7️⃣', '50x'),
                      _buildPayItem('💎💎💎', '20x'),
                    _buildPayItem('3 같은', '10x'),
                    _buildPayItem('2 같은', '2x'),
                  ],
                ),
              ),
            ),

            // Slot Machine Display
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 가용 공간에 맞춰 전체 비율 유지하면서 축소
                  final availableHeight = constraints.maxHeight;
                  final scale = (availableHeight / 350).clamp(0.5, 1.0);
                  
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Result message
                          AnimatedOpacity(
                            opacity: _resultMessage.isNotEmpty ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 24 * scale, vertical: 12 * scale),
                              margin: EdgeInsets.only(bottom: 20 * scale),
                              decoration: BoxDecoration(
                                color: _lastWin > 0 ? Colors.green.shade800 : Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _resultMessage,
                                style: TextStyle(
                                  fontSize: 18 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          // Slot machine
                          Container(
                            padding: EdgeInsets.all(16 * scale),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.amber.shade700,
                                  Colors.amber.shade500,
                                  Colors.amber.shade700,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24 * scale),
                              border: Border.all(color: Colors.amber.shade900, width: 6 * scale),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withAlpha(100),
                                  blurRadius: 20 * scale,
                                  spreadRadius: 2 * scale,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Title
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 4 * scale),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade800,
                                    borderRadius: BorderRadius.circular(8 * scale),
                                  ),
                                  child: Text(
                                    tr({'en': "LUCKY SLOTS", 'ko': "럭키 슬롯"}),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16 * scale,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12 * scale),
                                // Reels
                                Container(
                                  padding: EdgeInsets.all(8 * scale),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(12 * scale),
                                    border: Border.all(color: Colors.amber.shade800, width: 3 * scale),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(3, (index) {
                                      return Container(
                                        width: 80 * scale,
                                        height: 100 * scale,
                                        margin: EdgeInsets.symmetric(horizontal: 4 * scale),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.grey.shade300,
                                              Colors.white,
                                              Colors.grey.shade300,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(8 * scale),
                                          border: Border.all(color: Colors.grey.shade600, width: 2 * scale),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4 * scale,
                                              offset: Offset(0, 2 * scale),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 100),
                                            child: Text(
                                              _currentSymbols[index],
                                              key: ValueKey(_currentSymbols[index] + index.toString()),
                                              style: TextStyle(fontSize: 48 * scale),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Win amount display
                          if (_lastWin > 0)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: EdgeInsets.only(top: 20 * scale),
                              padding: EdgeInsets.symmetric(horizontal: 32 * scale, vertical: 12 * scale),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(20 * scale),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withAlpha(150),
                                    blurRadius: 10 * scale,
                                    spreadRadius: 2 * scale,
                                  ),
                                ],
                              ),
                              child: Text(
                                "+$_lastWin",
                                style: TextStyle(
                                  fontSize: 28 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
                        onPressed: _isSpinning
                            ? null
                            : () => setState(() => _betAmount = max(10, _betAmount - 10)),
                        icon: const Icon(Icons.remove),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${tr(AppStrings.bet)}: $_betAmount",
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSpinning ? null : () => setState(() => _betAmount += 10),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isSpinning ? null : _spin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSpinning)
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
                            _isSpinning
                                ? tr({'en': 'SPINNING...', 'ko': '스핀 중...'})
                                : tr({'en': 'SPIN', 'ko': '스핀'}),
                            style: const TextStyle(
                              fontSize: 24,
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
      ),
    );
  }

  Widget _buildPayItem(String symbols, String payout) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(symbols, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            payout,
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
