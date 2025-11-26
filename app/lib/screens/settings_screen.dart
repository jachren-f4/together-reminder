import 'package:flutter/material.dart';
import 'package:togetherremind/screens/onboarding_screen.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/couple_preferences_service.dart';
import 'package:togetherremind/services/api_client.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/config/brand/brand_loader.dart';
import 'package:intl/intl.dart';
import 'debug/data_validation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();
  final CouplePreferencesService _preferencesService = CouplePreferencesService();

  String? _firstPlayerId;
  String? _user1Id;
  String? _user2Id;
  bool _loadingPreferences = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _loadingPreferences = true);
    try {
      // Fetch preferences from API to get user IDs and first player preference
      final apiClient = ApiClient();
      final response = await apiClient.get('/api/sync/couple-preferences');

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _firstPlayerId = data['firstPlayerId'] as String;
          _user1Id = data['user1Id'] as String;
          _user2Id = data['user2Id'] as String;
          _loadingPreferences = false;
        });
      } else {
        setState(() => _loadingPreferences = false);
      }
    } catch (e) {
      setState(() => _loadingPreferences = false);
    }
  }

  Future<void> _updateFirstPlayer(String userId) async {
    try {
      setState(() => _firstPlayerId = userId);
      await _preferencesService.setFirstPlayerId(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game preference updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update preference: $e')),
        );
      }
      // Reload to revert UI change
      _loadPreferences();
    }
  }

  Future<void> _unpairPartner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Partner?'),
        content: const Text(
          'This will remove your partner and clear all reminders. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: BrandLoader().colors.error),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.clearAllData();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = _storageService.getPartner();
    final user = _storageService.getUser();
    final allReminders = _storageService.getAllReminders();
    final sentCount = _storageService.getSentReminders().length;
    final receivedCount = _storageService.getReceivedReminders().length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundGray,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Settings',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 30),

                // Partner Info Card
                if (partner != null) ...[
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PARTNER',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundGray,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderLight, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  partner.avatarEmoji ?? '👤',
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    partner.name,
                                    style: AppTheme.bodyFont.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Paired ${DateFormat('MMM d, yyyy').format(partner.pairedAt)}',
                                    style: AppTheme.bodyFont.copyWith(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                label: 'Sent',
                                value: sentCount.toString(),
                                emoji: '💌',
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: 'Received',
                                value: receivedCount.toString(),
                                emoji: '📬',
                              ),
                            ),
                            Expanded(
                              child: _StatItem(
                                label: 'Total',
                                value: allReminders.length.toString(),
                                emoji: '📊',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // User Info
                if (user != null) ...[
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR INFO',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingRow(
                          icon: '👤',
                          label: 'Name',
                          value: user.name ?? 'Not set',
                        ),
                        const SizedBox(height: 12),
                        _SettingRow(
                          icon: '📱',
                          label: 'User ID',
                          value: user.id.substring(0, 8) + '...',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Preferences
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PREFERENCES',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SettingRow(
                        icon: '🔔',
                        label: 'Notifications',
                        value: 'Enabled',
                        trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                      ),
                      const SizedBox(height: 12),
                      _SettingRow(
                        icon: '🌙',
                        label: 'Do Not Disturb',
                        value: 'Off',
                        trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Game Preferences
                if (user != null && partner != null) ...[
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GAME PREFERENCES',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_user1Id != null && _user2Id != null)
                          _PartnerToggle(
                            label: 'Goes first in new games',
                            user1Id: _user1Id == user.id ? _user1Id! : _user2Id!,
                            user1Name: user.name ?? 'You',
                            user2Id: _user1Id == user.id ? _user2Id! : _user1Id!,
                            user2Name: partner.name,
                            user2Emoji: partner.avatarEmoji ?? '👤',
                            selectedUserId: _firstPlayerId,
                            onChanged: _updateFirstPlayer,
                            isLoading: _loadingPreferences,
                          )
                        else
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Data Management
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DATA',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textTertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          // TODO: Export data functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export feature coming soon')),
                          );
                        },
                        child: _SettingRow(
                          icon: '💾',
                          label: 'Export Data',
                          value: '',
                          trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear History?'),
                              content: const Text(
                                'This will delete all reminders but keep your partner connection.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: BrandLoader().colors.error),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await _storageService.clearAllReminders();
                            setState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('History cleared')),
                              );
                            }
                          }
                        },
                        child: _SettingRow(
                          icon: '🗑️',
                          label: 'Clear History',
                          value: '',
                          trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Unpair button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _unpairPartner,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BrandLoader().colors.error,
                      side: BorderSide(color: BrandLoader().colors.error, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.link_off),
                        const SizedBox(width: 8),
                        Text(
                          'Unpair Partner',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // App version
                Center(
                  child: GestureDetector(
                    onLongPress: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DataValidationScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'TogetherRemind v1.0.0\nMade with 💕',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: BrandLoader().colors.textPrimary.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (value.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String emoji;

  const _StatItem({
    required this.label,
    required this.value,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _PartnerToggle extends StatelessWidget {
  final String label;
  final String user1Id;
  final String user1Name;
  final String user2Id;
  final String user2Name;
  final String user2Emoji;
  final String? selectedUserId;
  final Function(String) onChanged;
  final bool isLoading;

  const _PartnerToggle({
    required this.label,
    required this.user1Id,
    required this.user1Name,
    required this.user2Id,
    required this.user2Name,
    required this.user2Emoji,
    required this.selectedUserId,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _PartnerOption(
                name: user1Name,
                emoji: '👤',
                isSelected: selectedUserId == user1Id,
                onTap: () => onChanged(user1Id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PartnerOption(
                name: user2Name,
                emoji: user2Emoji,
                isSelected: selectedUserId == user2Id,
                onTap: () => onChanged(user2Id),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PartnerOption extends StatelessWidget {
  final String name;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _PartnerOption({
    required this.name,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlack : AppTheme.backgroundGray,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlack : AppTheme.borderLight,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryWhite : AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
