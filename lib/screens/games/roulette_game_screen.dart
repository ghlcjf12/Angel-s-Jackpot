import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

// Roulette wheel numbers in order (European)
const List<int> _wheelNumbers = [
  0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
  5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26
];

// Red numbers on roulette wheel
const Set<int> _redNumbers = {
  1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36
};

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().playGameBgm();
    });
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
      _finalColor = _redNumbers.contains(_finalResult) ? "RED" : "BLACK";
    }

    // Find the index of the result number in the wheel
    final int resultIndex = _wheelNumbers.indexOf(_finalResult!);
    // Calculate angle so that the result aligns with the top pointer
    // Each segment is 2*pi/37, and we need to rotate so that the target segment is at the top
    final double segmentAngle = 2 * pi / 37;
    // The pointer is at the top (12 o'clock), wheel segments start at -pi/2 (top)
    // We need to rotate the wheel so that the target segment's center is at the top
    final double targetAngle = resultIndex * segmentAngle + segmentAngle / 2;
    final double totalRotation = 4 * pi + (2 * pi - targetAngle);

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
      context.read<AudioService>().playWinSound();
      _showResultDialog(
        "${localization.translate(AppStrings.win)} $colorLabel $_finalResult",
        localization.translate({'en': 'You won ${_betAmount * multiplier} coins!', 'ko': '${_betAmount * multiplier} 코인 당첨!'}),
      );
    } else {
      context.read<AudioService>().playFailSound();
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

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<AudioService>().playLobbyBgm();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(AppStrings.roulette)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.read<AudioService>().playLobbyBgm();
              Navigator.pop(context);
            },
          ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 가용 공간에 맞춰 전체 비율 유지하면서 축소
                  final availableSize = min(constraints.maxWidth, constraints.maxHeight);
                  final scale = (availableSize / 300).clamp(0.6, 1.0);
                  final wheelSize = 280 * scale;
                  final hubSize = 60 * scale;
                  final arrowWidth = 10 * scale;
                  final arrowHeight = 16 * scale;
                  final arrowTop = 8 * scale;
                  
                  return Center(
                    child: SizedBox(
                      width: wheelSize,
                      height: wheelSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Spinning wheel
                          Transform.rotate(
                            angle: _angle,
                            child: CustomPaint(
                              size: Size(wheelSize, wheelSize),
                              painter: _RouletteWheelPainter(),
                            ),
                          ),
                          // Ball indicator (stationary pointer at top)
                          Positioned(
                            top: arrowTop,
                            child: CustomPaint(
                              size: Size(arrowWidth, arrowHeight),
                              painter: _ArrowPainter(),
                            ),
                          ),
                          // Center hub
                          Container(
                            width: hubSize,
                            height: hubSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.amber.shade800,
                              border: Border.all(color: Colors.amber, width: 3 * scale),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10 * scale,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(Icons.casino, color: Colors.white, size: 30 * scale),
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

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    // Sharp pointed arrow shape
    path.moveTo(size.width / 2, size.height); // Bottom point (sharp tip)
    path.lineTo(0, 0); // Top left
    path.lineTo(size.width, 0); // Top right
    path.close();
    
    // Draw shadow
    canvas.save();
    canvas.translate(2, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
    
    // Draw arrow
    canvas.drawPath(path, paint);
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.amber.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouletteWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / 37;

    // Draw outer border
    final borderPaint = Paint()
      ..color = Colors.amber.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius - 4, borderPaint);

    // Draw segments
    for (int i = 0; i < 37; i++) {
      final startAngle = i * segmentAngle - pi / 2;
      final number = _wheelNumbers[i];

      Color segmentColor;
      if (number == 0) {
        segmentColor = Colors.green.shade700;
      } else if (_redNumbers.contains(number)) {
        segmentColor = Colors.red.shade700;
      } else {
        segmentColor = Colors.grey.shade900;
      }

      final paint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 12),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Draw segment border
      final segmentBorderPaint = Paint()
        ..color = Colors.amber.shade600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 12),
        startAngle,
        segmentAngle,
        true,
        segmentBorderPaint,
      );

      // Draw number text
      final textPainter = TextPainter(
        text: TextSpan(
          text: number.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      canvas.save();
      final angle = startAngle + segmentAngle / 2;
      final textRadius = radius - 35;
      final x = center.dx + textRadius * cos(angle);
      final y = center.dy + textRadius * sin(angle);
      canvas.translate(x, y);
      canvas.rotate(angle + pi / 2);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }

    // Draw inner circle
    final innerPaint = Paint()
      ..color = Colors.brown.shade800
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.3, innerPaint);

    final innerBorderPaint = Paint()
      ..color = Colors.amber.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * 0.3, innerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
