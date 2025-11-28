import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/firebase_service.dart';

class DonationRankingScreen extends StatefulWidget {
  const DonationRankingScreen({super.key});

  @override
  State<DonationRankingScreen> createState() => _DonationRankingScreenState();
}

class _DonationRankingScreenState extends State<DonationRankingScreen> {
  final TextEditingController _donateController = TextEditingController();

  @override
  void dispose() {
    _donateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final firebaseService = context.read<FirebaseService>();

    return Scaffold(
      appBar: AppBar(title: const Text("Hall of Fame 🏆")),
      body: Column(
        children: [
          // Donation Area
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF252525),
            child: Column(
              children: [
                Text("My Balance: 🪙 ${gameProvider.balance}", style: const TextStyle(fontSize: 18, color: Colors.amber)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _donateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Amount to Donate",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.volunteer_activism),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        final amount = int.tryParse(_donateController.text);
                        if (amount != null && amount > 0) {
                          if (amount <= gameProvider.balance) {
                            await gameProvider.donate(amount);
                            _donateController.clear();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Donation Successful! Rank Updated.")),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Insufficient funds!")),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      child: const Text("DONATE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text("Donating coins removes them from your wallet but increases your Ranking Score.", 
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // Ranking List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: firebaseService.getRankingStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading rankings"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No donations yet. Be the first!"));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final uid = data['uid'] as String;
                    final totalDonated = data['totalDonated'] ?? 0;
                    final isMe = uid == firebaseService.user?.uid;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: index < 3 ? Colors.amber : Colors.grey[800],
                        child: Text("${index + 1}", style: TextStyle(color: index < 3 ? Colors.black : Colors.white)),
                      ),
                      title: Text(isMe ? "YOU" : "Player ${uid.substring(0, 4)}...", 
                        style: TextStyle(
                          color: isMe ? Colors.amber : Colors.white,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text("🏆 $totalDonated", 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
