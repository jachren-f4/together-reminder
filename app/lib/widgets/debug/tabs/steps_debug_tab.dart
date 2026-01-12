import 'package:flutter/material.dart';
import '../../../services/steps_debug_service.dart';
import '../../../services/storage_service.dart';
import '../../../models/steps_data.dart';
import '../../../widgets/steps_auto_claim_overlay.dart';
import '../../../widgets/steps_milestone_overlay.dart';

/// Debug tab for testing Steps Together features.
/// Allows simulating step counts, triggering celebrations, and testing auto-claim.
class StepsDebugTab extends StatefulWidget {
  const StepsDebugTab({super.key});

  @override
  State<StepsDebugTab> createState() => _StepsDebugTabState();
}

class _StepsDebugTabState extends State<StepsDebugTab> {
  final StepsDebugService _debugService = StepsDebugService();
  final StorageService _storage = StorageService();

  double _userStepsSlider = 0;
  double _partnerStepsSlider = 0;

  @override
  void initState() {
    super.initState();
    _userStepsSlider = _debugService.mockUserSteps.toDouble();
    _partnerStepsSlider = _debugService.mockPartnerSteps.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final combined = (_userStepsSlider + _partnerStepsSlider).toInt();
    final lp = StepsDay.calculateLP(combined);
    final tier = _getTierName(combined);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        _buildSection(
          title: 'Steps Simulation',
          child: Column(
            children: [
              // Mock data toggle
              SwitchListTile(
                title: const Text('Use Mock Data'),
                subtitle: Text(_debugService.useMockData ? 'Active' : 'Inactive'),
                value: _debugService.useMockData,
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _debugService.enableMockData();
                    } else {
                      _debugService.disableMockData();
                      _userStepsSlider = 0;
                      _partnerStepsSlider = 0;
                    }
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Step Sliders
        _buildSection(
          title: 'Step Counts',
          child: Column(
            children: [
              // User steps
              _buildSliderRow(
                label: 'Your Steps',
                value: _userStepsSlider,
                onChanged: (value) {
                  setState(() {
                    _userStepsSlider = value;
                    _debugService.setMockUserSteps(value.toInt());
                  });
                },
              ),

              const SizedBox(height: 8),

              // Partner steps
              _buildSliderRow(
                label: 'Partner Steps',
                value: _partnerStepsSlider,
                onChanged: (value) {
                  setState(() {
                    _partnerStepsSlider = value;
                    _debugService.setMockPartnerSteps(value.toInt());
                  });
                },
              ),

              const Divider(height: 24),

              // Combined display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Combined', _formatNumber(combined)),
                    _buildStatColumn('Tier', tier),
                    _buildStatColumn('LP', '+$lp'),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Presets
        _buildSection(
          title: 'Quick Presets',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetButton(
                label: 'Below 10K',
                subtitle: '7K total',
                onTap: () {
                  _debugService.applyPresetBelowThreshold();
                  setState(() {
                    _userStepsSlider = 4000;
                    _partnerStepsSlider = 3000;
                  });
                },
              ),
              _buildPresetButton(
                label: 'At 10K',
                subtitle: '15 LP',
                onTap: () {
                  _debugService.applyPresetAt10K();
                  setState(() {
                    _userStepsSlider = 5000;
                    _partnerStepsSlider = 5000;
                  });
                },
              ),
              _buildPresetButton(
                label: 'At 14K',
                subtitle: '21 LP',
                onTap: () {
                  _debugService.applyPresetAt14K();
                  setState(() {
                    _userStepsSlider = 8000;
                    _partnerStepsSlider = 6000;
                  });
                },
              ),
              _buildPresetButton(
                label: 'Max Tier',
                subtitle: '30 LP',
                onTap: () {
                  _debugService.applyPresetMaxTier();
                  setState(() {
                    _userStepsSlider = 12000;
                    _partnerStepsSlider = 10000;
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Actions
        _buildSection(
          title: 'Actions',
          child: Column(
            children: [
              _buildActionButton(
                icon: Icons.save,
                label: 'Apply to Today\'s Data',
                subtitle: 'Write mock values to Hive storage',
                onTap: () async {
                  await _debugService.applyMockDataToStorage();
                  _showSnackBar('Mock data applied to today');
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.celebration,
                label: 'Show Auto-Claim Overlay',
                subtitle: 'Simulate yesterday\'s claim celebration',
                onTap: () => _showAutoClaimOverlay(isCurrentUserClaimer: true),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.people,
                label: 'Show Partner Claimed Overlay',
                subtitle: 'Simulate partner claiming for you',
                onTap: () => _showAutoClaimOverlay(isCurrentUserClaimer: false),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.emoji_events,
                label: 'Show Milestone Celebration',
                subtitle: 'Simulate tier crossing (10K → 12K)',
                onTap: () => _showMilestoneCelebration(),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.calendar_month,
                label: 'Generate Week History',
                subtitle: 'Create 7 days of mock data',
                onTap: () async {
                  await _debugService.generateMockWeekHistory();
                  _showSnackBar('Week history generated');
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.refresh,
                label: 'Reset Today\'s Data',
                subtitle: 'Clear today\'s step counts',
                onTap: () async {
                  await _debugService.resetTodayData();
                  setState(() {
                    _userStepsSlider = 0;
                    _partnerStepsSlider = 0;
                  });
                  _showSnackBar('Today\'s data reset');
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                icon: Icons.history,
                label: 'Reset Yesterday (for Auto-Claim)',
                subtitle: 'Clear claimed status to test auto-claim',
                onTap: () async {
                  await _debugService.applyMockYesterdayData(
                    userSteps: 8000,
                    partnerSteps: 6000,
                    claimed: false,
                  );
                  _showSnackBar('Yesterday reset - auto-claim will trigger on next app launch');
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Current Storage State
        _buildSection(
          title: 'Current Storage State',
          child: _buildStorageInfo(),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              _formatNumber(value.toInt()),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 15000,
          divisions: 150,
          activeColor: Colors.deepOrange,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.deepOrange,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetButton({
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.deepOrange.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.deepOrange, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageInfo() {
    final today = _storage.getTodaySteps();
    final yesterday = _storage.getYesterdaySteps();
    final connection = _storage.getStepsConnection();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Connection', connection?.isConnected == true ? 'Connected' : 'Not Connected'),
        _buildInfoRow('Partner', connection?.partnerConnected == true ? 'Connected' : 'Not Connected'),
        const Divider(),
        const Text('Today:', style: TextStyle(fontWeight: FontWeight.w600)),
        if (today != null) ...[
          _buildInfoRow('  Your Steps', _formatNumber(today.userSteps)),
          _buildInfoRow('  Partner Steps', _formatNumber(today.partnerSteps)),
          _buildInfoRow('  Combined', _formatNumber(today.combinedSteps)),
          _buildInfoRow('  LP', '+${today.earnedLP}'),
        ] else
          const Text('  No data', style: TextStyle(color: Colors.grey)),
        const Divider(),
        const Text('Yesterday:', style: TextStyle(fontWeight: FontWeight.w600)),
        if (yesterday != null) ...[
          _buildInfoRow('  Combined', _formatNumber(yesterday.combinedSteps)),
          _buildInfoRow('  LP', '+${yesterday.earnedLP}'),
          _buildInfoRow('  Claimed', yesterday.claimed ? 'Yes' : 'No'),
          _buildInfoRow('  Overlay Shown', yesterday.overlayShownAt != null ? 'Yes' : 'No'),
          _buildInfoRow('  Can Claim', yesterday.canClaim ? 'Yes' : 'No'),
        ] else
          const Text('  No data', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showMilestoneCelebration() {
    final partner = _storage.getPartner();
    final userSteps = _userStepsSlider.toInt() > 0 ? _userStepsSlider.toInt() : 7000;
    final partnerSteps = _partnerStepsSlider.toInt() > 0 ? _partnerStepsSlider.toInt() : 5500;

    showStepsMilestoneOverlay(
      context: context,
      previousTier: 10000,
      newTier: 12000,
      combinedSteps: userSteps + partnerSteps,
      userSteps: userSteps,
      partnerSteps: partnerSteps,
      partnerName: partner?.name ?? 'Partner',
      previousLP: 15,
      newLP: 18,
    );
  }

  void _showAutoClaimOverlay({required bool isCurrentUserClaimer}) {
    final user = _storage.getUser();
    final partner = _storage.getPartner();

    // Create mock steps data for overlay
    final mockStepsDay = StepsDay(
      dateKey: 'debug-mock',
      userSteps: _userStepsSlider.toInt() > 0 ? _userStepsSlider.toInt() : 7500,
      partnerSteps: _partnerStepsSlider.toInt() > 0 ? _partnerStepsSlider.toInt() : 6500,
      lastSync: DateTime.now(),
      partnerLastSync: DateTime.now(),
      claimed: true,
      earnedLP: StepsDay.calculateLP(
        (_userStepsSlider.toInt() > 0 ? _userStepsSlider.toInt() : 7500) +
        (_partnerStepsSlider.toInt() > 0 ? _partnerStepsSlider.toInt() : 6500),
      ),
    );

    showStepsAutoClaimOverlay(
      context: context,
      stepsDay: mockStepsDay,
      isCurrentUserClaimer: isCurrentUserClaimer,
      partnerName: partner?.name ?? 'Partner',
      userName: user?.name ?? 'You',
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
    return number.toString();
  }

  String _getTierName(int combinedSteps) {
    if (combinedSteps >= 20000) return '20K';
    if (combinedSteps >= 18000) return '18K';
    if (combinedSteps >= 16000) return '16K';
    if (combinedSteps >= 14000) return '14K';
    if (combinedSteps >= 12000) return '12K';
    if (combinedSteps >= 10000) return '10K';
    return '<10K';
  }
}
