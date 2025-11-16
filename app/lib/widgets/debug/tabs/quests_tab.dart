import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../services/storage_service.dart';
import '../../../services/daily_quest_service.dart';
import '../../../services/quest_utilities.dart';
import '../../../models/daily_quest.dart';
import '../components/debug_section_card.dart';
import '../components/debug_copy_button.dart';
import '../components/debug_status_indicator.dart';

/// Quests tab showing Firebase vs Local comparison and validation
class QuestsTab extends StatefulWidget {
  const QuestsTab({Key? key}) : super(key: key);

  @override
  State<QuestsTab> createState() => _QuestsTabState();
}

class _QuestsTabState extends State<QuestsTab> {
  final StorageService _storage = StorageService();
  final DailyQuestService _questService = DailyQuestService(storage: StorageService());
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _isLoading = true;
  List<DailyQuest> _localQuests = [];
  Map<String, dynamic>? _firebaseData;
  List<String> _validationIssues = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get local quests
      _localQuests = _questService.getTodayQuests();

      // Get Firebase data
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user != null && partner != null) {
        final coupleId = QuestUtilities.generateCoupleId(user.id, partner.pushToken);
        final dateKey = _questService.getTodayDateKey();
        final dbRef = _database.ref('daily_quests/$coupleId/$dateKey');
        final snapshot = await dbRef.get();

        _firebaseData = snapshot.exists ? snapshot.value as Map<String, dynamic>? : null;
      }

      // Run validation
      _runValidation();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading quests data: $e');
    }
  }

  void _runValidation() {
    _validationIssues.clear();

    // Check if quest IDs match
    if (_firebaseData != null) {
      final firebaseQuests = _firebaseData!['quests'] as List<dynamic>?;
      if (firebaseQuests != null) {
        final firebaseIds = firebaseQuests.map((q) => q['id'] as String).toSet();
        final localIds = _localQuests.map((q) => q.id).toSet();

        if (firebaseIds.length != localIds.length || !firebaseIds.containsAll(localIds)) {
          _validationIssues.add('⚠️ Quest IDs mismatch between Firebase and Local');
        } else {
          _validationIssues.add('✅ All quest IDs match between Firebase and Local');
        }
      }
    } else {
      _validationIssues.add('⚠️ No Firebase data found');
    }

    // Check content IDs
    if (_localQuests.every((q) => q.contentId != null && q.contentId!.isNotEmpty)) {
      _validationIssues.add('✅ All quests have valid content IDs');
    } else {
      _validationIssues.add('❌ Some quests missing content IDs');
    }

    // Check expirations
    final now = DateTime.now();
    if (_localQuests.every((q) => q.expiresAt.isAfter(now))) {
      _validationIssues.add('✅ All quests have valid expiration dates');
    } else {
      _validationIssues.add('⚠️ Some quests have expired');
    }

    // Check for duplicates
    final ids = _localQuests.map((q) => q.id).toList();
    if (ids.length == ids.toSet().length) {
      _validationIssues.add('✅ No duplicate quest IDs');
    } else {
      _validationIssues.add('❌ Duplicate quest IDs found!');
    }
  }

  String _getQuestData(DailyQuest quest) {
    return JsonEncoder.withIndent('  ').convert({
      'id': quest.id,
      'type': quest.type.name,
      'contentId': quest.contentId,
      'status': quest.status,
      'userCompletions': quest.userCompletions,
      'isCompleted': quest.isCompleted,
      'isSideQuest': quest.isSideQuest,
      'expiresAt': quest.expiresAt.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Validation Section
            DebugSectionCard(
              title: '✅ VALIDATION CHECKS',
              copyData: _validationIssues.join('\n'),
              copyMessage: 'Validation results copied',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _validationIssues.map((issue) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      issue,
                      style: TextStyle(
                        fontSize: 11,
                        color: issue.startsWith('✅')
                            ? Colors.green.shade700
                            : issue.startsWith('❌')
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Quest Comparison Table
            DebugSectionCard(
              title: '📊 QUEST COMPARISON (${_localQuests.length} quests)',
              copyData: JsonEncoder.withIndent('  ').convert({
                'local': _localQuests.map((q) => q.id).toList(),
                'firebase': _firebaseData?['quests']?.map((q) => q['id']).toList() ?? [],
              }),
              copyMessage: 'Quest comparison copied',
              child: Column(
                children: _localQuests.map((quest) {
                  final inFirebase = _firebaseData?['quests']
                      ?.any((q) => q['id'] == quest.id) ?? false;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                quest.id,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                quest.type.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DebugStatusIndicator(
                          status: inFirebase ? DebugStatus.success : DebugStatus.error,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Individual Quest Cards
            ..._localQuests.map((quest) => _buildQuestCard(quest)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard(DailyQuest quest) {
    final now = DateTime.now();
    final isExpired = quest.expiresAt.isBefore(now);
    final timeRemaining = quest.expiresAt.difference(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isExpired ? Colors.red.shade300 : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quest ${_localQuests.indexOf(quest) + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        quest.id,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTypeColor(quest.type),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        quest.type.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DebugCopyButton(
                      data: _getQuestData(quest),
                      message: 'Quest data copied',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Card Content
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildQuestInfoRow('Status', quest.status),
                _buildQuestInfoRow('Content ID', quest.contentId ?? 'N/A'),
                _buildQuestInfoRow(
                  'Completed',
                  quest.isCompleted ? '✅ Yes' : '⏳ No',
                ),
                _buildQuestInfoRow(
                  'Completions',
                  quest.userCompletions?.entries
                      .where((e) => e.value)
                      .map((e) => e.key)
                      .join(', ') ?? 'None',
                ),
                _buildQuestInfoRow(
                  'Expires',
                  isExpired
                      ? '❌ EXPIRED'
                      : '${timeRemaining.inHours}h ${timeRemaining.inMinutes % 60}m',
                ),
                _buildQuestInfoRow('Side Quest', quest.isSideQuest ? 'Yes' : 'No'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(QuestType type) {
    switch (type) {
      case QuestType.quiz:
        return Colors.blue;
      case QuestType.question:
        return Colors.orange;
      case QuestType.game:
        return Colors.purple;
      case QuestType.wordLadder:
        return Colors.green;
      case QuestType.memoryFlip:
        return Colors.pink;
      case QuestType.youOrMe:
        return Colors.teal;
    }
  }
}
