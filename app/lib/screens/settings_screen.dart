import 'package:flutter/material.dart';
import 'package:togetherremind/screens/onboarding_screen.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storageService = StorageService();

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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      decoration: const BoxDecoration(
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
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                      ),
                      const SizedBox(height: 12),
                      _SettingRow(
                        icon: '🌙',
                        label: 'Do Not Disturb',
                        value: 'Off',
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

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
                        child: const _SettingRow(
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
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                        child: const _SettingRow(
                          icon: '🗑️',
                          label: 'Clear History',
                          value: '',
                          trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Unpair button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _unpairPartner,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 2),
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
            color: Colors.black.withAlpha((0.06 * 255).round()),
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
