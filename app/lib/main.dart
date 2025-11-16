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
import 'package:togetherremind/services/affirmation_quiz_bank.dart';
import 'package:togetherremind/services/you_or_me_service.dart';
import 'package:togetherremind/services/word_validation_service.dart';
import 'package:togetherremind/services/quest_sync_service.dart';
import 'package:togetherremind/services/daily_quest_service.dart';
import 'package:togetherremind/services/quest_type_manager.dart';
import 'package:togetherremind/services/love_point_service.dart';
import 'package:togetherremind/models/daily_quest.dart';
import 'package:togetherremind/config/dev_config.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/utils/logger.dart';
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
      Logger.info('Firebase already initialized (Dart side)');
    }
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      Logger.info('Firebase already initialized (native side)');
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

  // Initialize Affirmation Quiz Bank
  await AffirmationQuizBank().initialize();

  // Initialize You or Me Service (load questions)
  await YouOrMeService().loadQuestions();

  // Initialize Word Validation Service
  await WordValidationService.instance.initialize();

  // 🚀 Auto-inject mock data in debug mode (only on simulators)
  Logger.debug('Debug Mode: $kDebugMode');
  final isSimulator = await DevConfig.isSimulator;
  final enableMockPairing = await DevConfig.enableMockPairing;
  Logger.debug('Is Simulator: $isSimulator');
  Logger.debug('Enable Mock Pairing: $enableMockPairing');
  await MockDataService.injectMockDataIfNeeded();

  // 🔗 Start auto-pairing for dual-emulator setup (dev mode only)
  if (isSimulator && kDebugMode) {
    await DevPairingService().startAutoPairing();
  }

  // 🎯 Generate daily quests if paired
  // Clear old mock quests first (dev mode only)
  if (kDebugMode) {
    await _clearOldMockQuests();
  }
  await _initializeDailyQuests();

  runApp(const TogetherRemindApp());
}

/// Clear old quests from previous test runs (dev mode only)
Future<void> _clearOldMockQuests() async {
  try {
    // Removed verbose logging
    // print('🧹 Clearing old quests...');
    final storage = StorageService();
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    // print('🧹 Date key: $dateKey');

    // Get all quests for today
    final quests = storage.getDailyQuestsForDate(dateKey);
    // print('🧹 Found ${quests.length} quests for $dateKey');

    // Delete ALL quests for today (for testing quest generation)
    // int deletedCount = 0;
    for (final quest in quests) {
      // print('🧹 Deleting quest: ${quest.id} (${quest.type.name})');
      await quest.delete();
      // deletedCount++;
    }

    // print('🧹 Cleared $deletedCount old quests for testing');
  } catch (e) {
    Logger.error('Error clearing quests', error: e);
  }
}

/// Initialize daily quests for today if needed
Future<void> _initializeDailyQuests() async {
  try {
    final storage = StorageService();
    final user = storage.getUser();
    final partner = storage.getPartner();

    // Only generate quests if user has a partner
    if (!storage.hasPartner() || user == null || partner == null) {
      // Removed verbose logging
      // print('ℹ️  Skipping quest generation - no partner yet');
      return;
    }

    // 💰 Start listening for LP awards from partner
    LovePointService.startListeningForLPAwards(
      currentUserId: user.id,
      partnerUserId: partner.pushToken,
    );
    // Removed verbose logging
    // print('💰 LP listener initialized');

    // Initialize services
    final questService = DailyQuestService(storage: storage);
    final syncService = QuestSyncService(
      storage: storage,
    );
    final questTypeManager = QuestTypeManager(
      storage: storage,
      questService: questService,
      syncService: syncService,
    );

    // Sync or generate today's quests
    // First try to load from Firebase
    final synced = await syncService.syncTodayQuests(
      currentUserId: user.id,
      partnerUserId: partner.pushToken, // Using pushToken as partner ID
    );

    List<DailyQuest> quests;
    if (synced) {
      // Loaded from Firebase or already exist locally
      quests = questService.getTodayQuests();
      // Removed verbose logging
      // print('✅ Daily quests loaded: ${quests.length} quests');
    } else {
      // No quests in Firebase - generate new ones
      quests = await questTypeManager.generateDailyQuests(
        currentUserId: user.id,
        partnerUserId: partner.pushToken,
      );
      // Removed verbose logging
      // print('✅ Daily quests generated: ${quests.length} quests');
    }
  } catch (e, stackTrace) {
    Logger.error('Error generating daily quests', error: e, stackTrace: stackTrace);
    // Don't block app startup on quest generation errors
  }
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
          // Set the app context for NotificationService and LovePointService
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.setAppContext(context);
            LovePointService.setAppContext(context);
          });
          return hasPartner ? const HomeScreen() : const OnboardingScreen();
        },
      ),
    );
  }
}
