import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
        );
        setState(() => _isPlaying = false);
      }
      return;
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
        } else {
          _message = "${localization.translate(AppStrings.lose)} ${localization.translate({'en': 'Card was', 'ko': '카드는'})} $nextCard";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(AppStrings.highLow)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            onPressed: () => showHowToPlayDialog(context, AppStrings.highLowDescription),
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
                    Text(tr({'en': 'Current Card', 'ko': '현재 카드'}), style: TextStyle(fontSize: 20, color: Colors.grey)),
                    const SizedBox(height: 10),
                    _buildCard(_currentCard),
                    const SizedBox(height: 30),
                    Text(
                      _message == "Will the next card be Higher or Lower?"
                          ? tr({'en': 'Will the next card be Higher or Lower?', 'ko': '다음 카드는 높을까요? 낮을까요?'})
                          : _message,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber),
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
                      IconButton(onPressed: _isPlaying ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)), icon: const Icon(Icons.remove)),
                      Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(onPressed: _isPlaying ? null : () => setState(() => _betAmount += 10), icon: const Icon(Icons.add)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPlaying ? null : () => _guess(true),
                          icon: const Icon(Icons.arrow_upward),
                          label: Text(tr({'en': 'HIGHER', 'ko': '높다'})),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(20)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPlaying ? null : () => _guess(false),
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
    );
  }

  Widget _buildCard(int value) {
    String label = value.toString();
    if (value == 1) label = "A";
    if (value == 11) label = "J";
    if (value == 12) label = "Q";
    if (value == 13) label = "K";
    
    return Container(
      width: 120,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Center(child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 60, fontWeight: FontWeight.bold))),
    );
  }
}
