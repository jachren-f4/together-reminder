import 'package:flutter/material.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/couple_preferences_service.dart';
import 'package:togetherremind/services/api_client.dart';
import 'package:togetherremind/services/sound_service.dart';
import 'package:togetherremind/services/haptic_service.dart';
import 'package:togetherremind/theme/app_theme.dart';
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
  final SoundService _soundService = SoundService();
  final HapticService _hapticService = HapticService();

  String? _firstPlayerId;
  String? _user1Id;
  String? _user2Id;
  bool _loadingPreferences = false;
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadSoundHapticPreferences();
  }

  Future<void> _loadSoundHapticPreferences() async {
    setState(() {
      _soundEnabled = _soundService.isEnabled;
      _hapticEnabled = _hapticService.isEnabled;
    });
  }

  Future<void> _loadPreferences() async {
    setState(() => _loadingPreferences = true);
    try {
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
      _loadPreferences();
    }
  }

  Future<void> _editName() async {
    final user = _storageService.getUser();
    if (user == null) return;

    final controller = TextEditingController(text: user.name ?? '');

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != user.name) {
      final updatedUser = user.copyWith(name: newName);
      await _storageService.saveUser(updatedUser);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated')),
        );
      }
    }
  }

  Future<void> _editAvatar() async {
    final user = _storageService.getUser();
    if (user == null) return;

    final emojis = ['😊', '😎', '🥰', '😇', '🤗', '😄', '🙂', '😁', '🤩', '😋', '🥳', '😏'];

    final newEmoji = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Avatar'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: emojis.map((emoji) => GestureDetector(
            onTap: () => Navigator.pop(context, emoji),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: user.avatarEmoji == emoji
                    ? AppTheme.primaryBlack
                    : AppTheme.backgroundGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (newEmoji != null && newEmoji != user.avatarEmoji) {
      final updatedUser = user.copyWith(avatarEmoji: newEmoji);
      await _storageService.saveUser(updatedUser);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = _storageService.getPartner();
    final user = _storageService.getUser();

    return Container(
      color: AppTheme.primaryWhite,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.primaryBlack, width: 2),
                  ),
                ),
                child: Text(
                  'SETTINGS',
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                    letterSpacing: 3,
                  ),
                ),
              ),

              // Partner Banner
              if (partner != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    border: Border(
                      bottom: BorderSide(color: AppTheme.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Initial circle
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlack,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            partner.name.isNotEmpty ? partner.name[0].toUpperCase() : 'P',
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryWhite,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner.name,
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PARTNER SINCE ${DateFormat('MMM yyyy').format(partner.pairedAt).toUpperCase()}',
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 11,
                              color: const Color(0xFF888888),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Profile Section
              if (user != null)
                _SettingsGroup(
                  title: 'PROFILE',
                  children: [
                    _SettingRow(
                      label: 'Name',
                      value: user.name ?? 'Not set',
                      onTap: _editName,
                    ),
                    _SettingRow(
                      label: 'Avatar',
                      value: 'Tap to change',
                      onTap: _editAvatar,
                    ),
                  ],
                ),

              // Sound Section
              _SettingsGroup(
                title: 'SOUND',
                children: [
                  _ToggleRow(
                    label: 'Sound Effects',
                    value: _soundEnabled,
                    onChanged: (value) async {
                      // Play toggle sound BEFORE disabling (user hears confirmation)
                      if (_soundEnabled) {
                        await _soundService.play(value ? SoundId.toggleOn : SoundId.toggleOff);
                      }
                      setState(() => _soundEnabled = value);
                      await _soundService.setEnabled(value);
                      // Play toggle on sound AFTER enabling
                      if (value) {
                        await _soundService.play(SoundId.toggleOn);
                      }
                      // Haptic feedback for toggle
                      _hapticService.trigger(HapticType.selection);
                    },
                  ),
                  _ToggleRow(
                    label: 'Haptic Feedback',
                    value: _hapticEnabled,
                    onChanged: (value) async {
                      // Trigger haptic BEFORE disabling (user feels confirmation)
                      _hapticService.trigger(HapticType.selection);
                      setState(() => _hapticEnabled = value);
                      await _hapticService.setEnabled(value);
                      // Sound feedback for toggle
                      _soundService.play(value ? SoundId.toggleOn : SoundId.toggleOff);
                    },
                  ),
                ],
              ),

              // Games Section
              if (user != null && partner != null)
                _SettingsGroup(
                  title: 'GAMES',
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Who goes first?',
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_user1Id != null && _user2Id != null)
                            Row(
                              children: [
                                Expanded(
                                  child: _PickerOption(
                                    label: 'You',
                                    isSelected: _firstPlayerId == (_user1Id == user.id ? _user1Id : _user2Id),
                                    onTap: () => _updateFirstPlayer(
                                      _user1Id == user.id ? _user1Id! : _user2Id!,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _PickerOption(
                                    label: partner.name,
                                    isSelected: _firstPlayerId == (_user1Id == user.id ? _user2Id : _user1Id),
                                    onTap: () => _updateFirstPlayer(
                                      _user1Id == user.id ? _user2Id! : _user1Id!,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (_loadingPreferences)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.borderLight),
                  ),
                ),
                child: Center(
                  child: GestureDetector(
                    onLongPress: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DataValidationScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'TOGETHERREMIND V1.0.0',
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 11,
                        color: const Color(0xFFAAAAAA),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              title,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF999999),
                letterSpacing: 2,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 12,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '›',
              style: TextStyle(
                fontSize: 18,
                color: const Color(0xFFCCCCCC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _MiniToggle(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MiniToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: value ? AppTheme.primaryBlack : const Color(0xFFDDDDDD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.primaryWhite,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlack : AppTheme.primaryWhite,
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlack : AppTheme.borderLight,
          ),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isSelected ? AppTheme.primaryWhite : AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
