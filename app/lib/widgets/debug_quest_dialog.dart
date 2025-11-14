import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:hive/hive.dart';
import '../services/storage_service.dart';
import '../services/daily_quest_service.dart';
import '../services/mock_data_service.dart';
import '../services/quest_utilities.dart';
import '../theme/app_theme.dart';

/// Debug dialog for viewing quest data in Firebase and local storage
class DebugQuestDialog extends StatefulWidget {
  const DebugQuestDialog({Key? key}) : super(key: key);

  @override
  State<DebugQuestDialog> createState() => _DebugQuestDialogState();
}

class _DebugQuestDialogState extends State<DebugQuestDialog> {
  final StorageService _storage = StorageService();
  final DailyQuestService _questService = DailyQuestService(storage: StorageService());
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _isLoading = true;
  Map<String, dynamic>? _firebaseData;
  Map<String, dynamic>? _localStorage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get user info
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user == null || partner == null) {
        setState(() {
          _error = 'User or partner not found in local storage';
          _isLoading = false;
        });
        return;
      }

      // Generate couple ID and date key
      final coupleId = QuestUtilities.generateCoupleId(user.id, partner.pushToken);
      final dateKey = _questService.getTodayDateKey();

      // Fetch Firebase data
      final dbRef = _database.ref('daily_quests/$coupleId/$dateKey');
      final snapshot = await dbRef.get();

      Map<String, dynamic> firebaseData = {
        'path': 'daily_quests/$coupleId/$dateKey',
        'exists': snapshot.exists,
        'data': snapshot.exists ? snapshot.value : null,
      };

      // Get local storage data
      final localQuests = _questService.getTodayQuests();
      Map<String, dynamic> localData = {
        'userId': user.id,
        'partnerId': partner.pushToken,
        'coupleId': coupleId,
        'dateKey': dateKey,
        'questCount': localQuests.length,
        'quests': localQuests.map((q) => {
          'id': q.id,
          'type': q.type.name,
          'contentId': q.contentId,
          'status': q.status,
          'userCompletions': q.userCompletions,
          'isCompleted': q.isCompleted,
          'isSideQuest': q.isSideQuest,
          'expiresAt': q.expiresAt.toIso8601String(),
        }).toList(),
      };

      setState(() {
        _firebaseData = firebaseData;
        _localStorage = localData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'firebase': _firebaseData,
      'localStorage': _localStorage,
    };

    final jsonString = JsonEncoder.withIndent('  ').convert(data);
    Clipboard.setData(ClipboardData(text: jsonString));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debug data copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearLocalStorageAndReload() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('🗑️ Clearing local storage only...');
      print('⚠️  NOTE: Firebase data is NOT cleared. Use external script for that.');

      // Clear all Hive boxes
      print('🗑️ Clearing local Hive boxes...');
      await _storage.remindersBox.clear();
      await _storage.userBox.clear();
      await _storage.partnerBox.clear();
      await _storage.transactionsBox.clear();
      await _storage.quizSessionsBox.clear();
      await _storage.badgesBox.clear();
      await _storage.ladderSessionsBox.clear();
      await _storage.memoryPuzzlesBox.clear();
      await _storage.memoryAllowancesBox.clear();
      await _storage.quizStreaksBox.clear();
      await _storage.dailyPulsesBox.clear();
      await _storage.dailyQuestsBox.clear();
      await _storage.dailyQuestCompletionsBox.clear();
      await _storage.quizProgressionStatesBox.clear();
      await Hive.box('app_metadata').clear();  // Clear metadata box
      print('✅ Local storage cleared');

      // Show restart dialog instead of trying to reload in-place
      // (Reloading causes crashes due to inconsistent app state)
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
      print('❌ Error clearing local storage: $e');
      setState(() {
        _error = 'Error clearing local storage: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Quest Debug Menu',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Copy button
            ElevatedButton.icon(
              onPressed: _isLoading || _error != null ? null : _copyToClipboard,
              icon: const Icon(Icons.copy),
              label: const Text('Copy to Clipboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Clear Local Storage button
            ElevatedButton.icon(
              onPressed: _isLoading || _error != null ? null : _clearLocalStorageAndReload,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear Local Storage & Reload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Firebase Data
                              _buildSection(
                                'Firebase RTDB',
                                _firebaseData,
                              ),
                              const SizedBox(height: 24),

                              // Local Storage Data
                              _buildSection(
                                'Local Storage (Hive)',
                                _localStorage,
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Map<String, dynamic>? data) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderLight, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              title,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              JsonEncoder.withIndent('  ').convert(data ?? {}),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
