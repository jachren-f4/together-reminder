import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:togetherremind/screens/onboarding_screen.dart';
import 'package:togetherremind/screens/home_screen.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/mock_data_service.dart';
import 'package:togetherremind/services/dev_pairing_service.dart';
import 'package:togetherremind/services/notification_service.dart';
import 'package:togetherremind/services/quiz_question_bank.dart';
import 'package:togetherremind/services/quiz_service.dart';
import 'package:togetherremind/services/daily_pulse_service.dart';
import 'package:togetherremind/services/word_validation_service.dart';
import 'package:togetherremind/config/dev_config.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (with try-catch for duplicate app error)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      print('ℹ️  Firebase already initialized (Dart side)');
    }
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('ℹ️  Firebase already initialized (native side)');
    } else {
      rethrow;
    }
  }

  // Initialize Hive storage
  await StorageService.init();

  // Initialize NotificationService
  await NotificationService.initialize();

  // Initialize Quiz Question Bank
  await QuizQuestionBank().initialize();

  // Initialize Word Validation Service
  await WordValidationService.instance.initialize();

  // 🚀 Auto-inject mock data in debug mode (only on simulators)
  print('🔍 Debug Mode: $kDebugMode');
  final isSimulator = await DevConfig.isSimulator;
  final enableMockPairing = await DevConfig.enableMockPairing;
  print('🔍 Is Simulator: $isSimulator');
  print('🔍 Enable Mock Pairing: $enableMockPairing');
  await MockDataService.injectMockDataIfNeeded();

  // 🔗 Start auto-pairing for dual-emulator setup (dev mode only)
  if (isSimulator && kDebugMode) {
    await DevPairingService().startAutoPairing();
    // Start listening for partner's quiz sessions and Daily Pulses
    await QuizService().startListeningForPartnerSessions();
    await DailyPulseService().startListeningForPartnerPulses();
  }

  runApp(const TogetherRemindApp());
}

class TogetherRemindApp extends StatefulWidget {
  const TogetherRemindApp({super.key});

  @override
  State<TogetherRemindApp> createState() => _TogetherRemindAppState();
}

class _TogetherRemindAppState extends State<TogetherRemindApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final hasPartner = storageService.hasPartner();

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'TogetherRemind',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          // Set the app context for NotificationService
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.setAppContext(context);
          });
          return hasPartner ? const HomeScreen() : const OnboardingScreen();
        },
      ),
    );
  }
}
