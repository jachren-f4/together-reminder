import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import '../../../services/storage_service.dart';
import '../../../services/daily_quest_service.dart';
import '../../../services/clipboard_service.dart';
import '../../../services/quest_utilities.dart';
import '../../../services/branch_progression_service.dart';
import '../../../services/quest_type_manager.dart';
import '../../../services/quest_sync_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/love_point_service.dart';
import '../../../models/branch_progression_state.dart';
import '../../../models/linked.dart';
import '../../../models/word_search.dart';
import '../../../config/supabase_config.dart';
import '../../../utils/logger.dart';
import '../../../config/theme_config.dart';
import '../components/debug_section_card.dart';

/// Actions tab for testing tools and data management
class ActionsTab extends StatefulWidget {
  const ActionsTab({Key? key}) : super(key: key);

  @override
  State<ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<ActionsTab> {
  final StorageService _storage = StorageService();
  final DailyQuestService _questService = DailyQuestService(storage: StorageService());
  final BranchProgressionService _branchService = BranchProgressionService();

  bool _isProcessing = false;
  Map<BranchableActivityType, String> _currentBranches = {};
  Map<String, Map<String, dynamic>> _serverGameStatus = {}; // gameType -> status
  Map<String, int> _completedCounts = {}; // gameType -> total completed count
  List<Map<String, dynamic>> _availableGames = []; // what's available to play next

  // Clear storage checkboxes
  bool _clearDailyQuests = true;
  bool _clearQuizSessions = true;
  bool _clearLpTransactions = true;
  bool _clearProgressionState = false;
  bool _clearBranchProgressionState = false;
  bool _clearAppliedLpAwards = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBranches();
    _loadServerGameStatus();
  }

  Future<void> _loadServerGameStatus({String? dateKey}) async {
    try {
      final authService = AuthService();
      final date = dateKey ?? QuestUtilities.getTodayDateKey();
      final uri = Uri.parse('${SupabaseConfig.apiUrl}/api/sync/game/status?date=$date');
      final headers = await authService.getAuthHeaders();

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final games = data['games'] as List? ?? [];

        final status = <String, Map<String, dynamic>>{};
        for (final game in games) {
          final type = game['type'] as String?;
          // Only store the first (most recent) entry per type
          // Server returns matches in created_at DESC order
          if (type != null && !status.containsKey(type)) {
            status[type] = Map<String, dynamic>.from(game);
          }
        }

        // Extract completed counts
        final completedCounts = <String, int>{};
        final countsData = data['completedCounts'] as Map<String, dynamic>? ?? {};
        for (final entry in countsData.entries) {
          completedCounts[entry.key] = (entry.value as num?)?.toInt() ?? 0;
        }

        // Extract available games
        final available = (data['available'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (mounted) {
          setState(() {
            _serverGameStatus = status;
            _completedCounts = completedCounts;
            _availableGames = available;
          });
        }
      }
    } catch (e) {
      Logger.warn('Error loading server game status: $e', service: 'debug');
    }
  }

  Future<void> _loadCurrentBranches() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null || partner == null) return;

    final coupleId = QuestUtilities.generateCoupleId(user.id, partner.pushToken);
    final branches = <BranchableActivityType, String>{};

    for (final activityType in [
      BranchableActivityType.classicQuiz,
      BranchableActivityType.affirmation,
      BranchableActivityType.youOrMe,
    ]) {
      final branch = await _branchService.getCurrentBranch(
        coupleId: coupleId,
        activityType: activityType,
      );
      branches[activityType] = branch;
    }

