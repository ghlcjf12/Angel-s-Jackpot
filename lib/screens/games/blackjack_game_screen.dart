import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../widgets/how_to_play_dialog.dart';

// Card class with suit and rank
class _PlayingCard {
  final int rank; // 1-13 (A-K)
  final int suit; // 0-3 (♠♥♦♣)

  _PlayingCard(this.rank, this.suit);

  String get rankLabel {
    switch (rank) {
      case 1:
        return "A";
      case 11:
        return "J";
      case 12:
        return "Q";
      case 13:
        return "K";
      default:
        return rank.toString();
    }
  }

  String get suitLabel {
    switch (suit) {
      case 0:
        return "♠";
      case 1:
        return "♥";
      case 2:
        return "♦";
      case 3:
        return "♣";
      default:
        return "";
    }
  }

  Color get suitColor {
    return (suit == 1 || suit == 2) ? Colors.red : Colors.black;
  }
}

class _Deck {
  final List<_PlayingCard> _cards = [];

  _Deck() {
    reset();
  }

  void reset() {
    _cards.clear();
    for (int suit = 0; suit < 4; suit++) {
      for (int rank = 1; rank <= 13; rank++) {
        _cards.add(_PlayingCard(rank, suit));
      }
    }
    shuffle();
  }

  void shuffle() {
    _cards.shuffle(Random());
  }

  _PlayingCard draw() {
    if (_cards.isEmpty) reset();
    return _cards.removeLast();
  }
}

class BlackjackGameScreen extends StatefulWidget {
  const BlackjackGameScreen({super.key});

  @override
  State<BlackjackGameScreen> createState() => _BlackjackGameScreenState();
}

class _BlackjackGameScreenState extends State<BlackjackGameScreen> {
  int _betAmount = 10;
  bool _isPlaying = false;
  bool _isStand = false;
  bool _isDealing = false;

  List<_PlayingCard> _playerHand = [];
  List<_PlayingCard> _dealerHand = [];
  late _Deck _deck;

  String _message = "Place your bet";

