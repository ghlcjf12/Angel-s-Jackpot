import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class HighLowGameScreen extends StatefulWidget {
  const HighLowGameScreen({super.key});

  @override
  State<HighLowGameScreen> createState() => _HighLowGameScreenState();
}

class _HighLowGameScreenState extends State<HighLowGameScreen> {
  int _currentCard = 1;
  int _betAmount = 10;
  bool _isPlaying = false;
  String _message = "Will the next card be Higher or Lower?";

  @override
  void initState() {
    super.initState();
    _currentCard = Random().nextInt(13) + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().playGameBgm();
    });
  }

  Future<void> _guess(bool higher) async {
    final localization = context.read<LocalizationService>();
    if (_isPlaying) return;

    final provider = context.read<GameProvider>();
    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    setState(() => _isPlaying = true);

    final success = await provider.placeBet(_betAmount);

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
        );
        setState(() => _isPlaying = false);
      }
      return;
    }

    if (mounted) {
      context.read<AudioService>().playBettingSoundLong();
    }

    int nextCard = Random().nextInt(13) + 1;
    bool win = false;

    if (higher && nextCard > _currentCard) win = true;
    if (!higher && nextCard < _currentCard) win = true;
    if (nextCard == _currentCard) win = false;

    if (mounted) {
      setState(() {
        _currentCard = nextCard;
        _isPlaying = false;
        if (win) {
          _message = "${localization.translate(AppStrings.win)} ${localization.translate({'en': 'Card was', 'ko': '카드는'})} $nextCard";
          provider.winPrize(_betAmount * 2);
          context.read<AudioService>().playWinSound();
        } else {
          _message = "${localization.translate(AppStrings.lose)} ${localization.translate({'en': 'Card was', 'ko': '카드는'})} $nextCard";
          context.read<AudioService>().playFailSound();
        }
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
          title: Text(tr(AppStrings.highLow)),
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
                showHowToPlayDialog(context, AppStrings.highLowDescription);
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
                  final scale = (constraints.maxHeight / 280).clamp(0.5, 1.0);
                  return Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tr({'en': 'Current Card', 'ko': '현재 카드'}), style: TextStyle(fontSize: 20 * scale, color: Colors.grey)),
                          SizedBox(height: 10 * scale),
                          _buildCard(_currentCard, scale),
                          SizedBox(height: 30 * scale),
                          Text(
                            _message == "Will the next card be Higher or Lower?"
                                ? tr({'en': 'Will the next card be Higher or Lower?', 'ko': '다음 카드는 높을까요? 낮을까요?'})
                                : _message,
                            style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold, color: Colors.amber),
                            textAlign: TextAlign.center,
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
                      IconButton(onPressed: _isPlaying ? null : () {
                        context.read<AudioService>().playButtonSound();
                        setState(() => _betAmount = max(10, _betAmount - 10));
                      }, icon: const Icon(Icons.remove)),
                      Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isPlaying ? null : () {
                        context.read<AudioService>().playButtonSound();
                        setState(() => _betAmount += 10);
                      }, icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPlaying ? null : () {
                            context.read<AudioService>().playButtonSound();
                            _guess(true);
                          },
                          icon: const Icon(Icons.arrow_upward),
                          label: Text(tr({'en': 'HIGHER', 'ko': '높다'})),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPlaying ? null : () {
                            context.read<AudioService>().playButtonSound();
                            _guess(false);
                          },
                          icon: const Icon(Icons.arrow_downward),
                          label: Text(tr({'en': 'LOWER', 'ko': '낮다'})),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.all(20)),
                        ),
                      ),
                    ],
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

  Widget _buildCard(int value, double scale) {
    String label = value.toString();
    if (value == 1) label = "A";
    if (value == 11) label = "J";
    if (value == 12) label = "Q";
    if (value == 13) label = "K";
    
    return Container(
      width: 120 * scale,
      height: 180 * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10 * scale, offset: Offset(0, 5 * scale))],
      ),
      child: Center(child: Text(label, style: TextStyle(color: Colors.black, fontSize: 60 * scale, fontWeight: FontWeight.bold))),
    );
  }
}
