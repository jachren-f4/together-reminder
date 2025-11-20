import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../services/storage_service.dart';
import '../../services/quest_sync_service.dart';
import '../../services/love_point_service.dart';
import '../../services/quiz_service.dart';
import '../../utils/logger.dart';

class DataValidationScreen extends StatefulWidget {
  const DataValidationScreen({super.key});

  @override
  State<DataValidationScreen> createState() => _DataValidationScreenState();
}

class _DataValidationScreenState extends State<DataValidationScreen> {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storage = StorageService();
  late final QuestSyncService _questSyncService;
  final LovePointService _lovePointService = LovePointService();
  final QuizService _quizService = QuizService();

  @override
  void initState() {
    super.initState();
    _questSyncService = QuestSyncService(storage: _storage);
    _runValidation();
  }

  bool _isLoading = false;
  Map<String, dynamic>? _validationResults;
  String? _error;

  Future<void> _runValidation() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _validationResults = null;
    });

    try {
      final results = <String, dynamic>{};

      // 1. Validate Daily Quests
      results['quests'] = await _validateDailyQuests();

      // 2. Validate Love Points
      results['lovePoints'] = await _validateLovePoints();

      // 3. Validate Quiz Sessions
      results['quizSessions'] = await _validateQuizSessions();

      setState(() {
        _validationResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _validateDailyQuests() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Fetch from Firebase (via local storage which is synced)
      // Note: QuestSyncService syncs to Hive, so we read from Hive
      final firebaseQuests = _storage.getDailyQuestsForDate(today);

      // Fetch from Supabase
      final response = await _apiClient.get('/api/sync/daily-quests?date=$today');
      
      if (!response.success) {
        return {'status': 'error', 'message': response.error};
      }

      final supabaseQuests = (response.data['quests'] as List?) ?? [];

      // Compare
      final firebaseCount = firebaseQuests.length;
      final supabaseCount = supabaseQuests.length;
      final isSynced = firebaseCount == supabaseCount; // Simple count check for now

      return {
        'status': isSynced ? 'synced' : 'diverged',
        'firebaseCount': firebaseCount,
        'supabaseCount': supabaseCount,
        'details': 'Firebase: $firebaseCount, Supabase: $supabaseCount',
      };
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _validateLovePoints() async {
    try {
      // Fetch from Firebase/Local
      final user = _storage.getUser();
      final firebaseTotal = user?.lovePoints ?? 0;

      // Fetch from Supabase
      final response = await _apiClient.get('/api/sync/love-points');
      
      if (!response.success) {
        return {'status': 'error', 'message': response.error};
      }

      final supabaseTotal = response.data['total'] as int? ?? 0;
      final transactions = response.data['transactions'] as List? ?? [];

      final isSynced = firebaseTotal == supabaseTotal;

      return {
        'status': isSynced ? 'synced' : 'diverged',
        'firebaseTotal': firebaseTotal,
        'supabaseTotal': supabaseTotal,
        'recentTransactions': transactions.length,
        'details': 'Firebase: $firebaseTotal, Supabase: $supabaseTotal',
      };
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _validateQuizSessions() async {
    try {
      // Fetch from Firebase/Local
      final firebaseSessions = _quizService.getCompletedSessions();
      // We only check the last 10 to match API
      final recentFirebase = firebaseSessions.take(10).toList();

      // Fetch from Supabase
      final response = await _apiClient.get('/api/sync/quiz-sessions');
      
      if (!response.success) {
        return {'status': 'error', 'message': response.error};
      }

      final supabaseSessions = (response.data['sessions'] as List?) ?? [];

      // Compare counts of recent sessions (rough check)
      // A more robust check would compare IDs
      
      // Let's compare the ID of the most recent session
      String? firebaseLatestId = recentFirebase.isNotEmpty ? recentFirebase.first.id : null;
      String? supabaseLatestId = supabaseSessions.isNotEmpty ? supabaseSessions.first['id'] : null;

      final isSynced = firebaseLatestId == supabaseLatestId;

      return {
        'status': isSynced ? 'synced' : 'diverged',
        'firebaseLatest': firebaseLatestId ?? 'None',
        'supabaseLatest': supabaseLatestId ?? 'None',
        'details': 'Latest ID Match: $isSynced',
      };
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Validation Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _runValidation,
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Simulate Network Errors'),
            subtitle: const Text('Force API calls to fail for resilience testing'),
            value: _apiClient.simulateNetworkError,
            onChanged: (value) {
              setState(() {
                _apiClient.simulateNetworkError = value;
              });
            },
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSection('Daily Quests', _validationResults?['quests']),
                          _buildSection('Love Points', _validationResults?['lovePoints']),
                          _buildSection('Quiz Sessions', _validationResults?['quizSessions']),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();

    final status = data['status'] as String;
    final isSynced = status == 'synced';
    final isError = status == 'error';

    Color statusColor = isSynced ? Colors.green : (isError ? Colors.red : Colors.orange);
    IconData statusIcon = isSynced ? Icons.check_circle : (isError ? Icons.error : Icons.warning);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (isError)
              Text('Error: ${data['message']}', style: const TextStyle(color: Colors.red))
            else ...[
              Text('Details: ${data['details']}'),
              const SizedBox(height: 8),
              if (data.containsKey('firebaseCount'))
                Text('Firebase Count: ${data['firebaseCount']}'),
              if (data.containsKey('supabaseCount'))
                Text('Supabase Count: ${data['supabaseCount']}'),
              if (data.containsKey('firebaseTotal'))
                Text('Firebase Total: ${data['firebaseTotal']}'),
              if (data.containsKey('supabaseTotal'))
                Text('Supabase Total: ${data['supabaseTotal']}'),
            ],
          ],
        ),
      ),
    );
  }
}
