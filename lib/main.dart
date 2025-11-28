import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/firebase_service.dart';
import 'providers/game_provider.dart';
import 'screens/lobby_screen.dart';
import 'services/ad_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AdService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    firebaseService.signInAnonymously();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: firebaseService),
        ChangeNotifierProxyProvider<FirebaseService, GameProvider>(
          create: (_) => GameProvider(firebaseService),
          update: (_, service, __) => GameProvider(service),
        ),
      ],
      child: MaterialApp(
        title: "Angel's Jackpot",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.dark,
            background: const Color(0xFF121212),
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            elevation: 0,
            centerTitle: true,
          ),
        ),
        home: const LobbyScreen(),
      ),
    );
  }
}
