import 'package:flutter/material.dart';
import 'base_session.dart';
import 'quiz_session.dart';
import 'you_or_me.dart';
import '../screens/quiz_intro_screen.dart';
import '../screens/quiz_question_screen.dart';
import '../screens/quiz_waiting_screen.dart';
import '../screens/affirmation_intro_screen.dart';
import '../screens/you_or_me_intro_screen.dart';
import '../screens/you_or_me_game_screen.dart';
import '../screens/you_or_me_waiting_screen.dart';
import '../widgets/results_content/classic_quiz_results_content.dart';
import '../widgets/results_content/affirmation_results_content.dart';
import '../widgets/results_content/you_or_me_results_content.dart';

/// Polling behavior for waiting screens
enum PollingType {
  manual, // Show refresh button (Classic Quiz)
  auto, // Auto-poll at intervals (Affirmation, You or Me)
  none, // No polling needed
}

/// Configuration for waiting screen behavior
class WaitingConfig {
  final PollingType pollingType;
  final Duration? pollingInterval; // For auto-polling
  final bool showTimeRemaining; // Show expiration countdown
  final bool isDualSession; // For You or Me (separate sessions per user)
  final String waitingMessage;

  const WaitingConfig({
    required this.pollingType,
    this.pollingInterval,
    this.showTimeRemaining = false,
    this.isDualSession = false,
    required this.waitingMessage,
  });
}

/// Configuration for results screen features
class ResultsConfig {
  final bool showConfetti; // Show confetti animation
  final double? confettiThreshold; // Score threshold for confetti (e.g., 80%)
  final bool showLPBanner; // Show LP earned banner

  const ResultsConfig({
    this.showConfetti = false,
    this.confettiThreshold,
    this.showLPBanner = true,
  });
}

/// Complete configuration for a quest type
/// Defines all screens and behaviors for a specific quest format
class QuestTypeConfig {
  final String formatType; // 'classic', 'affirmation', 'youorme', etc.
  final Widget Function(BaseSession session, {String? branch}) introBuilder;
  final Widget Function(BaseSession session) questionBuilder;
  final Widget Function(BaseSession session) waitingBuilder;
  final Widget Function(BaseSession session) resultsContentBuilder;
  final WaitingConfig waitingConfig;
  final ResultsConfig resultsConfig;

  const QuestTypeConfig({
    required this.formatType,
    required this.introBuilder,
    required this.questionBuilder,
    required this.waitingBuilder,
    required this.resultsContentBuilder,
    required this.waitingConfig,
    required this.resultsConfig,
  });
}

/// Registry for all quest type configurations
/// Call registerDefaults() in main.dart during app initialization
class QuestTypeConfigRegistry {
  static final Map<String, QuestTypeConfig> _configs = {};

  /// Register a quest type configuration
  static void register(String type, QuestTypeConfig config) {
    _configs[type] = config;
  }

  /// Get configuration for a quest type
  static QuestTypeConfig? get(String type) => _configs[type];

  /// Register default quest type configurations
  /// Called from main.dart during app initialization
  static void registerDefaults() {
    // Phase 3: Classic Quiz
    register(
      'classic',
      QuestTypeConfig(
        formatType: 'classic',
        introBuilder: (session, {String? branch}) =>
            QuizIntroScreen(session: session as QuizSession, branch: branch),
        questionBuilder: (session) => QuizQuestionScreen(session: session as QuizSession),
        waitingBuilder: (session) => QuizWaitingScreen(session: session as QuizSession),
        resultsContentBuilder: (session) => ClassicQuizResultsContent(session: session),
        waitingConfig: const WaitingConfig(
          pollingType: PollingType.manual,
          showTimeRemaining: true,
          waitingMessage: 'Waiting for your partner to finish...',
        ),
        resultsConfig: const ResultsConfig(
          showConfetti: true,
          confettiThreshold: 80.0,
          showLPBanner: true,
        ),
      ),
    );

    // Phase 4: Affirmation Quiz (reuses QuizWaitingScreen like Classic)
    register(
      'affirmation',
      QuestTypeConfig(
        formatType: 'affirmation',
        introBuilder: (session, {String? branch}) =>
            AffirmationIntroScreen(session: session as QuizSession, branch: branch),
        questionBuilder: (session) => QuizQuestionScreen(session: session as QuizSession),
        waitingBuilder: (session) => QuizWaitingScreen(session: session as QuizSession),
        resultsContentBuilder: (session) => AffirmationResultsContent(session: session),
        waitingConfig: const WaitingConfig(
          pollingType: PollingType.auto,
          pollingInterval: Duration(seconds: 5),
          showTimeRemaining: false,
          waitingMessage: 'Waiting for your partner...',
        ),
        resultsConfig: const ResultsConfig(
          showConfetti: false,
          showLPBanner: true,
        ),
      ),
    );

    // Phase 5: You or Me
    register(
      'youorme',
      QuestTypeConfig(
        formatType: 'youorme',
        introBuilder: (session, {String? branch}) =>
            YouOrMeIntroScreen(session: session as YouOrMeSession, branch: branch),
        questionBuilder: (session) => YouOrMeGameScreen(session: session as YouOrMeSession),
        waitingBuilder: (session) => YouOrMeWaitingScreen(session: session as YouOrMeSession),
        resultsContentBuilder: (session) => YouOrMeResultsContent(session: session as YouOrMeSession),
        waitingConfig: const WaitingConfig(
          pollingType: PollingType.auto,
          pollingInterval: Duration(seconds: 3),
          showTimeRemaining: false,
          isDualSession: true, // CRITICAL: You or Me uses separate sessions per user
          waitingMessage: 'Waiting for your partner...',
        ),
        resultsConfig: const ResultsConfig(
          showConfetti: false,
          showLPBanner: true,
        ),
      ),
    );
  }
}
