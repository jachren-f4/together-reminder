import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/storage_service.dart';
import '../../../models/quiz_session.dart';
import '../components/debug_section_card.dart';
import '../components/debug_copy_button.dart';

/// Sessions tab showing quiz/game sessions
class SessionsTab extends StatefulWidget {
  const SessionsTab({Key? key}) : super(key: key);

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  final StorageService _storage = StorageService();

  bool _isLoading = true;
  List<QuizSession> _allSessions = [];
  List<QuizSession> _filteredSessions = [];
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Affirmations',
    'Classic Quiz',
    'Completed',
    'In Progress',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _allSessions = _storage.quizSessionsBox.values.toList();
      _allSessions.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
      _applyFilter();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading sessions: $e');
    }
  }

  void _applyFilter() {
    switch (_selectedFilter) {
      case 'All':
        _filteredSessions = _allSessions;
        break;
      case 'Affirmations':
        _filteredSessions = _allSessions.where((s) =>
          s.formatType == 'affirmation' || s.quizName != null
        ).toList();
        break;
      case 'Classic Quiz':
        _filteredSessions = _allSessions.where((s) =>
          s.formatType == 'classic' || (s.formatType == null && s.quizName == null)
        ).toList();
        break;
      case 'Completed':
        _filteredSessions = _allSessions.where((s) => s.status == 'completed').toList();
        break;
      case 'In Progress':
        _filteredSessions = _allSessions.where((s) => s.status != 'completed').toList();
        break;
    }
  }

  String _getSessionData(QuizSession session) {
    return JsonEncoder.withIndent('  ').convert({
      'id': session.id,
      'status': session.status,
      'createdAt': session.createdAt.toIso8601String(),
      'questionIds': session.questionIds,
      'formatType': session.formatType,
      'quizName': session.quizName,
      'category': session.category,
      'answers': session.answers?.map((k, v) => MapEntry(k, v.toString())),
      'matchPercentage': session.matchPercentage,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = filter == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                          _applyFilter();
                        });
                      },
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? Colors.black : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Sessions List
          Expanded(
            child: _filteredSessions.isEmpty
                ? Center(
                    child: Text(
                      'No sessions found',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredSessions.length,
                    itemBuilder: (context, index) {
                      return _buildSessionCard(_filteredSessions[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(QuizSession session) {
    final isAffirmation = session.formatType == 'affirmation' || session.quizName != null;
    final questionCount = session.questionIds.length;
    final createdAgo = _getTimeAgo(session.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300, width: 2),
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
                        session.quizName ?? (isAffirmation ? '📝 Affirmation Quiz' : '🎯 Classic Quiz'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        session.id,
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
                        color: isAffirmation ? Colors.pink : Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.formatType?.toUpperCase() ?? 'CLASSIC',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DebugCopyButton(
                      data: _getSessionData(session),
                      message: 'Session data copied',
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
                _buildInfoRow('Created', createdAgo),
                _buildInfoRow('Status', session.status),
                _buildInfoRow('Questions', '$questionCount question IDs'),
                if (session.matchPercentage != null)
                  _buildInfoRow('Match', '${session.matchPercentage}%'),
                if (session.category != null)
                  _buildInfoRow('Category', session.category!),

                // Question IDs Summary
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Question IDs: ${session.questionIds.take(3).join(", ")}${session.questionIds.length > 3 ? "..." : ""}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Answer Count
                const SizedBox(height: 8),
                Text(
                  'Answers received: ${session.answers?.length ?? 0} users',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
