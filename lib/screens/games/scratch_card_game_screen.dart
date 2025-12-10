import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scratcher/scratcher.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

class ScratchCardGameScreen extends StatefulWidget {
  const ScratchCardGameScreen({super.key});

  @override
  State<ScratchCardGameScreen> createState() => _ScratchCardGameScreenState();
}

class _ScratchCardGameScreenState extends State<ScratchCardGameScreen> {
  int _betAmount = 20;
  int _prize = 0;
  bool _isScratched = false;
  bool _hasTicket = false;
  bool _isPurchasing = false;
  final GlobalKey<ScratcherState> _scratcherKey = GlobalKey<ScratcherState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().playGameBgm();
    });
  }

  Future<void> _buyTicket() async {
    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();

    if (_hasTicket || _isPurchasing) return;

    if (provider.balance < _betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
      );
      return;
    }

    setState(() => _isPurchasing = true);

    final success = await provider.placeBet(_betAmount);

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
        );
        setState(() => _isPurchasing = false);
      }
      return;
    }

    if (mounted) {
      context.read<AudioService>().playBettingSound();
    }

    setState(() {
      _isScratched = false;
      _hasTicket = true;
      _isPurchasing = false;
      int r = Random().nextInt(100);
      if (r < 45) _prize = 0; // 45% lose
      else if (r < 70) _prize = (_betAmount * 0.8).round(); // 25% small return
      else if (r < 90) _prize = _betAmount * 2; // 20% double
      else _prize = _betAmount * 5; // 10% big win
    });

    _scratcherKey.currentState?.reset(duration: const Duration(milliseconds: 0));
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
          title: Text(tr(AppStrings.scratchCard)),
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
                showHowToPlayDialog(context, AppStrings.scratchCardDescription);
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
                  final scale = (constraints.maxHeight / 300).clamp(0.5, 1.0);
                  return Center(
                    child: _hasTicket
                        ? SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  tr({'en': 'Scratch to Win!', 'ko': '긁어서 당첨을 확인하세요!'}),
                                  style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 20 * scale),
                                Scratcher(
                                  key: _scratcherKey,
                                  brushSize: 50 * scale,
                                  threshold: 50,
                                  color: Colors.grey,
                                  onThreshold: () {
                                    if (!_isScratched) {
                                      setState(() {
                                        _isScratched = true;
                                        _hasTicket = false;
                                      });
                                      if (_prize > 0) {
                                        context.read<GameProvider>().winPrize(_prize);
                                        context.read<AudioService>().playWinSound();
                                        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.green,
                                            content: Text(
                                              tr({'en': 'WON $_prize COINS!', 'ko': '$_prize 코인 당첨!'}),
                                            ),
                                          ),
                                        );
                                      } else {
                                        context.read<AudioService>().playFailSound();
                                        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text(tr({'en': 'Better luck next time!', 'ko': '다음 기회에!'})),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: 300 * scale,
                                    height: 200 * scale,
                                    color: Colors.white,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _prize > 0 ? tr(AppStrings.win) : tr({'en': 'TRY AGAIN', 'ko': '다시 시도'}),
                                            style: TextStyle(
                                              fontSize: 32 * scale,
                                              fontWeight: FontWeight.bold,
                                              color: _prize > 0 ? Colors.green : Colors.red,
                                            ),
                                          ),
                                          if (_prize > 0)
                                            Text("+$_prize", style: TextStyle(fontSize: 24 * scale, color: Colors.black)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.confirmation_number, size: 100 * scale, color: Colors.grey[600]),
                                SizedBox(height: 20 * scale),
                                Text(
                                  tr({'en': 'Buy a ticket to play!', 'ko': '티켓을 구매하고 플레이하세요!'}),
                                  style: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.bold, color: Colors.grey[400]),
                                ),
                                SizedBox(height: 10 * scale),
                                Text(
                                  tr({'en': 'Ticket Price: $_betAmount coins', 'ko': '티켓 가격: $_betAmount 코인'}),
                                  style: TextStyle(fontSize: 18 * scale, color: Colors.grey[500]),
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
                  Text("${tr({'en': 'Ticket Price', 'ko': '티켓 가격'})}: $_betAmount", style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: (_hasTicket || _isPurchasing) ? null : () {
                        context.read<AudioService>().playButtonSound();
                        _buyTicket();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
                      child: Text(
                        _isPurchasing
                            ? tr({'en': 'PURCHASING...', 'ko': '구매 중...'})
                            : (_hasTicket
                                ? tr({'en': 'SCRATCH THE CARD', 'ko': '카드 긁기'})
                                : tr({'en': 'BUY TICKET', 'ko': '티켓 구매'})),
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
    ),
    );
  }
}
