import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../config/dev_config.dart';
import '../../../services/storage_service.dart';
import '../../../services/daily_quest_service.dart';
import '../../../services/quest_utilities.dart';
import '../components/debug_section_card.dart';
import '../components/debug_status_indicator.dart';

/// Overview tab showing system health and device info
class OverviewTab extends StatefulWidget {
  const OverviewTab({Key? key}) : super(key: key);

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final StorageService _storage = StorageService();
  final DailyQuestService _questService = DailyQuestService(storage: StorageService());

  bool _isLoading = true;
  Map<String, dynamic> _deviceInfo = {};
  Map<String, dynamic> _questHealth = {};
  Map<String, dynamic> _storageStats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Device Info
      final user = _storage.getUser();
      final partner = _storage.getPartner();

      _deviceInfo = {
        'emulatorId': await DevConfig.emulatorId,
        'userId': user?.id ?? 'Not set',
        'partnerId': partner?.pushToken ?? 'Not set',
        'coupleId': user != null && partner != null
            ? QuestUtilities.generateCoupleId(user.id, partner.pushToken)
            : 'Not set',
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'isSimulator': await DevConfig.isSimulator,
      };

      // Quest System Health
      final todayQuests = _questService.getTodayQuests();
      final dateKey = _questService.getTodayDateKey();

      _questHealth = {
        'dateKey': dateKey,
        'questCount': todayQuests.length,
        'allHaveContentIds': todayQuests.every((q) => q.contentId != null),
        'allHaveValidExpiration': todayQuests.every((q) => q.expiresAt.isAfter(DateTime.now())),
        'hasDuplicateIds': _hasDuplicateIds(todayQuests.map((q) => q.id).toList()),
      };

      // Storage Stats
      final questsBox = _storage.dailyQuestsBox;
      final sessionsBox = _storage.quizSessionsBox;
      final transactionsBox = _storage.transactionsBox;
      final metadataBox = Hive.box('app_metadata');

      _storageStats = {
        'dailyQuests': questsBox.length,
        'quizSessions': sessionsBox.length,
        'lpTransactions': transactionsBox.length,
        'appliedLpAwards': metadataBox.get('applied_lp_awards', defaultValue: <String>[]).length,
        'quizProgression': _storage.quizProgressionStatesBox.length,
      };

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading overview data: $e');
    }
  }

  bool _hasDuplicateIds(List<String> ids) {
    return ids.length != ids.toSet().length;
  }

  String _getDeviceInfoData() {
    return JsonEncoder.withIndent('  ').convert(_deviceInfo);
  }

  String _getQuestHealthData() {
    return JsonEncoder.withIndent('  ').convert(_questHealth);
  }

  String _getStorageStatsData() {
    return JsonEncoder.withIndent('  ').convert(_storageStats);
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
            // Device Info
            DebugSectionCard(
              title: '📱 DEVICE INFO',
              copyData: _getDeviceInfoData(),
              copyMessage: 'Device info copied',
              child: Column(
                children: [
                  _buildInfoRow('Emulator ID', _deviceInfo['emulatorId'] ?? 'N/A'),
                  _buildInfoRow('User ID', _deviceInfo['userId'] ?? 'N/A'),
                  _buildInfoRow('Partner ID', _deviceInfo['partnerId'] ?? 'N/A'),
                  _buildInfoRow('Couple ID', _deviceInfo['coupleId'] ?? 'N/A'),
                  _buildInfoRow('Platform', _deviceInfo['platform'] ?? 'N/A'),
                  _buildInfoRow('Is Simulator', _deviceInfo['isSimulator'].toString()),
                ],
              ),
            ),

            // Quest System Health
            DebugSectionCard(
              title: '🎯 QUEST SYSTEM HEALTH',
              copyData: _getQuestHealthData(),
              copyMessage: 'Quest health data copied',
              child: Column(
                children: [
                  _buildHealthRow(
                    'Quest Count',
                    '${_questHealth['questCount']} quests today',
                    _questHealth['questCount'] == 3 ? DebugStatus.success : DebugStatus.warning,
                  ),
                  _buildHealthRow(
                    'Content IDs',
                    _questHealth['allHaveContentIds'] ? 'All valid' : 'Missing some',
                    _questHealth['allHaveContentIds'] ? DebugStatus.success : DebugStatus.error,
                  ),
                  _buildHealthRow(
                    'Expiration',
                    _questHealth['allHaveValidExpiration'] ? 'All valid' : 'Some expired',
                    _questHealth['allHaveValidExpiration'] ? DebugStatus.success : DebugStatus.warning,
                  ),
                  _buildHealthRow(
                    'Quest IDs',
                    _questHealth['hasDuplicateIds'] ? 'Duplicates found!' : 'All unique',
                    _questHealth['hasDuplicateIds'] ? DebugStatus.error : DebugStatus.success,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Date Key', _questHealth['dateKey'] ?? 'N/A'),
                ],
              ),
            ),

            // Storage Stats
            DebugSectionCard(
              title: '💾 STORAGE STATS',
              copyData: _getStorageStatsData(),
              copyMessage: 'Storage stats copied',
              child: Column(
                children: [
                  _buildInfoRow('Daily Quests', '${_storageStats['dailyQuests']} items'),
                  _buildInfoRow('Quiz Sessions', '${_storageStats['quizSessions']} items'),
                  _buildInfoRow('LP Transactions', '${_storageStats['lpTransactions']} items'),
                  _buildInfoRow('Applied LP Awards', '${_storageStats['appliedLpAwards']} IDs'),
                  _buildInfoRow('Quiz Progression', '${_storageStats['quizProgression']} states'),
                ],
              ),
            ),

            // Quick Actions
            DebugSectionCard(
              title: '⚡ QUICK ACTIONS',
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh All Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pull down to refresh',
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
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(String label, String value, DebugStatus status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          DebugStatusIndicator(status: status, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
