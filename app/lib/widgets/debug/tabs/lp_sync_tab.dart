import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../services/storage_service.dart';
import '../../../services/arena_service.dart';
import '../../../services/quest_utilities.dart';
import '../../../models/love_point_transaction.dart';
import '../../../utils/logger.dart';
import '../components/debug_section_card.dart';

/// LP & Sync tab showing Love Points and Firebase synchronization
class LpSyncTab extends StatefulWidget {
  const LpSyncTab({Key? key}) : super(key: key);

  @override
  State<LpSyncTab> createState() => _LpSyncTabState();
}

class _LpSyncTabState extends State<LpSyncTab> {
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  bool _isLoading = true;
  List<LovePointTransaction> _transactions = [];
  List<String> _appliedAwards = [];
  int _currentLP = 0;
  Map<String, dynamic> _firebaseSync = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get LP transactions
      _transactions = _storage.transactionsBox.values.toList();
      _transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Get applied LP awards from app_metadata
      final metadataBox = Hive.box('app_metadata');
      _appliedAwards = List<String>.from(
        metadataBox.get('applied_lp_awards', defaultValue: <String>[]),
      );

      // Get current LP
      _currentLP = _arenaService.getLovePoints();

      // Get Firebase sync status
      await _loadFirebaseSync();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      Logger.error('Error loading LP & Sync data', error: e, service: 'debug');
    }
  }

  Future<void> _loadFirebaseSync() async {
    try {
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      if (user != null && partner != null) {
        final coupleId = QuestUtilities.generateCoupleId(user.id, partner.pushToken);

        // Check daily_quests path
        final questsRef = _database.ref('daily_quests/$coupleId');
        final questsSnapshot = await questsRef.get();

        // Check quiz_progression path
        final progressionRef = _database.ref('quiz_progression/$coupleId');
        final progressionSnapshot = await progressionRef.get();

        // Check lp_awards path
        final awardsRef = _database.ref('lp_awards/$coupleId');
        final awardsSnapshot = await awardsRef.get();

        _firebaseSync = {
          'daily_quests': {
            'path': 'daily_quests/$coupleId',
            'exists': questsSnapshot.exists,
            'childrenCount': questsSnapshot.exists ? questsSnapshot.children.length : 0,
          },
          'quiz_progression': {
            'path': 'quiz_progression/$coupleId',
            'exists': progressionSnapshot.exists,
            'data': progressionSnapshot.exists ? progressionSnapshot.value : null,
          },
          'lp_awards': {
            'path': 'lp_awards/$coupleId',
            'exists': awardsSnapshot.exists,
            'childrenCount': awardsSnapshot.exists ? awardsSnapshot.children.length : 0,
          },
        };
      }
    } catch (e) {
      Logger.error('Error loading Firebase sync status', error: e, service: 'debug');
    }
  }

  String _getTransactionsData() {
    return JsonEncoder.withIndent('  ').convert(
      _transactions.take(20).map((t) => {
        'amount': t.amount,
        'reason': t.reason,
        'timestamp': t.timestamp.toIso8601String(),
        'relatedId': t.relatedId,
      }).toList(),
    );
  }

  String _getAppliedAwardsData() {
    return JsonEncoder.withIndent('  ').convert(_appliedAwards);
  }

  String _getFirebaseSyncData() {
    return JsonEncoder.withIndent('  ').convert(_firebaseSync);
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
            // Current LP Summary
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '💰 Current Love Points',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_currentLP LP',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            // LP Transactions
            DebugSectionCard(
              title: '💰 LP TRANSACTIONS (Last 20)',
              copyData: _getTransactionsData(),
              copyMessage: 'LP transactions copied',
              child: _transactions.isEmpty
                  ? const Text(
                      'No transactions yet',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    )
                  : Column(
                      children: _transactions.take(20).map((transaction) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getTimeAgo(transaction.timestamp),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      Text(
                                        transaction.reason,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '+${transaction.amount} LP',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),

            // Applied LP Awards
            DebugSectionCard(
              title: '📋 APPLIED LP AWARDS (app_metadata)',
              copyData: _getAppliedAwardsData(),
              copyMessage: 'Applied awards copied',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tracked Awards: ${_appliedAwards.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_appliedAwards.isEmpty)
                    const Text(
                      'No awards applied yet',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    )
                  else
                    ...(_appliedAwards.take(10).map((awardId) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                awardId,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 14,
                            ),
                          ],
                        ),
                      );
                    })),
                  if (_appliedAwards.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${_appliedAwards.length - 10} more',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Firebase Sync Status
            DebugSectionCard(
              title: '🔥 FIREBASE SYNC STATUS',
              copyData: _getFirebaseSyncData(),
              copyMessage: 'Firebase sync status copied',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // daily_quests path
                  _buildFirebasePath(
                    '/daily_quests',
                    _firebaseSync['daily_quests']?['path'] ?? 'N/A',
                    _firebaseSync['daily_quests']?['exists'] ?? false,
                    'Date keys: ${_firebaseSync['daily_quests']?['childrenCount'] ?? 0}',
                  ),

                  const SizedBox(height: 16),

                  // quiz_progression path
                  _buildFirebasePath(
                    '/quiz_progression',
                    _firebaseSync['quiz_progression']?['path'] ?? 'N/A',
                    _firebaseSync['quiz_progression']?['exists'] ?? false,
                    _firebaseSync['quiz_progression']?['data'] != null
                        ? 'Data exists'
                        : 'No data',
                  ),

                  const SizedBox(height: 16),

                  // lp_awards path
                  _buildFirebasePath(
                    '/lp_awards',
                    _firebaseSync['lp_awards']?['path'] ?? 'N/A',
                    _firebaseSync['lp_awards']?['exists'] ?? false,
                    'Awards: ${_firebaseSync['lp_awards']?['childrenCount'] ?? 0}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirebasePath(String name, String path, bool exists, String info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          path,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              exists ? Icons.check_circle : Icons.error,
              color: exists ? Colors.green : Colors.red,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              exists ? 'Active' : 'Not found',
              style: TextStyle(
                fontSize: 11,
                color: exists ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              info,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
