import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_strings.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/localization_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'donation_ranking_screen.dart';
import 'games/baccarat_game_screen.dart';
import 'games/blackjack_game_screen.dart';
import 'games/coin_flip_game_screen.dart';
import 'games/crash_game_screen.dart';
import 'games/dice_game_screen.dart';
import 'games/high_low_game_screen.dart';
import 'games/roulette_game_screen.dart';
import 'games/scratch_card_game_screen.dart';
import 'games/slots_game_screen.dart';
import 'games/video_poker_game_screen.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = context.watch<LocalizationService>();
    const double _headerButtonHeight = 42;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                border: Border(bottom: BorderSide(color: Colors.amber, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          localization.translate(AppStrings.appTitle),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 72, maxWidth: 80, minHeight: _headerButtonHeight),
                        child: OutlinedButton.icon(
                          onPressed: () => _openLanguageSheet(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amber),
                            foregroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size.fromHeight(_headerButtonHeight),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.language, size: 18),
                          label: Text(
                            localization.isKorean ? 'KR' : 'EN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Consumer<GameProvider>(
                    builder: (context, provider, child) {
                      return Text(
                        "${localization.translate(AppStrings.balance)}: ${provider.balance} coins",
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            AdService().showRewardedAd(
                              onReward: (amount) {
                                context.read<GameProvider>().winPrize(amount);
                                final message = localization.isKorean ? "$amount 코인을 받았습니다!" : "Received $amount Coins!";
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                              },
                              onDismissed: () {},
                            );
                          },
                          icon: const Icon(Icons.video_library, color: Colors.black),
                          label: Text(
                            localization.translate(AppStrings.freeCoins),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size.fromHeight(_headerButtonHeight),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationRankingScreen()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size.fromHeight(_headerButtonHeight),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            localization.translate(AppStrings.ranking),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Game Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildGameCard(context, localization.translate(AppStrings.crash), Colors.redAccent, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CrashGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.blackjack), Colors.green, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BlackjackGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.roulette), Colors.orange, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RouletteGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.slots), Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SlotsGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.highLow), Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HighLowGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.dice), Colors.teal, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.coinFlip), Colors.yellow.shade700, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinFlipGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.baccarat), Colors.brown, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BaccaratGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.videoPoker), Colors.indigo, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoPokerGameScreen()));
                  }),
                  _buildGameCard(context, localization.translate(AppStrings.scratchCard), Colors.pink, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScratchCardGameScreen()));
                  }),
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

  Widget _buildGameCard(BuildContext context, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.games, size: 48, color: color), // Placeholder icon
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _openLanguageSheet(BuildContext context) {
    final localization = context.read<LocalizationService>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.language, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    localization.isKorean ? '언어 설정' : 'Language',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                value: 'en',
                groupValue: localization.currentLanguage,
                activeColor: Colors.amber,
                title: const Text('English'),
                onChanged: (v) {
                  localization.setLanguage('en');
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                value: 'ko',
                groupValue: localization.currentLanguage,
                activeColor: Colors.amber,
                title: const Text('한국어'),
                onChanged: (v) {
                  localization.setLanguage('ko');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
