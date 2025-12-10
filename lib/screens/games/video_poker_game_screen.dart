import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/ad_service.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

// Card class with suit and rank
class PlayingCard {
  final int rank; // 1-13 (A-K)
  final int suit; // 0-3 (♠♥♦♣)

  PlayingCard(this.rank, this.suit);

  String get rankLabel {
    switch (rank) {
      case 1: return "A";
      case 11: return "J";
      case 12: return "Q";
      case 13: return "K";
      default: return rank.toString();
    }
  }

  String get suitLabel {
    switch (suit) {
      case 0: return "♠";
      case 1: return "♥";
      case 2: return "♦";
      case 3: return "♣";
      default: return "";
    }
  }

  Color get suitColor {
    return (suit == 1 || suit == 2) ? Colors.red : Colors.black;
  }

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => rank.hashCode ^ suit.hashCode;
}

// Deck class
class Deck {
  final List<PlayingCard> _cards = [];

  Deck() {
    reset();
  }

  void reset() {
    _cards.clear();
    for (int suit = 0; suit < 4; suit++) {
      for (int rank = 1; rank <= 13; rank++) {
        _cards.add(PlayingCard(rank, suit));
      }
    }
    shuffle();
  }

  void shuffle() {
    _cards.shuffle(Random());
  }

  PlayingCard draw() {
    if (_cards.isEmpty) reset();
    return _cards.removeLast();
  }

  void removeCard(PlayingCard card) {
    _cards.remove(card);
  }
}

class VideoPokerGameScreen extends StatefulWidget {
  const VideoPokerGameScreen({super.key});

  @override
  State<VideoPokerGameScreen> createState() => _VideoPokerGameScreenState();
}

class _VideoPokerGameScreenState extends State<VideoPokerGameScreen> {
  int _betAmount = 10;
  List<PlayingCard> _hand = [];
  List<bool> _held = [false, false, false, false, false];
  bool _isFirstDeal = true;
  bool _isDealing = false;
  String _message = "Press DEAL to start";
  String _handRank = "";
  late Deck _deck;

