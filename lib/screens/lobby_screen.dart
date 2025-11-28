import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'donation_ranking_screen.dart';
import 'games/crash_game_screen.dart';
import 'games/blackjack_game_screen.dart';
import 'games/roulette_game_screen.dart';
import 'games/slots_game_screen.dart';
import 'games/high_low_game_screen.dart';
import 'games/dice_game_screen.dart';
import 'games/coin_flip_game_screen.dart';
import 'games/baccarat_game_screen.dart';
import 'games/video_poker_game_screen.dart';
import 'games/scratch_card_game_screen.dart';
import '../services/ad_service.dart';
import '../widgets/banner_ad_widget.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("GAMBLE KING 👑", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
                      Consumer<GameProvider>(
                        builder: (context, provider, child) {
                          return Text("Balance: ${provider.balance} 🪙", style: const TextStyle(fontSize: 18, color: Colors.white));
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          AdService().showRewardedAd(
                            onReward: (amount) {
                              context.read<GameProvider>().rewardUser(amount);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Received $amount Coins!")));
                            },
                            onDismissed: () {},
                          );
                        },
                        icon: const Icon(Icons.video_library, color: Colors.black),
                        label: const Text("FREE COINS", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DonationRankingScreen()));
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                        child: const Text("RANKING", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                  _buildGameCard(context, "Crash 🚀", Colors.redAccent, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CrashGameScreen()));
                  }),
                  _buildGameCard(context, "Blackjack 🃏", Colors.green, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BlackjackGameScreen()));
                  }),
                  _buildGameCard(context, "Roulette 🎡", Colors.orange, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RouletteGameScreen()));
                  }),
                  _buildGameCard(context, "Slots 🎰", Colors.purple, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SlotsGameScreen()));
                  }),
                  _buildGameCard(context, "High-Low ⬆️⬇️", Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HighLowGameScreen()));
                  }),
                  _buildGameCard(context, "Dice 🎲", Colors.teal, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceGameScreen()));
                  }),
                  _buildGameCard(context, "Coin Flip 🪙", Colors.yellow.shade700, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinFlipGameScreen()));
                  }),
                  _buildGameCard(context, "Baccarat 🎴", Colors.brown, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BaccaratGameScreen()));
                  }),
                  _buildGameCard(context, "Video Poker ♠️", Colors.indigo, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoPokerGameScreen()));
                  }),
                  _buildGameCard(context, "Scratch 🎫", Colors.pink, () {
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
}
