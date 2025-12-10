import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/firebase_service.dart';
import 'services/localization_service.dart';
import 'services/audio_service.dart';
import 'providers/game_provider.dart';
import 'screens/lobby_screen.dart';
import 'screens/google_login_screen.dart';
import 'services/ad_service.dart';
import 'firebase_options.dart';
import 'constants/app_strings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only if not already initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized - this is fine during hot reload
    if (e.toString().contains('duplicate-app')) {
      debugPrint('Firebase already initialized');
    } else {
      rethrow;
    }
  }

  await AdService().initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final FirebaseService _firebaseService = FirebaseService();
  final LocalizationService _localizationService = LocalizationService();
  final AudioService _audioService = AudioService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _firebaseService),
        ChangeNotifierProvider.value(value: _localizationService),
        ChangeNotifierProvider.value(value: _audioService),
        ChangeNotifierProvider<GameProvider>(
          create: (context) => GameProvider(context.read<FirebaseService>()),
        ),
      ],
      child: LifecycleWatcher(
        child: Consumer<LocalizationService>(
        builder: (context, localization, _) {
          return MaterialApp(
            title: localization.translate(AppStrings.appTitle),
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
            home: const AuthGate(),
          );
        },
      ),
    ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseService>(
      builder: (context, service, _) {
        if (service.user == null) return const GoogleLoginScreen();
        return const LobbyScreen();
      },
    );
  }
}

class LifecycleWatcher extends StatefulWidget {
  final Widget child;
  const LifecycleWatcher({super.key, required this.child});

  @override
  State<LifecycleWatcher> createState() => _LifecycleWatcherState();
}

class _LifecycleWatcherState extends State<LifecycleWatcher> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final audioService = context.read<AudioService>();
    if (state == AppLifecycleState.paused) {
      debugPrint("App paused - pausing BGM");
      audioService.pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("App resumed - resuming BGM");
      audioService.resumeBgm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