  @override
  void initState() {
    super.initState();
    _deck = Deck();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().playGameBgm();
    });
  }

  Future<void> _deal() async {
    if (_isDealing) return;

    final localization = context.read<LocalizationService>();
    final provider = context.read<GameProvider>();

    if (_isFirstDeal) {
      if (provider.balance < _betAmount) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.insufficientFunds))),
        );
        return;
      }

      final success = await provider.placeBet(_betAmount);

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
          );
        }
        return;
      }

      if (mounted) {
        context.read<AudioService>().playBettingSoundLong();
      }

      setState(() => _isDealing = true);

      _deck.reset();

      setState(() {
        _hand = List.generate(5, (_) => _deck.draw());
        _held = [false, false, false, false, false];
        _isFirstDeal = false;
        _isDealing = false;
        _message = localization.translate({'en': 'Hold cards and Draw', 'ko': '홀드할 카드를 선택하고 드로우'});
        _handRank = "";
      });
    } else {
      setState(() => _isDealing = true);

      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        for (int i = 0; i < 5; i++) {
          if (!_held[i]) {
            _hand[i] = _deck.draw();
          }
        }
        _isFirstDeal = true;
        _isDealing = false;
      });

      _checkWin();
    }
  }

  void _checkWin() {
    final localization = context.read<LocalizationService>();
    final result = _evaluateHand();

    int winAmount = result.multiplier * _betAmount;
    String handName = localization.translate(result.name);

    if (winAmount > 0) {
      context.read<GameProvider>().winPrize(winAmount);
      context.read<AudioService>().playWinSound();
      setState(() {
        _message = "${localization.translate(AppStrings.win)} $handName (+$winAmount)";
        _handRank = handName;
      });
    } else {
      context.read<AudioService>().playFailSound();
      setState(() {
        _message = handName;
        _handRank = handName;
      });
    }
  }

  _HandResult _evaluateHand() {
    // Sort by rank
    final ranks = _hand.map((c) => c.rank).toList()..sort();
    final suits = _hand.map((c) => c.suit).toList();

    // Count ranks
    Map<int, int> rankCounts = {};
    for (var rank in ranks) {
      rankCounts[rank] = (rankCounts[rank] ?? 0) + 1;
    }

    final counts = rankCounts.values.toList()..sort((a, b) => b.compareTo(a));
    final isFlush = suits.every((s) => s == suits[0]);

    // Check for straight
    bool isStraight = false;
    final uniqueRanks = ranks.toSet().toList()..sort();

    if (uniqueRanks.length == 5) {
      if (uniqueRanks[4] - uniqueRanks[0] == 4) {
        isStraight = true;
      }
      // Ace-low straight (A-2-3-4-5)
      if (uniqueRanks.contains(1) &&
          uniqueRanks.contains(2) &&
          uniqueRanks.contains(3) &&
          uniqueRanks.contains(4) &&
          uniqueRanks.contains(5)) {
        isStraight = true;
      }
      // Ace-high straight (10-J-Q-K-A)
      if (uniqueRanks.contains(1) &&
          uniqueRanks.contains(10) &&
          uniqueRanks.contains(11) &&
          uniqueRanks.contains(12) &&
          uniqueRanks.contains(13)) {
        isStraight = true;
      }
    }

    // Royal Flush
    if (isFlush && isStraight && ranks.contains(1) && ranks.contains(13)) {
      return _HandResult({'en': 'ROYAL FLUSH!', 'ko': '로열 플러시!'}, 250);
    }

    // Straight Flush
    if (isFlush && isStraight) {
      return _HandResult({'en': 'Straight Flush!', 'ko': '스트레이트 플러시!'}, 50);
    }

    // Four of a Kind
    if (counts[0] == 4) {
      return _HandResult({'en': 'Four of a Kind!', 'ko': '포 카드!'}, 25);
    }

    // Full House
    if (counts[0] == 3 && counts[1] == 2) {
      return _HandResult({'en': 'Full House!', 'ko': '풀 하우스!'}, 9);
    }

    // Flush
    if (isFlush) {
      return _HandResult({'en': 'Flush!', 'ko': '플러시!'}, 6);
    }

    // Straight
    if (isStraight) {
      return _HandResult({'en': 'Straight!', 'ko': '스트레이트!'}, 4);
    }

    // Three of a Kind
    if (counts[0] == 3) {
      return _HandResult({'en': 'Three of a Kind!', 'ko': '트리플!'}, 3);
    }

    // Two Pair
    if (counts[0] == 2 && counts[1] == 2) {
      return _HandResult({'en': 'Two Pair!', 'ko': '투 페어!'}, 2);
    }

    // Jacks or Better (pair of J, Q, K, or A)
    if (counts[0] == 2) {
      final pairRank = rankCounts.entries.firstWhere((e) => e.value == 2).key;
      if (pairRank >= 11 || pairRank == 1) {
        return _HandResult({'en': 'Jacks or Better!', 'ko': '잭 이상 원 페어!'}, 1);
      } else {
        return _HandResult({'en': 'Low Pair (No Win)', 'ko': '낮은 페어 (노 윈)'}, 0);
      }
    }

    return _HandResult({'en': 'No Win', 'ko': '노 윈'}, 0);
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
          title: Text(tr(AppStrings.videoPoker)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              context.read<AudioService>().playButtonSound();
              context.read<AudioService>().playLobbyBgm();
              
              AdService().incrementGameCount();
              AdService().showInterstitialAd(
                onDismissed: () {
                  if (mounted) {
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.amber),
              onPressed: () {
                context.read<AudioService>().playButtonSound();
                showHowToPlayDialog(context, AppStrings.videoPokerDescription);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Pay table
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPayItem('RF', '250x', _handRank.contains('ROYAL')),
                    _buildPayItem('SF', '50x', _handRank.contains('Straight Flush')),
                    _buildPayItem('4K', '25x', _handRank.contains('Four')),
                    _buildPayItem('FH', '9x', _handRank.contains('Full')),
                    _buildPayItem('FL', '6x', _handRank.contains('Flush') && !_handRank.contains('Straight')),
                    _buildPayItem('ST', '4x', _handRank.contains('Straight') && !_handRank.contains('Flush')),
                    _buildPayItem('3K', '3x', _handRank.contains('Three')),
                    _buildPayItem('2P', '2x', _handRank.contains('Two Pair')),
                    _buildPayItem('J+', '1x', _handRank.contains('Jacks')),
                  ],
                ),
              ),
            ),

            // Hand Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxHeight / 180).clamp(0.5, 1.0);
                  return Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _hand.isEmpty
                            ? [Text(tr({'en': 'Press DEAL', 'ko': '딜을 눌러 시작'}), style: TextStyle(fontSize: 16 * scale))]
                            : _hand.asMap().entries.map((entry) {
                                int idx = entry.key;
                                PlayingCard card = entry.value;
                                return GestureDetector(
                                  onTap: (_isFirstDeal || _isDealing) ? null : () {
                                    context.read<AudioService>().playButtonSound();
                                    setState(() => _held[idx] = !_held[idx]);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    transform: Matrix4.translationValues(0, _held[idx] ? -10 * scale : 0, 0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildCard(card, _held[idx], scale),
                                        SizedBox(height: 5 * scale),
                                        AnimatedOpacity(
                                          duration: const Duration(milliseconds: 200),
                                          opacity: _held[idx] ? 1.0 : 0.0,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 2 * scale),
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius: BorderRadius.circular(4 * scale),
                                            ),
                                            child: Text(
                                              tr({'en': 'HELD', 'ko': '홀드'}),
                                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12 * scale),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _message == "Press DEAL to start"
                    ? tr({'en': 'Press DEAL to start', 'ko': '딜을 눌러 시작하세요'})
                    : _message,
                style: TextStyle(
                  fontSize: 16,
                  color: _message.contains('WIN') ? Colors.green : Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),

            // Controls
            Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF252525),
              child: Column(
                children: [
                  if (_isFirstDeal)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _isDealing ? null : () {
                            context.read<AudioService>().playButtonSound();
                            setState(() => _betAmount = max(10, _betAmount - 10));
                          },
                          icon: const Icon(Icons.remove),
                        ),
                        Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 24)),
                        IconButton(
                          onPressed: _isDealing ? null : () {
                            context.read<AudioService>().playButtonSound();
                            setState(() => _betAmount += 10);
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isDealing ? null : () {
                        context.read<AudioService>().playButtonSound();
                        _deal();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                      child: Text(
                        _isFirstDeal ? tr({'en': 'DEAL', 'ko': '딜'}) : tr({'en': 'DRAW', 'ko': '드로우'}),
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

  Widget _buildPayItem(String label, String payout, bool highlight) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? Colors.amber : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.black : Colors.white,
          )),
          Text(payout, style: TextStyle(
            fontSize: 12,
            color: highlight ? Colors.black : Colors.amber,
          )),
        ],
      ),
    );
  }

  Widget _buildCard(PlayingCard card, bool isHeld, double scale) {
    return Container(
      width: 55 * scale,
      height: 80 * scale,
      margin: EdgeInsets.all(3 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color: isHeld ? Colors.amber : Colors.grey.shade400,
          width: isHeld ? 3 * scale : 1 * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: isHeld ? Colors.amber.withOpacity(0.5) : Colors.black26,
            blurRadius: (isHeld ? 8 : 4) * scale,
            offset: Offset(0, 2 * scale),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top left rank and suit
          Positioned(
            top: 4 * scale,
            left: 4 * scale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  card.rankLabel,
                  style: TextStyle(
                    color: card.suitColor,
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  card.suitLabel,
                  style: TextStyle(
                    color: card.suitColor,
                    fontSize: 12 * scale,
                  ),
                ),
              ],
            ),
          ),
          // Center suit
          Center(
            child: Text(
              card.suitLabel,
              style: TextStyle(
                color: card.suitColor,
                fontSize: 24 * scale,
              ),
            ),
          ),
          // Bottom right (inverted)
          Positioned(
            bottom: 4 * scale,
            right: 4 * scale,
            child: Transform.rotate(
              angle: 3.14159,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    card.rankLabel,
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    card.suitLabel,
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: 12 * scale,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandResult {
  final Map<String, String> name;
  final int multiplier;

  _HandResult(this.name, this.multiplier);
}
