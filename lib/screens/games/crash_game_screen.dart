import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class CrashGameScreen extends StatefulWidget {
  const CrashGameScreen({super.key});

  @override
  State<CrashGameScreen> createState() => _CrashGameScreenState();
}

class _CrashGameScreenState extends State<CrashGameScreen> {
  bool _isPlaying = false;
  bool _crashed = false;
  bool _cashedOut = false;
  bool _isCashingOut = false; // Prevent multiple cash-out attempts
  double _multiplier = 1.0;
  double _crashPoint = 0.0;
  int _betAmount = 10;

  Timer? _timer;
  final List<FlSpot> _spots = [const FlSpot(0, 1.0)];
  double _time = 0.0;

  double _determineCrashPoint() {
    // 더 균형잡힌 크래시 포인트 분포
    // 하우스 엣지 약 5%를 고려 (95% RTP)
    final random = Random();
    final r = random.nextDouble();
    
    // 구간별 분포 (더 다양한 배수가 나오도록)
    // 5% 확률: 1.00x ~ 1.20x (즉시 크래시)
    // 15% 확률: 1.20x ~ 1.50x (낮은 배수)
    // 25% 확률: 1.50x ~ 2.50x (중간 배수)
    // 25% 확률: 2.50x ~ 5.00x (높은 배수)
    // 20% 확률: 5.00x ~ 20.00x (고배수)
    // 8% 확률: 20.00x ~ 100.00x (잭팟)
    // 2% 확률: 100.00x ~ 500.00x (대박)
    
    double crashPoint;
    
    if (r < 0.05) {
      // 5%: 1.00x ~ 1.20x
      crashPoint = 1.00 + (r / 0.05) * 0.20;
    } else if (r < 0.20) {
      // 15%: 1.20x ~ 1.50x
      crashPoint = 1.20 + ((r - 0.05) / 0.15) * 0.30;
    } else if (r < 0.45) {
      // 25%: 1.50x ~ 2.50x
      crashPoint = 1.50 + ((r - 0.20) / 0.25) * 1.00;
    } else if (r < 0.70) {
      // 25%: 2.50x ~ 5.00x
      crashPoint = 2.50 + ((r - 0.45) / 0.25) * 2.50;
    } else if (r < 0.90) {
      // 20%: 5.00x ~ 20.00x
      crashPoint = 5.00 + ((r - 0.70) / 0.20) * 15.00;
    } else if (r < 0.98) {
      // 8%: 20.00x ~ 100.00x
      crashPoint = 20.00 + ((r - 0.90) / 0.08) * 80.00;
    } else {
      // 2%: 100.00x ~ 500.00x
      crashPoint = 100.00 + ((r - 0.98) / 0.02) * 400.00;
    }
    
    return crashPoint;
  }

  void _startGame() async {
    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    final success = await provider.placeBet(_betAmount);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
      );
      return;
    }

    setState(() {
      _isPlaying = true;
      _crashed = false;
      _cashedOut = false;
      _isCashingOut = false;
      _multiplier = 1.0;
      _time = 0.0;
      _spots
        ..clear()
        ..add(const FlSpot(0, 1.0));
      _crashPoint = _determineCrashPoint();
    });

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _time += 0.1;
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

  void _cashOut() async {
    final localization = context.read<LocalizationService>();

    // Prevent multiple cash-out attempts
    if (_cashedOut || _crashed || _isCashingOut) return;

    setState(() => _isCashingOut = true);

    _timer?.cancel();
    final winAmount = (_betAmount * _multiplier).floor();

    // Award the prize
    await context.read<GameProvider>().winPrize(winAmount);

    if (mounted) {
      setState(() {
        _cashedOut = true;
        _isPlaying = false;
        _isCashingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            localization.isKorean
                ? "${_multiplier.toStringAsFixed(2)}배에서 캐시 아웃! $winAmount 코인 획득!"
                : "Cashed out at ${_multiplier.toStringAsFixed(2)}x! Won $winAmount coins!",
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(AppStrings.crash)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            onPressed: () => showHowToPlayDialog(context, AppStrings.crashDescription),
          ),
        ],
      ),
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
                    maxY: max(_multiplier * 1.2, 2),
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
              _crashed
                  ? (localization.isKorean
                      ? "${_multiplier.toStringAsFixed(2)}배에서 크래시"
                      : "CRASHED @ ${_multiplier.toStringAsFixed(2)}x")
                  : "${_multiplier.toStringAsFixed(2)}x",
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
                      IconButton(
                        onPressed: _isPlaying ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)),
                        icon: const Icon(Icons.remove),
                      ),
                      Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(
                        onPressed: _isPlaying ? null : () => setState(() => _betAmount += 10),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: _isPlaying
                        ? ElevatedButton(
                            onPressed: (_cashedOut || _isCashingOut) ? null : _cashOut,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: Text(
                              _isCashingOut
                                  ? tr({'en': 'CASHING OUT...', 'ko': '캐시아웃 중...'})
                                  : tr({'en': 'CASH OUT', 'ko': '캐시 아웃'}),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            child: Text(
                              tr({'en': 'PLACE BET', 'ko': '베팅하기'}),
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
}
