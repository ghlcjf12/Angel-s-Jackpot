import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class CoinFlipGameScreen extends StatefulWidget {
  const CoinFlipGameScreen({super.key});

  @override
  State<CoinFlipGameScreen> createState() => _CoinFlipGameScreenState();
}

class _CoinFlipGameScreenState extends State<CoinFlipGameScreen> {
  int _betAmount = 10;
  String _selected = "HEADS";
  String _result = "HEADS";
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().playGameBgm();
    });
  }

  void _flip() async {
    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    setState(() => _isFlipping = true);

    final success = await provider.placeBet(_betAmount);
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
        );
        setState(() => _isFlipping = false);
      }
      return;
    }

    if (mounted) {
      context.read<AudioService>().playBettingSound();
    }

    final finalResult = Random().nextBool() ? "HEADS" : "TAILS";

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() => _result = Random().nextBool() ? "HEADS" : "TAILS");
    }

    if (mounted) {
      setState(() {
        _result = finalResult;
        _isFlipping = false;
      });

      if (_selected == _result) {
        provider.winPrize(_betAmount * 2);
        context.read<AudioService>().playWinSound();
        _showSnack(localization.translate({'en': 'WIN! +${_betAmount * 2} coins', 'ko': '당첨! +${_betAmount * 2} 코인'}), Colors.green);
      } else {
        context.read<AudioService>().playFailSound();
        _showSnack(localization.translate({'en': 'LOSE - Try again!', 'ko': '패배 - 다시 시도!'}), Colors.red);
      }
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: color, content: Text(message)));
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
          title: Text(tr(AppStrings.coinFlip)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.read<AudioService>().playButtonSound();
              context.read<AudioService>().playLobbyBgm();
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.amber),
              onPressed: () {
                context.read<AudioService>().playButtonSound();
                showHowToPlayDialog(context, AppStrings.coinFlipDescription);
              },
            ),
          ],
        ),
        body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxHeight / 180).clamp(0.5, 1.0);
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60 * scale,
                            backgroundColor: Colors.yellow.shade700,
                            child: Text(
                              _displayFace(_result, localization),
                              style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                          SizedBox(height: 20 * scale),
                          Text(tr({'en': 'Choose Heads or Tails', 'ko': '앞면/뒷면을 선택하세요'}), style: TextStyle(fontSize: 14 * scale)),
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
                      IconButton(onPressed: _isFlipping ? null : () {
                        context.read<AudioService>().playButtonSound();
                        setState(() => _betAmount = max(10, _betAmount - 10));
                      }, icon: const Icon(Icons.remove)),
                      Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isFlipping ? null : () {
                        context.read<AudioService>().playButtonSound();
                        setState(() => _betAmount += 10);
                      }, icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildChoice(tr({'en': 'HEADS', 'ko': '앞면'}), "HEADS", Colors.orange),
                      _buildChoice(tr({'en': 'TAILS', 'ko': '뒷면'}), "TAILS", Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isFlipping ? null : _flip,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade700),
                      child: Text(
                        tr({'en': 'FLIP', 'ko': '던지기'}),
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

  Widget _buildChoice(String label, String key, Color color) {
    return GestureDetector(
      onTap: _isFlipping ? null : () {
        context.read<AudioService>().playButtonSound();
        setState(() => _selected = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _selected == key ? color : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(color: _selected == key ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _displayFace(String value, LocalizationService localization) {
    return localization.translate(
      value == "HEADS" ? {'en': 'HEADS', 'ko': '앞면'} : {'en': 'TAILS', 'ko': '뒷면'},
    );
  }
}
