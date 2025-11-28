import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../services/storage_service.dart';
import '../../../services/daily_quest_service.dart';
import '../../../services/clipboard_service.dart';
import '../../../services/quest_utilities.dart';
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

  bool _isProcessing = false;

  // Clear storage checkboxes
  bool _clearDailyQuests = true;
  bool _clearQuizSessions = true;
  bool _clearLpTransactions = true;
  bool _clearProgressionState = false;
  bool _clearAppliedLpAwards = false;

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
      'quests': quests.map((q) => {
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
                  'Progression State',
                  _clearProgressionState,
                  (value) => setState(() => _clearProgressionState = value ?? false),
                  '${_storage.quizProgressionStatesBox.length} states',
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

          // Quest Testing (Placeholder for future)
          DebugSectionCard(
            title: '🧪 QUEST TESTING',
            child: Column(
              children: [
                Text(
                  'Quest testing tools coming soon',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Future features:\n'
                  '• Simulate partner completion\n'
                  '• Force quest regeneration\n'
                  '• Expire/reset quests',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}
