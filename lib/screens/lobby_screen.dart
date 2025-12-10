import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_strings.dart';
import '../providers/game_provider.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
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

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    // Play lobby music when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().playLobbyBgm();
    });
  }

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
                          onPressed: () {
                            context.read<AudioService>().playButtonSound();
                            _openLanguageSheet(context);
                          },
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
                            context.read<AudioService>().playButtonSound();
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
                            context.read<AudioService>().playButtonSound();
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
                      const SizedBox(width: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 42, maxWidth: 42, minHeight: _headerButtonHeight),
                        child: Consumer<AudioService>(
                          builder: (context, audio, child) {
                            return IconButton(
                              onPressed: () {
                                audio.playButtonSound();
                                audio.toggleBgm();
                              },
                              icon: Icon(
                                audio.isBgmEnabled ? Icons.music_note : Icons.music_off,
                                color: Colors.amber,
                              ),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Remove Ads Button
                  Consumer<InAppPurchaseService>(
                    builder: (context, iapService, child) {
                      if (iapService.adRemovalPurchased) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                localization.translate({'en': 'Ads Removed ✓', 'ko': '광고 제거됨 ✓'}),
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: iapService.isPurchasing ? null : () async {
                            context.read<AudioService>().playButtonSound();
                            final error = await iapService.buyAdRemoval();
                            
                            if (!mounted) return;
                            
                            if (error != null) {
                              // Show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.orange,
                                  content: Text(error),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            } else if (iapService.adRemovalPurchased) {
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text(
                                    localization.translate({'en': 'Ads removed successfully!', 'ko': '광고가 성공적으로 제거되었습니다!'}),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            iapService.isPurchasing ? Icons.hourglass_empty : Icons.remove_circle_outline,
                            color: Colors.black,
                          ),
                          label: Text(
                            iapService.isPurchasing
                                ? localization.translate({'en': 'Processing...', 'ko': '처리 중...'})
                                : localization.translate({'en': '💎 Remove Ads', 'ko': '💎 광고 제거'}),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size.fromHeight(_headerButtonHeight),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      );
                    },
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
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.crash),
                    Colors.redAccent,
                    '🚀',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CrashGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.blackjack),
                    Colors.green,
                    '🃏',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlackjackGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.roulette),
                    Colors.orange,
                    '🎡',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RouletteGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.slots),
                    Colors.purple,
                    '🎰',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SlotsGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.highLow),
                    Colors.blue,
                    '⬆️⬇️',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HighLowGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.dice),
                    Colors.teal,
                    '🎲',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.coinFlip),
                    Colors.yellow.shade700,
                    '🪙',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinFlipGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.baccarat),
                    Colors.brown,
                    '♠️♥️',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BaccaratGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.videoPoker),
                    Colors.indigo,
                    '♠️',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoPokerGameScreen())),
                  ),
                  _buildGameCard(
                    context,
                    localization.translate(AppStrings.scratchCard),
                    Colors.pink,
                    '🎫',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScratchCardGameScreen())),
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

  Widget _buildGameCard(BuildContext context, String title, Color color, String emoji, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        context.read<AudioService>().playButtonSound();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C2C2C),
              color.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
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
