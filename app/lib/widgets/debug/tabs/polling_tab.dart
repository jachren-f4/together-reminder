import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import '../../../services/home_polling_service.dart';
import '../../../services/word_search_service.dart';
import '../../../services/linked_service.dart';
import '../components/debug_section_card.dart';

/// Polling tab showing HomePollingService state and side quest status
class PollingTab extends StatefulWidget {
  const PollingTab({Key? key}) : super(key: key);

  @override
  State<PollingTab> createState() => _PollingTabState();
}

class _PollingTabState extends State<PollingTab> {
  final StorageService _storage = StorageService();
  final HomePollingService _pollingService = HomePollingService();
  final WordSearchService _wordSearchService = WordSearchService();
  final LinkedService _linkedService = LinkedService();

  Timer? _refreshTimer;
  bool _isLoading = false;
  String? _lastPollError;
  DateTime? _lastRefresh;

  // Cached match data
  Map<String, dynamic>? _linkedMatch;
  Map<String, dynamic>? _wsMatch;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 2 seconds to show live polling state
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Get cached matches from Hive
      final linkedMatch = _storage.getActiveLinkedMatch();
      final wsMatch = _storage.getActiveWordSearchMatch();

      if (mounted) {
        setState(() {
          _linkedMatch = linkedMatch != null
              ? {
                  'matchId': linkedMatch.matchId,
                  'status': linkedMatch.status,
                  'currentTurnUserId': linkedMatch.currentTurnUserId,
                  'progressPercent': linkedMatch.progressPercent,
                }
              : null;

          _wsMatch = wsMatch != null
              ? {
                  'matchId': wsMatch.matchId,
                  'status': wsMatch.status,
                  'currentTurnUserId': wsMatch.currentTurnUserId,
                  'progressPercent': wsMatch.progressPercent,
                  'totalWordsFound': wsMatch.totalWordsFound,
                }
              : null;

          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      _lastPollError = e.toString();
    }
  }

  Future<void> _forcePoll() async {
    setState(() => _isLoading = true);
    try {
      await _pollingService.pollNow();
      await _loadData();
      _lastPollError = null;
    } catch (e) {
      _lastPollError = e.toString();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pollWordSearchDirectly() async {
    setState(() => _isLoading = true);
    try {
      final match = _storage.getActiveWordSearchMatch();
      if (match != null) {
        final result = await _wordSearchService.pollMatchState(match.matchId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('WS Poll: turn=${result.match.currentTurnUserId}, status=${result.match.status}'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active Word Search match')),
        );
      }
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WS Poll error: $e')),
      );
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pollLinkedDirectly() async {
    setState(() => _isLoading = true);
    try {
      final match = _storage.getActiveLinkedMatch();
      if (match != null) {
        final result = await _linkedService.pollMatchState(match.matchId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Linked Poll: turn=${result.match.currentTurnUserId}, status=${result.match.status}'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active Linked match')),
        );
      }
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linked Poll error: $e')),
      );
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _storage.getUser();
    final currentUserId = user?.id ?? 'unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Polling Service Status
          DebugSectionCard(
            title: 'POLLING SERVICE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow(
                  'Status',
                  _pollingService.isPolling ? 'ACTIVE' : 'STOPPED',
                  _pollingService.isPolling ? Colors.green : Colors.red,
                ),
                _buildInfoRow('Subscribers', '${_pollingService.subscriberCount}'),
                const Divider(height: 16),
                const Text('Topic Listeners:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._pollingService.topicListenerCounts.entries.map(
                  (e) => _buildInfoRow('  ${e.key}', '${e.value}'),
                ),
                const SizedBox(height: 8),
                if (_lastRefresh != null)
                  Text(
                    'Last refresh: ${_lastRefresh!.toIso8601String().split('T')[1].substring(0, 8)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Current User
          DebugSectionCard(
            title: 'CURRENT USER',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('User ID', currentUserId),
                _buildInfoRow('Short ID', currentUserId.length > 8 ? '${currentUserId.substring(0, 8)}...' : currentUserId),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Word Search Match
          DebugSectionCard(
            title: 'WORD SEARCH MATCH',
            child: _wsMatch != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Match ID', _wsMatch!['matchId']?.toString().substring(0, 8) ?? 'none'),
                      _buildStatusRow(
                        'Status',
                        _wsMatch!['status'] ?? 'unknown',
                        _wsMatch!['status'] == 'active' ? Colors.green : Colors.orange,
                      ),
                      _buildTurnRow(
                        'Current Turn',
                        _wsMatch!['currentTurnUserId'] ?? 'none',
                        currentUserId,
                      ),
                      _buildInfoRow('Progress', '${_wsMatch!['progressPercent']}%'),
                      _buildInfoRow('Words Found', '${_wsMatch!['totalWordsFound']}/12'),
                      const Divider(height: 16),
                      Text(
                        'Cached turn: ${_pollingService.wordSearchTurnUserId ?? "none"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      Text(
                        'Cached status: ${_pollingService.lastWsStatus ?? "none"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  )
                : const Text('No active Word Search match', style: TextStyle(color: Colors.grey)),
          ),

          const SizedBox(height: 16),

          // Linked Match
          DebugSectionCard(
            title: 'LINKED MATCH',
            child: _linkedMatch != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Match ID', _linkedMatch!['matchId']?.toString().substring(0, 8) ?? 'none'),
                      _buildStatusRow(
                        'Status',
                        _linkedMatch!['status'] ?? 'unknown',
                        _linkedMatch!['status'] == 'active' ? Colors.green : Colors.orange,
                      ),
                      _buildTurnRow(
                        'Current Turn',
                        _linkedMatch!['currentTurnUserId'] ?? 'none',
                        currentUserId,
                      ),
                      _buildInfoRow('Progress', '${_linkedMatch!['progressPercent']}%'),
                      const Divider(height: 16),
                      Text(
                        'Cached turn: ${_pollingService.linkedTurnUserId ?? "none"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      Text(
                        'Cached status: ${_pollingService.lastLinkedStatus ?? "none"}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  )
                : const Text('No active Linked match', style: TextStyle(color: Colors.grey)),
          ),

          const SizedBox(height: 16),

          // Actions
          DebugSectionCard(
            title: 'DEBUG ACTIONS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _forcePoll,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Force Poll Now'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _pollWordSearchDirectly,
                        child: const Text('Poll WS'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _pollLinkedDirectly,
                        child: const Text('Poll Linked'),
                      ),
                    ),
                  ],
                ),
                if (_lastPollError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last error: $_lastPollError',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTurnRow(String label, String turnUserId, String currentUserId) {
    final isMyTurn = turnUserId == currentUserId;
    final displayValue = isMyTurn ? 'YOUR TURN' : 'Partner\'s turn';
    final color = isMyTurn ? Colors.green : Colors.orange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${turnUserId.length > 6 ? turnUserId.substring(0, 6) : turnUserId}...)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
