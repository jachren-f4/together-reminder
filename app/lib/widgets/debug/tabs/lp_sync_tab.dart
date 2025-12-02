import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../services/storage_service.dart';
import '../../../services/arena_service.dart';
import '../../../services/api_client.dart';
import '../../../models/love_point_transaction.dart';
import '../../../utils/logger.dart';
import '../components/debug_section_card.dart';

/// LP & Sync tab showing Love Points and API synchronization
class LpSyncTab extends StatefulWidget {
  const LpSyncTab({Key? key}) : super(key: key);

  @override
  State<LpSyncTab> createState() => _LpSyncTabState();
}

class _LpSyncTabState extends State<LpSyncTab> {
  final StorageService _storage = StorageService();
  final ArenaService _arenaService = ArenaService();
  final ApiClient _apiClient = ApiClient();

  bool _isLoading = true;
  List<LovePointTransaction> _transactions = [];
  List<String> _appliedAwards = [];
  int _currentLP = 0;
  int _serverLP = 0;
  Map<String, dynamic> _serverSync = {};

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

      // Get current LP (local)
      _currentLP = _arenaService.getLovePoints();

      // Get server sync status
      await _loadServerSync();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      Logger.error('Error loading LP & Sync data', error: e, service: 'debug');
    }
  }

  Future<void> _loadServerSync() async {
    try {
      // Fetch LP from server
      final lpResponse = await _apiClient.get('/api/sync/love-points');
      if (lpResponse.success && lpResponse.data != null) {
        _serverLP = lpResponse.data['totalLp'] as int? ?? 0;
      }

      // Fetch daily quests count from server
      final questsResponse = await _apiClient.get('/api/sync/daily-quests');
      int questCount = 0;
      if (questsResponse.success && questsResponse.data != null) {
        final quests = questsResponse.data['quests'] as List<dynamic>?;
        questCount = quests?.length ?? 0;
      }

      // Fetch LP awards from server
      final awardsResponse = await _apiClient.get('/api/sync/love-points/history');
      int awardsCount = 0;
      if (awardsResponse.success && awardsResponse.data != null) {
        final awards = awardsResponse.data['awards'] as List<dynamic>?;
        awardsCount = awards?.length ?? 0;
      }

      _serverSync = {
        'love_points': {
          'path': '/api/sync/love-points',
          'exists': true,
          'value': _serverLP,
        },
        'daily_quests': {
          'path': '/api/sync/daily-quests',
          'exists': questCount > 0,
          'childrenCount': questCount,
        },
        'lp_awards': {
          'path': '/api/sync/love-points/history',
          'exists': awardsCount > 0,
          'childrenCount': awardsCount,
        },
      };
    } catch (e) {
      Logger.error('Error loading server sync status', error: e, service: 'debug');
      _serverSync = {
        'love_points': {'path': '/api/sync/love-points', 'exists': false, 'value': 0},
        'daily_quests': {'path': '/api/sync/daily-quests', 'exists': false, 'childrenCount': 0},
        'lp_awards': {'path': '/api/sync/love-points/history', 'exists': false, 'childrenCount': 0},
      };
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

  String _getServerSyncData() {
    return JsonEncoder.withIndent('  ').convert(_serverSync);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final lpMatch = _currentLP == _serverLP;

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
                    '💰 Love Points',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Local',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '$_currentLP',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          lpMatch ? Icons.check_circle : Icons.warning,
                          color: lpMatch ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'Server',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '$_serverLP',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: lpMatch ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!lpMatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '⚠️ LP mismatch between local and server',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                        ),
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

            // Server Sync Status
            DebugSectionCard(
              title: '☁️ SERVER SYNC STATUS (Supabase)',
              copyData: _getServerSyncData(),
              copyMessage: 'Server sync status copied',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // love_points endpoint
                  _buildServerPath(
                    '/love-points',
                    _serverSync['love_points']?['path'] ?? 'N/A',
                    _serverSync['love_points']?['exists'] ?? false,
                    'Value: ${_serverSync['love_points']?['value'] ?? 0}',
                  ),

                  const SizedBox(height: 16),

                  // daily_quests endpoint
                  _buildServerPath(
                    '/daily-quests',
                    _serverSync['daily_quests']?['path'] ?? 'N/A',
                    _serverSync['daily_quests']?['exists'] ?? false,
                    'Quests: ${_serverSync['daily_quests']?['childrenCount'] ?? 0}',
                  ),

                  const SizedBox(height: 16),

                  // lp_awards endpoint
                  _buildServerPath(
                    '/love-points/history',
                    _serverSync['lp_awards']?['path'] ?? 'N/A',
                    _serverSync['lp_awards']?['exists'] ?? false,
                    'Awards: ${_serverSync['lp_awards']?['childrenCount'] ?? 0}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerPath(String name, String path, bool exists, String info) {
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
