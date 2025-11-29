import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:togetherremind/screens/onboarding_screen.dart';
import 'package:togetherremind/screens/home_screen.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/mock_data_service.dart';
import 'package:togetherremind/services/dev_data_service.dart';
import 'package:togetherremind/services/dev_pairing_service.dart';
import 'package:togetherremind/services/notification_service.dart';
import 'package:togetherremind/services/quiz_question_bank.dart';
import 'package:togetherremind/services/affirmation_quiz_bank.dart';
import 'package:togetherremind/services/you_or_me_service.dart';
import 'package:togetherremind/services/quest_sync_service.dart';
import 'package:togetherremind/services/daily_quest_service.dart';
import 'package:togetherremind/services/quest_type_manager.dart';
import 'package:togetherremind/services/love_point_service.dart';
import 'package:togetherremind/services/couple_preferences_service.dart';
import 'package:togetherremind/services/steps_feature_service.dart';
import 'package:togetherremind/services/quest_utilities.dart';
import 'package:togetherremind/services/auth_service.dart';
import 'dart:io' show Platform;
import 'package:togetherremind/services/api_client.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/services/haptic_service.dart';
import 'package:togetherremind/models/daily_quest.dart';
import 'package:togetherremind/config/dev_config.dart';
import 'package:togetherremind/config/theme_config.dart';
import 'package:togetherremind/config/supabase_config.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/utils/logger.dart';
import 'package:togetherremind/widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize brand configuration FIRST (before any other initialization)
  BrandLoader().initialize();

  // Set default font from brand configuration
  ThemeConfig().setFont(BrandLoader().config.typography.defaultSerifFont);

  // Initialize Firebase (with try-catch for duplicate app error)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: BrandLoader().firebase.toFirebaseOptions(),
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

  // Initialize Sound and Haptic Services
  await SoundService().initialize();
  await HapticService().initialize();

  // Initialize AuthService with Supabase
  if (SupabaseConfig.isConfigured) {
    await AuthService().initialize(
      supabaseUrl: SupabaseConfig.url,
      supabaseAnonKey: SupabaseConfig.anonKey,
    );
    Logger.info('AuthService initialized with Supabase');

    // Configure API client
    ApiClient().configure(baseUrl: SupabaseConfig.apiUrl);
    Logger.info('ApiClient configured with ${SupabaseConfig.apiUrl}');
  } else {
    Logger.warn('Supabase not configured - auth features disabled. Set SUPABASE_URL and SUPABASE_ANON_KEY.');
  }

  // 🚀 Load real user data in dev mode (bypasses auth but uses real database)
  Logger.debug('Debug Mode: $kDebugMode');
  final isSimulator = await DevConfig.isSimulator;
  Logger.debug('Is Simulator: $isSimulator');

  // Load real data from Supabase instead of mock data
  await DevDataService().loadRealDataIfNeeded();

  // Sync FCM push tokens on every startup (for poke notifications)
  await DevDataService().syncPushTokensOnStartup();

  // Keep mock data service for backward compatibility (currently disabled)
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

    // 💰 LP is now server-authoritative - synced via game status API
    // No Firebase RTDB listener needed

    // ⚙️ Start listening for couple preference updates
    CouplePreferencesService.startListening();
    Logger.debug('Couple preferences listener initialized', service: 'preferences');

    // 👟 Initialize Steps Together feature (iOS only)
    if (!kIsWeb && Platform.isIOS) {
      final coupleId = QuestUtilities.generateCoupleId(user.id, partner.pushToken);
      await StepsFeatureService().initialize(
        coupleId: coupleId,
        userId: user.id,
      );
      Logger.debug('Steps feature service initialized', service: 'steps');

      // Sync steps on app launch (if connected to HealthKit)
      await StepsFeatureService().syncSteps();
      Logger.debug('Initial steps sync completed', service: 'steps');
    }

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

class _TogetherRemindAppState extends State<TogetherRemindApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
    super.didChangeAppLifecycleState(state);

    // Sync steps when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _syncStepsOnResume();
    }
  }

  Future<void> _syncStepsOnResume() async {
    // Only sync on iOS
    if (kIsWeb || !Platform.isIOS) return;

    // Only sync if user is connected
    final storage = StorageService();
    if (!storage.hasPartner()) return;

    final connection = storage.getStepsConnection();
    if (connection == null || !connection.isConnected) return;

    Logger.debug('App resumed - syncing steps', service: 'steps');
    await StepsFeatureService().syncSteps();
  }

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final hasPartner = storageService.hasPartner();

    // Listen to font changes and rebuild the entire app
    return ValueListenableBuilder<SerifFont>(
      valueListenable: ThemeConfig().currentFont,
      builder: (context, currentFont, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: brand.appName,
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) {
              // Set the app context for NotificationService and LovePointService
              WidgetsBinding.instance.addPostFrameCallback((_) {
                NotificationService.setAppContext(context);
                LovePointService.setAppContext(context);
              });

              // Use AuthWrapper if Supabase is configured, otherwise fall back to old behavior
              if (SupabaseConfig.isConfigured) {
                return const AuthWrapper();
              } else {
                // Legacy behavior for development without auth
                return hasPartner ? const HomeScreen() : const OnboardingScreen();
              }
            },
          ),
        );
      },
    );
  }
}