    if (mounted) {
      setState(() => _currentBranches = branches);
    }
  }

  Future<void> _cycleBranch(BranchableActivityType activityType, {bool regenerateQuests = true}) async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null || partner == null) return;

    setState(() => _isProcessing = true);

    try {
      final coupleId = QuestUtilities.generateCoupleId(user.id, partner.pushToken);

      // Complete the activity to advance to next branch
      await _branchService.completeActivity(
        coupleId: coupleId,
        activityType: activityType,
      );

      // Reload current branches
      await _loadCurrentBranches();

      // Regenerate today's quests with new branch content
      if (regenerateQuests) {
        await _regenerateDailyQuests(user.id, partner.pushToken);
      }

      Logger.success(
        'Advanced ${activityType.name} to ${_currentBranches[activityType]}',
        service: 'debug',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${activityType.name} → ${_currentBranches[activityType]} (quests regenerated)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error cycling branch', error: e, service: 'debug');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Regenerate today's daily quests with current branch settings
  Future<void> _regenerateDailyQuests(String userId, String partnerId) async {
    try {
      Logger.info('Regenerating daily quests with new branch content...', service: 'debug');

      // Get today's date key
      final dateKey = QuestUtilities.getTodayDateKey();

      // Get existing quests to find their content IDs (quiz sessions to delete)
      final existingQuests = _questService.getTodayQuests();
      final contentIdsToDelete = existingQuests
          .where((q) => q.contentId != null)
          .map((q) => q.contentId!)
          .toList();

      // Delete related quiz sessions
      for (final contentId in contentIdsToDelete) {
        _storage.deleteQuizSession(contentId);
        Logger.debug('Deleted quiz session: $contentId', service: 'debug');
      }

      // Clear today's quests from storage
      final questsToDelete = _storage.dailyQuestsBox.values
          .where((q) => q.dateKey == dateKey)
          .toList();
      for (final quest in questsToDelete) {
        await quest.delete();
      }
      Logger.debug('Cleared ${questsToDelete.length} quests for $dateKey', service: 'debug');

      // Regenerate quests using QuestTypeManager
      final questTypeManager = QuestTypeManager(
        storage: _storage,
        questService: _questService,
        syncService: QuestSyncService(storage: _storage),
        branchService: _branchService,
      );

      final newQuests = await questTypeManager.generateDailyQuests(
        currentUserId: userId,
        partnerUserId: partnerId,
      );

      Logger.success('Regenerated ${newQuests.length} quests with new branch content', service: 'debug');
    } catch (e) {
      Logger.error('Error regenerating daily quests', error: e, service: 'debug');
      rethrow;
    }
  }

  /// Cycle all three activity types (Classic Quiz, Affirmation, You or Me) at once
  Future<void> _cycleAllBranches() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null || partner == null) return;

    setState(() => _isProcessing = true);

    try {
      final coupleId = QuestUtilities.generateCoupleId(user.id, partner.pushToken);

      for (final activityType in [
        BranchableActivityType.classicQuiz,
        BranchableActivityType.affirmation,
        BranchableActivityType.youOrMe,
      ]) {
        await _branchService.completeActivity(
          coupleId: coupleId,
          activityType: activityType,
        );
      }

      // Reload current branches
      await _loadCurrentBranches();

      // Regenerate quests once after all branches are cycled
      await _regenerateDailyQuests(user.id, partner.pushToken);

      Logger.success('Advanced all branches', service: 'debug');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All branches advanced (quests regenerated)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error cycling all branches', error: e, service: 'debug');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Complete today's games via API (submits dummy answers for both users), then cycle branch
  /// Marks quests as completed and advances branch WITHOUT regenerating new quests
  Future<void> _completeAndCycleBranch(BranchableActivityType activityType) async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    if (user == null || partner == null) return;

    setState(() => _isProcessing = true);

    try {
      // Get game types to complete for this activity
      final gameTypes = _getGameTypesForActivity(activityType);

      // Call API to complete games with dummy answers for both users
      await _completeGamesViaApi(gameTypes);

      // Mark local quests as completed
      // Note: quest.type.name is 'quiz' or 'youOrMe', formatType is 'classic'/'affirmation'/'youOrMe'
      final quests = _questService.getTodayQuests();
      final formatTypes = _getFormatTypesForActivity(activityType);
      for (final quest in quests) {
        final matchesFormat = formatTypes.contains(quest.formatType);
        if (matchesFormat && !quest.isCompleted) {
          quest.status = 'completed';
          quest.completedAt = DateTime.now();
          await _storage.saveDailyQuest(quest);
          Logger.info('Marked quest ${quest.id} (${quest.formatType}) as completed', service: 'debug');
        }
      }

      // Cycle the branch WITHOUT regenerating quests (keep them completed)
      final coupleId = QuestUtilities.generateCoupleId(user.id, partner.pushToken);
      await _branchService.completeActivity(
        coupleId: coupleId,
        activityType: activityType,
      );

      // Reload current branches to update UI
      await _loadCurrentBranches();

      // Sync LP from server (the API awards LP when completing games)
      await LovePointService.fetchAndSyncFromServer();

      Logger.success(
        'Completed ${activityType.name} and advanced to ${_currentBranches[activityType]}',
        service: 'debug',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${activityType.name} completed → ${_currentBranches[activityType]}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error completing and cycling branch', error: e, service: 'debug');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Complete all games via API - server handles EVERYTHING:
  /// - Creates matches
  /// - Completes with auto-generated answers
  /// - Awards LP
  /// - Advances branch progression
  /// Client just calls API and displays result
  Future<void> _completeAndCycleAllBranches() async {
    setState(() => _isProcessing = true);

    try {
      // Server does everything - includes linked and word_search now
      final result = await _completeGamesViaApi([
        'classic', 'affirmation', 'you_or_me', 'linked', 'word_search'
      ]);

      // Refresh display from server
      await _loadServerGameStatus();

      // Sync LP to local storage (server already awarded it)
      await LovePointService.fetchAndSyncFromServer();

      Logger.success('Server completed all games and advanced branches', service: 'debug');

      if (mounted && result != null) {
        final totalLp = result['totalLp'] ?? 0;
        final completedCount = (result['completed'] as List?)?.length ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completed $completedCount games! Total LP: $totalLp'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error('Error completing games via server', error: e, service: 'debug');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Call dev API to complete games - server handles everything
  /// Returns the full response including totalLp and branches
  Future<Map<String, dynamic>?> _completeGamesViaApi(List<String> gameTypes, {String? dateKey}) async {
    final authService = AuthService();

    try {
      final uri = Uri.parse('${SupabaseConfig.apiUrl}/api/dev/complete-games');
      final headers = await authService.getAuthHeaders();

      final response = await http.post(
        uri,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'localDate': dateKey ?? QuestUtilities.getTodayDateKey(),
          'gameTypes': gameTypes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final completed = data['completed'] as List? ?? [];
        Logger.success(
          'Completed ${completed.length} games via API: ${completed.map((c) => c['gameType']).join(', ')}',
          service: 'debug',
        );
        return data;
      } else if (response.statusCode == 403) {
        Logger.warn('Dev bypass not enabled on server', service: 'debug');
        return null;
      } else {
        Logger.warn('API complete-games failed: ${response.statusCode} ${response.body}', service: 'debug');
        return null;
      }
    } catch (e) {
      Logger.warn('Error calling complete-games API: $e', service: 'debug');
      return null;
    }
  }

  /// Get API game type names for an activity type
  List<String> _getGameTypesForActivity(BranchableActivityType activityType) {
    switch (activityType) {
      case BranchableActivityType.classicQuiz:
        return ['classic'];
      case BranchableActivityType.affirmation:
        return ['affirmation'];
      case BranchableActivityType.youOrMe:
        return ['you_or_me'];
      default:
        return [];
    }
  }

  /// Get formatType values for an activity type (used to match quests)
  List<String> _getFormatTypesForActivity(BranchableActivityType activityType) {
    switch (activityType) {
      case BranchableActivityType.classicQuiz:
        return ['classic'];
      case BranchableActivityType.affirmation:
        return ['affirmation'];
      case BranchableActivityType.youOrMe:
        return ['youOrMe'];
      default:
        return [];
    }
  }

  List<String> _getQuestTypesForActivity(BranchableActivityType activityType) {
    switch (activityType) {
      case BranchableActivityType.classicQuiz:
        return ['classicQuiz'];
      case BranchableActivityType.affirmation:
        return ['affirmation'];
      case BranchableActivityType.youOrMe:
        return ['youOrMe'];
      default:
        return [];
    }
  }

  Future<void> _resetUserData() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset User Data?'),
        content: const Text(
          'This will clear your local user and partner data.\n\n'
          'On next app restart, the app will reload real data from Supabase.\n\n'
          'Useful for testing the dev auth bypass with fresh database content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      Logger.info('Resetting user data (will reload from Supabase on restart)', service: 'debug');

      // Clear user and partner boxes
      await _storage.userBox.clear();
      await _storage.partnerBox.clear();

      Logger.success('User data reset', service: 'debug');

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('User Data Reset'),
            content: const Text(
              'User and partner data cleared.\n\n'
              'Restart the app to reload from Supabase.\n\n'
              'The app will automatically fetch real user names and couple data from the database.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close alert
                  Navigator.of(context).pop(); // Close debug dialog
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Logger.error('Error resetting user data', error: e, service: 'debug');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _clearLocalStorage() async {
    setState(() => _isProcessing = true);

    try {
      Logger.info('Clearing local storage only (Firebase data NOT cleared)', service: 'debug');

      if (_clearDailyQuests) {
        await _storage.dailyQuestsBox.clear();
        await _storage.dailyQuestCompletionsBox.clear();
        Logger.success('Daily quests cleared', service: 'debug');
      }

      if (_clearQuizSessions) {
        await _storage.quizSessionsBox.clear();
        Logger.success('Quiz sessions cleared', service: 'debug');
      }

      if (_clearLpTransactions) {
        await _storage.transactionsBox.clear();
        Logger.success('LP transactions cleared', service: 'debug');
      }

      if (_clearProgressionState) {
        await _storage.quizProgressionStatesBox.clear();
        Logger.success('Progression states cleared', service: 'debug');
      }

      if (_clearBranchProgressionState) {
        await _storage.branchProgressionBox.clear();
        Logger.success('Branch progression states cleared', service: 'debug');
      }

      if (_clearAppliedLpAwards) {
        final metadataBox = Hive.box('app_metadata');
        await metadataBox.delete('applied_lp_awards');
        Logger.success('Applied LP awards cleared', service: 'debug');
      }

      Logger.success('Local storage cleared', service: 'debug');

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Storage Cleared'),
            content: const Text(
              'Local storage has been cleared.\n\n'
              'Please manually restart the app to reinitialize with fresh data.\n\n'
              'On Android: Close app and relaunch\n'
              'On Web: Refresh the page',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close alert
                  Navigator.of(context).pop(); // Close debug dialog
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Logger.error('Error clearing local storage', error: e, service: 'debug');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _copyCurrentState() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final quests = _questService.getTodayQuests();
    final sessions = _storage.quizSessionsBox.values.toList();
    final transactions = _storage.transactionsBox.values.toList();
    final metadataBox = Hive.box('app_metadata');

    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'user': user != null ? {'id': user.id, 'name': user.name} : null,
      'partner': partner != null ? {'id': partner.pushToken, 'name': partner.name} : null,
      'quests': quests.map((q) => <String, dynamic>{
          'id': q.id,
          'type': q.type.name,
          'contentId': q.contentId,
          'status': q.status,
          'isCompleted': q.isCompleted,
        }).toList(),
      'sessions': sessions.length,
      'transactions': transactions.length,
      'appliedLpAwards': metadataBox.get('applied_lp_awards', defaultValue: <String>[]).length,
    };

    final jsonString = JsonEncoder.withIndent('  ').convert(data);
    await ClipboardService.copyToClipboard(
      context,
      jsonString,
      message: 'Current state copied as JSON',
    );
  }

  Future<void> _copyDebugReport() async {
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final quests = _questService.getTodayQuests();
    final sessions = _storage.quizSessionsBox.values.toList();

    final report = StringBuffer();
    report.writeln('=== TOGETHERREMIND DEBUG REPORT ===');
    report.writeln('Generated: ${DateTime.now().toIso8601String()}');
    report.writeln('');
    report.writeln('--- DEVICE INFO ---');
    report.writeln('User ID: ${user?.id ?? "Not set"}');
    report.writeln('Partner ID: ${partner?.pushToken ?? "Not set"}');
    if (user != null && partner != null) {
      report.writeln('Couple ID: ${QuestUtilities.generateCoupleId(user.id, partner.pushToken)}');
    }
    report.writeln('');
    report.writeln('--- QUEST STATUS ---');
    report.writeln('Today\'s Quests: ${quests.length}');
    for (var i = 0; i < quests.length; i++) {
      final q = quests[i];
      report.writeln('  Quest ${i + 1}:');
      report.writeln('    ID: ${q.id}');
      report.writeln('    Type: ${q.type.name}');
      report.writeln('    Content ID: ${q.contentId ?? "N/A"}');
      report.writeln('    Status: ${q.status}');
      report.writeln('    Completed: ${q.isCompleted}');
    }
    report.writeln('');
    report.writeln('--- STORAGE STATS ---');
    report.writeln('Quiz Sessions: ${sessions.length}');
    report.writeln('LP Transactions: ${_storage.transactionsBox.length}');
    report.writeln('Applied LP Awards: ${Hive.box('app_metadata').get('applied_lp_awards', defaultValue: <String>[]).length}');
    report.writeln('');
    report.writeln('=== END REPORT ===');

    await ClipboardService.copyToClipboard(
      context,
      report.toString(),
      message: 'Debug report copied',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Reset User Data
          DebugSectionCard(
            title: '🔄 RESET USER DATA',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Dev Auth Bypass Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Clear local user/partner data to force reload from Supabase.\n\n'
                        'Useful for:\n'
                        '• Testing with updated database content\n'
                        '• Simulating fresh user setup\n'
                        '• Resetting after manual database changes',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _resetUserData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset User Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),

          // Clear Local Storage
          DebugSectionCard(
            title: '🗑️ CLEAR LOCAL STORAGE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCheckbox(
                  'Daily Quests',
                  _clearDailyQuests,
                  (value) => setState(() => _clearDailyQuests = value ?? false),
                  '${_storage.dailyQuestsBox.length} items',
                ),
                _buildCheckbox(
                  'Quiz Sessions',
                  _clearQuizSessions,
                  (value) => setState(() => _clearQuizSessions = value ?? false),
                  '${_storage.quizSessionsBox.length} items',
                ),
                _buildCheckbox(
                  'LP Transactions',
                  _clearLpTransactions,
                  (value) => setState(() => _clearLpTransactions = value ?? false),
                  '${_storage.transactionsBox.length} items',
                ),
                _buildCheckbox(
                  'Quiz Progression',
                  _clearProgressionState,
                  (value) => setState(() => _clearProgressionState = value ?? false),
                  '${_storage.quizProgressionStatesBox.length} states',
                ),
                _buildCheckbox(
                  'Branch Progression',
                  _clearBranchProgressionState,
                  (value) => setState(() => _clearBranchProgressionState = value ?? false),
                  '${_storage.branchProgressionBox.length} states',
                ),
                _buildCheckbox(
                  'Applied LP Awards',
                  _clearAppliedLpAwards,
                  (value) => setState(() => _clearAppliedLpAwards = value ?? false),
                  '${Hive.box('app_metadata').get('applied_lp_awards', defaultValue: <String>[]).length} IDs',
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _clearLocalStorage,
                  icon: const Icon(Icons.delete_sweep),
                  label: Text(_isProcessing ? 'Clearing...' : 'Clear Selected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Requires manual app restart after clearing',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Copy to Clipboard
          DebugSectionCard(
            title: '📋 COPY TO CLIPBOARD',
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _copyCurrentState,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Current State (JSON)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: BorderSide(color: Colors.grey.shade300, width: 2),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _copyDebugReport,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Debug Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
              ],
            ),
          ),

          // Theme Settings
          DebugSectionCard(
            title: '🎨 THEME SETTINGS',
            child: ValueListenableBuilder<SerifFont>(
              valueListenable: ThemeConfig().currentFont,
              builder: (context, currentFont, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Serif Font (Headlines)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current: ${ThemeConfig().currentFontName}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...SerifFont.values.map((font) {
                      final isSelected = font == currentFont;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ElevatedButton(
                          onPressed: () {
                            ThemeConfig().setFont(font);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Font changed to ${font.displayName}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected ? Colors.black : Colors.white,
                            foregroundColor: isSelected ? Colors.white : Colors.black,
                            side: BorderSide(
                              color: isSelected ? Colors.black : Colors.grey.shade300,
                              width: 2,
                            ),
                            minimumSize: const Size(double.infinity, 56),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      font.displayName,
                                      style: font.getTextStyle().copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle, size: 16, color: Colors.white),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                font.description,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected ? Colors.white70 : Colors.grey.shade600,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),

          // Today's Quest Branches
          DebugSectionCard(
            title: '📋 TODAY\'S QUEST BRANCHES',
            child: _buildTodayQuestBranches(),
          ),

          // Branch Cycling
          DebugSectionCard(
            title: '🔄 BRANCH CYCLING',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, size: 14, color: Colors.purple.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Test Therapeutic Branches',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cycle through branches to test "Deeper" badge:\n'
                        '• Branches 1-2: Casual (no badge)\n'
                        '• Branches 3-5: Therapeutic (Deeper badge)\n\n'
                        '✓ Quests auto-regenerate with new branch content',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bulk actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _cycleAllBranches,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Skip All →',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _completeAndCycleAllBranches,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Complete & Next All →',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Individual branch controls
                Text(
                  'Individual Branches:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                // Classic Quiz
                _buildBranchCycleRow(
                  'Classic Quiz',
                  BranchableActivityType.classicQuiz,
                  _currentBranches[BranchableActivityType.classicQuiz] ?? 'loading...',
                ),
                const SizedBox(height: 8),
                // Affirmation
                _buildBranchCycleRow(
                  'Affirmation',
                  BranchableActivityType.affirmation,
                  _currentBranches[BranchableActivityType.affirmation] ?? 'loading...',
                ),
                const SizedBox(height: 8),
                // You or Me
                _buildBranchCycleRow(
                  'You or Me',
                  BranchableActivityType.youOrMe,
                  _currentBranches[BranchableActivityType.youOrMe] ?? 'loading...',
                ),
              ],
            ),
          ),

          // Side Quests Debug (Linked & Word Search)
          DebugSectionCard(
            title: '🧩 SIDE QUESTS DEBUG',
            child: _buildSideQuestsDebug(),
          ),
        ],
      ),
    );
  }

  /// Build debug info for Linked and Word Search matches
  Widget _buildSideQuestsDebug() {
    final user = _storage.getUser();
    final linkedMatch = _storage.getActiveLinkedMatch();
    final wordSearchMatch = _storage.getActiveWordSearchMatch();
    final allLinkedMatches = _storage.getAllLinkedMatches();
    final allWordSearchMatches = _storage.getAllWordSearchMatches();

    // Build comprehensive debug data
    final debugData = {
      'timestamp': DateTime.now().toIso8601String(),
      'userId': user?.id,
      'linked': {
        'activeMatch': linkedMatch != null ? _linkedMatchToJson(linkedMatch) : null,
        'totalMatches': allLinkedMatches.length,
        'activeCount': allLinkedMatches.where((m) => m.status == 'active').length,
        'completedCount': allLinkedMatches.where((m) => m.status == 'completed').length,
        'allMatches': allLinkedMatches.map(_linkedMatchToJson).toList(),
      },
      'wordSearch': {
        'activeMatch': wordSearchMatch != null ? _wordSearchMatchToJson(wordSearchMatch) : null,
        'totalMatches': allWordSearchMatches.length,
        'activeCount': allWordSearchMatches.where((m) => m.status == 'active').length,
        'completedCount': allWordSearchMatches.where((m) => m.status == 'completed').length,
        'allMatches': allWordSearchMatches.map(_wordSearchMatchToJson).toList(),
      },
    };

    final debugJson = const JsonEncoder.withIndent('  ').convert(debugData);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Copy All Button
        ElevatedButton.icon(
          onPressed: () async {
            await ClipboardService.copyToClipboard(
              context,
              debugJson,
              message: 'Side quests debug data copied',
            );
          },
          icon: const Icon(Icons.copy, size: 14),
          label: const Text('Copy All Side Quest Data'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),

        // Linked Section
        _buildGameDebugCard(
          title: 'LINKED',
          emoji: '🔗',
          color: Colors.teal,
          activeMatch: linkedMatch,
          allMatches: allLinkedMatches,
          matchToJson: (m) => _linkedMatchToJson(m as LinkedMatch),
          getStatusInfo: (m) => _getLinkedStatusInfo(m as LinkedMatch, user?.id ?? ''),
        ),
        const SizedBox(height: 12),

        // Word Search Section
        _buildGameDebugCard(
          title: 'WORD SEARCH',
          emoji: '🔍',
          color: Colors.indigo,
          activeMatch: wordSearchMatch,
          allMatches: allWordSearchMatches,
          matchToJson: (m) => _wordSearchMatchToJson(m as WordSearchMatch),
          getStatusInfo: (m) => _getWordSearchStatusInfo(m as WordSearchMatch, user?.id ?? ''),
        ),
      ],
    );
  }

  Widget _buildGameDebugCard({
    required String title,
    required String emoji,
    required MaterialColor color,
    required dynamic activeMatch,
    required List<dynamic> allMatches,
    required Map<String, dynamic> Function(dynamic) matchToJson,
    required Map<String, String> Function(dynamic) getStatusInfo,
  }) {
    final activeCount = allMatches.where((m) => m.status == 'active').length;
    final completedCount = allMatches.where((m) => m.status == 'completed').length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color.shade700,
                ),
              ),
              const Spacer(),
              // Counts
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$activeCount active / $completedCount done',
                  style: TextStyle(fontSize: 9, color: color.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (activeMatch == null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'No active match in Hive',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ] else ...[
            // Active match details
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status info
                  ...getStatusInfo(activeMatch).entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            '${e.key}:',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Copy active match button
            OutlinedButton.icon(
              onPressed: () async {
                final json = const JsonEncoder.withIndent('  ').convert(matchToJson(activeMatch));
                await ClipboardService.copyToClipboard(
                  context,
                  json,
                  message: '$title active match copied',
                );
              },
              icon: Icon(Icons.copy, size: 12, color: color.shade700),
              label: Text(
                'Copy Active Match JSON',
                style: TextStyle(fontSize: 10, color: color.shade700),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.shade300),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _linkedMatchToJson(LinkedMatch match) {
    return {
      'matchId': match.matchId,
      'puzzleId': match.puzzleId,
      'status': match.status,
      'currentTurnUserId': match.currentTurnUserId,
      'turnNumber': match.turnNumber,
      'lockedCellCount': match.lockedCellCount,
      'totalAnswerCells': match.totalAnswerCells,
      'progressPercent': match.progressPercent,
      'player1Id': match.player1Id,
      'player2Id': match.player2Id,
      'player1Score': match.player1Score,
      'player2Score': match.player2Score,
      'boardState': match.boardState,
      'currentRack': match.currentRack,
      'createdAt': match.createdAt.toIso8601String(),
      'completedAt': match.completedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _wordSearchMatchToJson(WordSearchMatch match) {
    return {
      'matchId': match.matchId,
      'puzzleId': match.puzzleId,
      'status': match.status,
      'currentTurnUserId': match.currentTurnUserId,
      'turnNumber': match.turnNumber,
      'wordsFoundThisTurn': match.wordsFoundThisTurn,
      'totalWordsFound': match.totalWordsFound,
      'progressPercent': match.progressPercent,
      'player1Id': match.player1Id,
      'player2Id': match.player2Id,
      'player1WordsFound': match.player1WordsFound,
      'player2WordsFound': match.player2WordsFound,
      'player1Score': match.player1Score,
      'player2Score': match.player2Score,
      'foundWords': match.foundWords.map((fw) => {
        'word': fw.word,
        'foundBy': fw.foundByUserId,
        'turnNumber': fw.turnNumber,
        'colorIndex': fw.colorIndex,
      }).toList(),
      'createdAt': match.createdAt.toIso8601String(),
      'completedAt': match.completedAt?.toIso8601String(),
    };
  }

  Map<String, String> _getLinkedStatusInfo(LinkedMatch match, String userId) {
    final isMyTurn = match.currentTurnUserId == userId;
    final isPlayer1 = match.player1Id == userId;

    return {
      'Match ID': match.matchId.substring(0, 8) + '...',
      'Puzzle ID': match.puzzleId,
      'Status': match.status,
      'Progress': '${match.lockedCellCount}/${match.totalAnswerCells} (${match.progressPercent}%)',
      'Turn': isMyTurn ? 'YOUR TURN' : 'Partner\'s turn',
      'Current Turn ID': match.currentTurnUserId ?? 'null',
      'You are': isPlayer1 ? 'Player 1' : 'Player 2',
      'Player 1 ID': match.player1Id ?? 'null',
      'Player 2 ID': match.player2Id ?? 'null',
      'Scores': 'P1: ${match.player1Score} / P2: ${match.player2Score}',
      'Current Rack': match.currentRack.isEmpty ? '(empty)' : match.currentRack.join(', '),
      'Board State': '${match.boardState.length} cells filled',
    };
  }

  Map<String, String> _getWordSearchStatusInfo(WordSearchMatch match, String userId) {
    final isMyTurn = match.currentTurnUserId == userId;
    final isPlayer1 = match.player1Id == userId;

    return {
      'Match ID': match.matchId.substring(0, 8) + '...',
      'Puzzle ID': match.puzzleId,
      'Status': match.status,
      'Progress': '${match.totalWordsFound}/12 (${match.progressPercent}%)',
      'Turn': isMyTurn ? 'YOUR TURN' : 'Partner\'s turn',
      'Current Turn ID': match.currentTurnUserId ?? 'null',
      'Words This Turn': '${match.wordsFoundThisTurn}/3',
      'You are': isPlayer1 ? 'Player 1' : 'Player 2',
      'Player 1 ID': match.player1Id,
      'Player 2 ID': match.player2Id,
      'Words Found': 'P1: ${match.player1WordsFound} / P2: ${match.player2WordsFound}',
      'Scores': 'P1: ${match.player1Score} / P2: ${match.player2Score}',
      'Found Words': match.foundWords.map((fw) => fw.word).join(', '),
    };
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?> onChanged, String count) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchCycleRow(String label, BranchableActivityType activityType, String currentBranch) {
    // Check if it's a therapeutic branch
    final isTherapeutic = ['connection', 'attachment', 'growth'].contains(currentBranch.toLowerCase());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: isTherapeutic
            ? Border.all(color: Colors.purple.shade300, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isTherapeutic ? Colors.purple : Colors.grey.shade600,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            currentBranch,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isTherapeutic) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            color: Colors.black,
                            child: const Text(
                              'DEEPER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : () => _cycleBranch(activityType),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: BorderSide(color: Colors.purple.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'Skip →',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : () => _completeAndCycleBranch(activityType),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const Text(
                    'Complete & Next →',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build widget showing today's quest branches with full debug info
  Widget _buildTodayQuestBranches() {
    final quests = _questService.getTodayQuests();
    final user = _storage.getUser();
    final partner = _storage.getPartner();
    final dateKey = QuestUtilities.getTodayDateKey();

    // Get LP data
    final currentLp = user?.lovePoints ?? 0;
    final transactions = _storage.transactionsBox.values.toList();
    final todayTransactions = transactions.where((t) =>
      t.timestamp.toIso8601String().startsWith(dateKey)
    ).toList();

    // Build debug data for clipboard
    final debugData = {
      'timestamp': DateTime.now().toIso8601String(),
      'dateKey': dateKey,
      'userId': user?.id,
      'partnerId': partner?.pushToken,
      'coupleId': user != null && partner != null
          ? QuestUtilities.generateCoupleId(user.id, partner.pushToken)
          : null,
      'lovePoints': {
        'currentTotal': currentLp,
        'totalTransactions': transactions.length,
        'todayTransactions': todayTransactions.length,
        'todayLpEarned': todayTransactions.fold<int>(0, (sum, t) => sum + t.amount),
      },
      'branchProgression': _currentBranches.map((k, v) => MapEntry(k.name, v)),
      'questCount': quests.length,
      'quests': quests.map((q) => <String, dynamic>{
          'id': q.id,
          'type': q.type.name,
          'formatType': q.formatType,
          'quizName': q.quizName,
          'branch': q.branch,
          'contentId': q.contentId,
          'status': q.status,
          'isCompleted': q.isCompleted,
          'dateKey': q.dateKey,
          'createdAt': q.createdAt?.toIso8601String(),
          'completedAt': q.completedAt?.toIso8601String(),
        }).toList(),
    };

    final debugJson = const JsonEncoder.withIndent('  ').convert(debugData);

    if (quests.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'No quests for today',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          _buildCopyDebugButton(debugJson),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Total Completed Summary
        _buildCompletedCountsSummary(),
        const SizedBox(height: 12),

        // Available Now Section
        _buildAvailableGamesSection(),
        const SizedBox(height: 12),

        // Copy debug button for completed quests
        _buildCopyDebugButton(debugJson, label: 'Copy Completed Quest Data'),
        const SizedBox(height: 12),

        // Quest cards with detailed info (completed/active)
        for (final quest in quests)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: quest.isCompleted ? Colors.green.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: quest.isCompleted
                  ? Border.all(color: Colors.green.shade300, width: 1)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with type icon and name
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _getQuestTypeColor(quest.formatType ?? quest.type.name),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          _getQuestTypeEmoji(quest.formatType ?? quest.type.name),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.quizName ?? _getQuestTypeName(quest.formatType ?? quest.type.name),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              if (quest.branch != null) ...[
                                _buildBranchBadge(quest.branch!),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                quest.isCompleted ? '✓ Completed' : 'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: quest.isCompleted ? Colors.green : Colors.grey.shade600,
                                  fontWeight: quest.isCompleted ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Detailed debug info
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show server quiz ID prominently
                      _buildServerQuizInfo(quest.formatType ?? quest.type.name),
                      const Divider(height: 8),
                      _buildDebugRow('ID', quest.id),
                      _buildDebugRow('Type', quest.type.name),
                      _buildDebugRow('Format', quest.formatType ?? '-'),
                      _buildDebugRow('Branch', quest.branch ?? '-'),
                      _buildDebugRow('ContentID', quest.contentId ?? '-'),
                      _buildDebugRow('Status', quest.status ?? '-'),
                      _buildDebugRow('DateKey', quest.dateKey ?? '-'),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Shows server-side quiz info: quizId, branch, status
  Widget _buildServerQuizInfo(String formatType) {
    // Map formatType to server game type
    String serverType;
    switch (formatType.toLowerCase()) {
      case 'classic':
        serverType = 'classic';
        break;
      case 'affirmation':
        serverType = 'affirmation';
        break;
      case 'youorme':
        serverType = 'you_or_me';
        break;
      default:
        serverType = formatType;
    }

    final gameStatus = _serverGameStatus[serverType];

    if (gameStatus == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'No server match yet',
          style: TextStyle(fontSize: 10, color: Colors.orange),
        ),
      );
    }

    final quizId = gameStatus['quizId'] as String? ?? '-';
    final branch = gameStatus['branch'] as String? ?? '-';
    final status = gameStatus['status'] as String? ?? '-';

    // Extract quiz number from quizId (e.g., "quiz_001" -> "1", "affirmation_003" -> "3")
    final quizNum = _extractQuizNumber(quizId);

    return Row(
      children: [
        // Prominent quiz number badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '#$quizNum',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quizId,
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '$branch • $status',
                style: TextStyle(
                  fontSize: 9,
                  color: status == 'completed' ? Colors.green : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _extractQuizNumber(String quizId) {
    // Extract number from patterns like "quiz_001", "affirmation_003", "youorme_001"
    final match = RegExp(r'_(\d+)').firstMatch(quizId);
    if (match != null) {
      return int.parse(match.group(1)!).toString(); // Remove leading zeros
    }
    return quizId;
  }

  /// Builds the Total Completed summary showing counts per game type
  Widget _buildCompletedCountsSummary() {
    if (_completedCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'TOTAL COMPLETED (All Time)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildCountChip('Classic', _completedCounts['classic'] ?? 0, Colors.purple),
              _buildCountChip('Affirmation', _completedCounts['affirmation'] ?? 0, Colors.pink),
              _buildCountChip('You/Me', _completedCounts['you_or_me'] ?? 0, Colors.orange),
              _buildCountChip('Linked', _completedCounts['linked'] ?? 0, Colors.teal),
              _buildCountChip('WordSearch', _completedCounts['word_search'] ?? 0, Colors.indigo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, int count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Available Now section showing what's next to play
  Widget _buildAvailableGamesSection() {
    if (_availableGames.isEmpty) {
      return const SizedBox.shrink();
    }

    final availableJson = const JsonEncoder.withIndent('  ').convert({
      'available': _availableGames,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'AVAILABLE NOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Copy button for available games
              InkWell(
                onTap: () async {
                  await ClipboardService.copyToClipboard(
                    context,
                    availableJson,
                    message: 'Available games data copied',
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 12, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: TextStyle(fontSize: 10, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final game in _availableGames)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getGameTypeColor(game['type'] as String),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatGameType(game['type'] as String),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Quiz info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game['nextQuizId'] as String? ?? '-',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '${game['branch']} • ${game['completedInBranch']}/${game['totalInBranch']} in branch',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active indicator
                  if (game['hasActiveMatch'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  MaterialColor _getGameTypeColor(String type) {
    switch (type) {
      case 'classic':
        return Colors.purple;
      case 'affirmation':
        return Colors.pink;
      case 'you_or_me':
        return Colors.orange;
      case 'linked':
        return Colors.teal;
      case 'word_search':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatGameType(String type) {
    switch (type) {
      case 'classic':
        return 'Classic';
      case 'affirmation':
        return 'Affirm';
      case 'you_or_me':
        return 'You/Me';
      case 'linked':
        return 'Linked';
      case 'word_search':
        return 'WordSearch';
      default:
        return type;
    }
  }

  Widget _buildCopyDebugButton(String debugJson, {String label = 'Copy Quest Debug Data'}) {
    return ElevatedButton.icon(
      onPressed: () async {
        await ClipboardService.copyToClipboard(
          context,
          debugJson,
          message: 'Debug data copied to clipboard',
        );
      },
      icon: const Icon(Icons.copy, size: 14),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBranchBadge(String branch) {
    final isTherapeutic = ['connection', 'attachment', 'growth'].contains(branch.toLowerCase());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isTherapeutic ? Colors.purple : Colors.grey.shade600,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            branch,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isTherapeutic) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: Colors.black,
            child: const Text(
              'DEEPER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getQuestTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'classic':
      case 'classicquiz':
        return Colors.blue.shade100;
      case 'affirmation':
        return Colors.pink.shade100;
      case 'youorme':
      case 'you_or_me':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  String _getQuestTypeEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'classic':
      case 'classicquiz':
        return '❓';
      case 'affirmation':
        return '💝';
      case 'youorme':
      case 'you_or_me':
        return '👫';
      default:
        return '📝';
    }
  }

  String _getQuestTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'classic':
      case 'classicquiz':
        return 'Classic Quiz';
      case 'affirmation':
        return 'Affirmation';
      case 'youorme':
      case 'you_or_me':
        return 'You or Me';
      default:
        return type;
    }
  }
}