  @override
  void initState() {
    super.initState();
    _deck = _Deck();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioService>().playGameBgm();
    });
  }

  void _startGame() async {
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
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localization.translate(AppStrings.transactionFailed))),
        );
        setState(() => _isDealing = false);
      }
      return;
    }
    
    if (mounted) {
      context.read<AudioService>().playBettingSound();
    }

    _deck.reset();

    setState(() {
      _isPlaying = true;
      _isStand = false;
      _isDealing = false;
      _message = localization.translate({'en': 'Hit or Stand?', 'ko': '히트 또는 스탠드?'});
      _playerHand = [_deck.draw(), _deck.draw()];
      _dealerHand = [_deck.draw(), _deck.draw()];
    });

    // Check for natural blackjack
    if (_calculateScore(_playerHand) == 21) {
      _stand();
    }
  }

  int _calculateScore(List<_PlayingCard> hand) {
    int score = 0;
    int aces = 0;
    for (var card in hand) {
      if (card.rank == 1) {
        aces++;
        score += 11;
      } else if (card.rank >= 10) {
        score += 10;
      } else {
        score += card.rank;
      }
    }
    while (score > 21 && aces > 0) {
      score -= 10;
      aces--;
    }
    return score;
  }

  void _hit() {
    if (_isDealing || _isStand) return;

    setState(() {
      _playerHand.add(_deck.draw());
    });

    if (_calculateScore(_playerHand) > 21) {
      _endGame(false); // Bust
    }
  }

  void _stand() async {
    if (_isDealing) return;

    setState(() {
      _isStand = true;
      _isDealing = true;
    });

    // Dealer draws until 17
    while (_calculateScore(_dealerHand) < 17) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _dealerHand.add(_deck.draw());
      });
    }

    if (!mounted) return;

    int playerScore = _calculateScore(_playerHand);
    int dealerScore = _calculateScore(_dealerHand);

    setState(() => _isDealing = false);

    if (dealerScore > 21 || playerScore > dealerScore) {
      _endGame(true);
    } else if (playerScore == dealerScore) {
      _endGame(null); // Push
    } else {
      _endGame(false);
    }
  }

  void _endGame(bool? win) {
    final localization = context.read<LocalizationService>();
    setState(() {
      _isPlaying = false;
    });

    if (win == true) {
      _message = localization.translate({'en': 'YOU WIN!', 'ko': '승리!'});
      context.read<GameProvider>().winPrize(_betAmount * 2);
      context.read<AudioService>().playWinSound();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(localization.translate({
            'en': 'Congratulations! +${_betAmount * 2} coins',
            'ko': '축하합니다! +${_betAmount * 2} 코인',
          })),
        ),
      );
    } else if (win == false) {
      _message = localization.translate({'en': 'YOU LOSE!', 'ko': '패배!'});
      context.read<AudioService>().playFailSound();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(localization.translate({
            'en': 'Better luck next time!',
            'ko': '다음 기회에!',
          })),
        ),
      );
    } else {
      _message = localization.translate({'en': 'PUSH (Tie)', 'ko': '무승부 (푸시)'});
      context.read<GameProvider>().winPrize(_betAmount);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text(localization.translate({
            'en': 'Push! Bet returned.',
            'ko': '푸시! 베팅금 반환.',
          })),
        ),
      );
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
          title: Text(tr(AppStrings.blackjack)),
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
                showHowToPlayDialog(context, AppStrings.blackjackDescription);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Dealer Area
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = (constraints.maxHeight / 130).clamp(0.4, 1.0);
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.green.shade900,
                            Colors.green.shade800,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(16 * scale),
                            ),
                            child: Text(
                              "${tr({'en': 'Dealer', 'ko': '딜러'})}: ${_isStand ? _calculateScore(_dealerHand) : "?"}",
                              style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                          SizedBox(
                            height: 80 * scale,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _dealerHand.asMap().entries.map((entry) {
                                int idx = entry.key;
                                _PlayingCard card = entry.value;
                                if (!_isStand && idx == 1) return _buildCardBack(scale);
                                return _buildCard(card, scale);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.black54,
              child: Text(
                _message == "Place your bet" ? tr({'en': 'Place your bet', 'ko': '베팅하세요'}) : _message,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _message.contains('WIN') ? Colors.green : (_message.contains('LOSE') ? Colors.red : Colors.amber),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Player Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxHeight / 130).clamp(0.4, 1.0);
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.green.shade800,
                          Colors.green.shade900,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 6 * scale),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(16 * scale),
                          ),
                          child: Text(
                            "${tr({'en': 'You', 'ko': '플레이어'})}: ${_calculateScore(_playerHand)}",
                            style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        SizedBox(
                          height: 80 * scale,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _playerHand.map((c) => _buildCard(c, scale)).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF252525),
              child: Column(
                children: [
                  if (!_isPlaying)
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
                        Text("${tr(AppStrings.bet)}: $_betAmount", style: const TextStyle(fontSize: 20)),
                        IconButton(
                          onPressed: _isDealing ? null : () {
                            context.read<AudioService>().playButtonSound();
                            setState(() => _betAmount += 10);
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isPlaying
                        ? Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: (_isStand || _isDealing) ? null : () {
                                    context.read<AudioService>().playButtonSound();
                                    _hit();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                  child: Text(
                                    tr({'en': 'HIT', 'ko': '히트'}),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: (_isStand || _isDealing) ? null : () {
                                    context.read<AudioService>().playButtonSound();
                                    _stand();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                  child: Text(
                                    tr({'en': 'STAND', 'ko': '스탠드'}),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _isDealing ? null : _startGame,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            child: Text(
                              _isDealing
                                  ? tr({'en': 'DEALING...', 'ko': '딜링 중...'})
                                  : tr({'en': 'DEAL', 'ko': '딜'}),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
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

  Widget _buildCard(_PlayingCard card, double scale) {
    return Container(
      width: 50 * scale,
      height: 75 * scale,
      margin: EdgeInsets.symmetric(horizontal: 2 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4 * scale,
            offset: Offset(2 * scale, 2 * scale),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top left
          Positioned(
            top: 3 * scale,
            left: 3 * scale,
            child: Column(
              children: [
                Text(
                  card.rankLabel,
                  style: TextStyle(
                    color: card.suitColor,
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  card.suitLabel,
                  style: TextStyle(
                    color: card.suitColor,
                    fontSize: 8 * scale,
                  ),
                ),
              ],
            ),
          ),
          // Center
          Center(
            child: Text(
              card.suitLabel,
              style: TextStyle(
                color: card.suitColor,
                fontSize: 22 * scale,
              ),
            ),
          ),
          // Bottom right (inverted)
          Positioned(
            bottom: 3 * scale,
            right: 3 * scale,
            child: Transform.rotate(
              angle: 3.14159,
              child: Column(
                children: [
                  Text(
                    card.rankLabel,
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    card.suitLabel,
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: 8 * scale,
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

  Widget _buildCardBack(double scale) {
    return Container(
      width: 50 * scale,
      height: 75 * scale,
      margin: EdgeInsets.symmetric(horizontal: 2 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade900, Colors.red.shade800],
        ),
        borderRadius: BorderRadius.circular(6 * scale),
        border: Border.all(color: Colors.white, width: 2 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4 * scale,
            offset: Offset(2 * scale, 2 * scale),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 30 * scale,
          height: 45 * scale,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber, width: 1 * scale),
            borderRadius: BorderRadius.circular(3 * scale),
          ),
          child: Center(
            child: Icon(Icons.question_mark, color: Colors.amber, size: 20 * scale),
          ),
        ),
      ),
    );
  }
}