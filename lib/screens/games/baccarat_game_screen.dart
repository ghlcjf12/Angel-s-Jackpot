import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class BaccaratGameScreen extends StatefulWidget {
  const BaccaratGameScreen({super.key});

  @override
  State<BaccaratGameScreen> createState() => _BaccaratGameScreenState();
}

class _BaccaratGameScreenState extends State<BaccaratGameScreen> {
  int _betAmount = 10;
  String _selectedBet = "PLAYER"; // PLAYER, BANKER, TIE
  bool _isDealing = false;

  List<int> _playerHand = [];
  List<int> _bankerHand = [];
  String _resultMessage = "Place your bet";

  void _deal() async {
    if (_isDealing) return;

    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();

    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    setState(() => _isDealing = true);

    final success = await provider.placeBet(_betAmount);
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
        );
        setState(() => _isDealing = false);
      }
      return;
    }

    setState(() {
      _playerHand = [_drawCard(), _drawCard()];
      _bankerHand = [_drawCard(), _drawCard()];
    });

    // Delay for animation effect
    await Future.delayed(const Duration(milliseconds: 500));

    int playerSum = _calculateSum(_playerHand);
    int bankerSum = _calculateSum(_bankerHand);

    String winner = "TIE";
    if (playerSum > bankerSum) winner = "PLAYER";
    if (bankerSum > playerSum) winner = "BANKER";

    bool win = false;
    double multiplier = 0;

    if (_selectedBet == winner) {
      win = true;
      if (winner == "TIE") {
        multiplier = 8;
      } else {
        multiplier = 2;
      }
    }

    if (mounted) {
      setState(() {
        _resultMessage = "${_betLabel(winner, localization)} ${localization.translate({'en': 'WINS!', 'ko': '승리!'})} (P:$playerSum vs B:$bankerSum)";
        _isDealing = false;
      });

      if (win) {
        provider.winPrize((_betAmount * multiplier).toInt());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.green, content: Text(localization.translate(AppStrings.win))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(localization.translate(AppStrings.lose))),
        );
      }
    }
  }
  
  int _drawCard() => Random().nextInt(13) + 1;
  
  int _calculateSum(List<int> hand) {
    int sum = 0;
    for (var card in hand) {
      // 10, J, Q, K are worth 0 points
      if (card >= 10) {
        sum += 0;
      } else {
        sum += card;
      }
    }
    return sum % 10;
  }

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    String tr(Map<String, String> value) => localization.translate(value);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(AppStrings.baccarat)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.amber),
            onPressed: () => showHowToPlayDialog(context, AppStrings.baccaratDescription),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Game Area
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildHand(tr({'en': 'BANKER', 'ko': '뱅커'}), _bankerHand),
                  Text(
                    _resultMessage == "Place your bet"
                        ? tr({'en': 'Place your bet', 'ko': '베팅하세요'})
                        : _resultMessage,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                  _buildHand(tr({'en': 'PLAYER', 'ko': '플레이어'}), _playerHand),
                ],
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
                        onPressed: _isDealing ? null : () => setState(() => _betAmount = max(10, _betAmount - 10)),
                        icon: const Icon(Icons.remove),
                      ),
                      Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                      IconButton(
                        onPressed: _isDealing ? null : () => setState(() => _betAmount += 10),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildBetOption(tr({'en': 'PLAYER', 'ko': '플레이어'}), "PLAYER", Colors.blue),
                      const SizedBox(width: 10),
                      _buildBetOption(tr({'en': 'TIE', 'ko': '타이'}), "TIE", Colors.green),
                      const SizedBox(width: 10),
                      _buildBetOption(tr({'en': 'BANKER', 'ko': '뱅커'}), "BANKER", Colors.red),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isDealing ? null : _deal,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                      child: Text(
                        _isDealing
                            ? tr({'en': 'DEALING...', 'ko': '딜링 중...'})
                            : tr({'en': 'DEAL', 'ko': '딜'}),
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

  Widget _buildBetOption(String label, String key, Color color) {
    bool selected = _selectedBet == key;
    return Expanded(
      child: GestureDetector(
        onTap: _isDealing ? null : () => setState(() => _selectedBet = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: color.withOpacity(selected ? 1.0 : (_isDealing ? 0.2 : 0.3)),
            border: selected ? Border.all(color: Colors.white, width: 2) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildHand(String label, List<int> hand) {
    return Column(
      children: [
        Text("$label (${_calculateSum(hand)})", style: const TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: hand.isEmpty 
              ? [const SizedBox(height: 90)] 
              : hand.map((c) => _buildCard(c)).toList(),
        ),
      ],
    );
  }

  Widget _buildCard(int value) {
    String label = value.toString();
    if (value == 1) label = "A";
    if (value == 11) label = "J";
    if (value == 12) label = "Q";
    if (value == 13) label = "K";
    
    return Container(
      width: 60,
      height: 90,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(child: Text(label, style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold))),
    );
  }

  String _betLabel(String key, LocalizationService localization) {
    switch (key) {
      case "PLAYER":
        return localization.translate({'en': 'PLAYER', 'ko': '플레이어'});
      case "BANKER":
        return localization.translate({'en': 'BANKER', 'ko': '뱅커'});
      case "TIE":
      default:
        return localization.translate({'en': 'TIE', 'ko': '타이'});
    }
  }
}
