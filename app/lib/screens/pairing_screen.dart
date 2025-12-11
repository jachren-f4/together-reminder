import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:togetherremind/models/partner.dart';
import 'package:togetherremind/models/pairing_code.dart';
import 'package:togetherremind/screens/home_screen.dart';
import 'package:togetherremind/services/storage_service.dart';
import 'package:togetherremind/services/notification_service.dart';
import 'package:togetherremind/services/couple_pairing_service.dart';
import 'package:togetherremind/services/auth_service.dart';
import 'package:togetherremind/services/quest_initialization_service.dart';
import 'package:togetherremind/services/unlock_service.dart';
import 'welcome_quiz_intro_screen.dart';
import 'package:togetherremind/test/test_keys.dart';
import 'package:togetherremind/theme/app_theme.dart';
import 'package:togetherremind/widgets/newspaper/newspaper_widgets.dart';
import '../utils/logger.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final StorageService _storageService = StorageService();
  final CouplePairingService _couplePairingService = CouplePairingService();

  // QR scanner state - kept but hidden
  bool _showScanner = false;
  String? _qrData;

  // Remote pairing state
  PairingCode? _generatedCode;
  bool _isGeneratingCode = false;
  bool _isWaitingForPartner = false;
  Timer? _countdownTimer;
  Timer? _pairingStatusTimer;
  Timer? _globalPairingTimer; // For QR code flow detection
  bool _isVerifyingCode = false;

  // Controller for partner code input
  final TextEditingController _partnerCodeController = TextEditingController();

  // Pairing success state - show success message before navigation
  bool _pairingSuccessful = false;
  String? _pairedPartnerName;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
    _generateRemoteCode(); // Auto-generate pairing code on load
    _listenForPairingConfirmation();
    _startGlobalPairingPolling(); // Poll for pairing status (works for QR code flow too)
  }

  /// Start polling for pairing status globally (not just for Remote tab)
  /// This allows detecting when partner scans our QR code and creates couple on server
  void _startGlobalPairingPolling() {
    _globalPairingTimer?.cancel();
    Logger.debug('Starting global pairing poll (every 5s)', service: 'pairing');

    _globalPairingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        Logger.debug('Polling for couple status...', service: 'pairing');
        final status = await _couplePairingService.getStatus();
        Logger.debug('Couple status result: ${status != null ? 'PAIRED with ${status.partnerName}' : 'NOT PAIRED'}', service: 'pairing');

        if (status != null && mounted) {
          Logger.success('Pairing detected via poll! Partner: ${status.partnerName}', service: 'pairing');
          timer.cancel();
          _countdownTimer?.cancel();
          _pairingStatusTimer?.cancel();
          _globalPairingTimer = null;

          // Show success state before navigating
          setState(() {
            _pairingSuccessful = true;
            _pairedPartnerName = status.partnerName;
          });

          // Partner already saved by getStatus() when it parses the partner object
          // Just navigate to home
          await _completeOnboarding();
        }
      } catch (e) {
        Logger.error('Error in global pairing poll', error: e, service: 'pairing');
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pairingStatusTimer?.cancel();
    _globalPairingTimer?.cancel();
    _partnerCodeController.dispose();
    super.dispose();
  }

  /// Complete onboarding after pairing - check unlock state and navigate
  Future<void> _completeOnboarding() async {
    // Check if Welcome Quiz has been completed
    final unlockService = UnlockService();
    final unlockState = await unlockService.getUnlockState();

    if (mounted) {
      if (unlockState != null && unlockState.welcomeQuizCompleted) {
        // Welcome Quiz already completed - initialize quests and go to home
        final initService = QuestInitializationService();
        final result = await initService.ensureQuestsInitialized();

        if (result.isSuccess) {
          Logger.debug('Quest init completed: $result', service: 'pairing');
        } else {
          Logger.error('Quest init failed: ${result.errorMessage}', service: 'pairing');
          // Still navigate to home - quests will be synced later
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else {
        // Welcome Quiz not completed - go to Welcome Quiz intro
        Logger.debug('Navigating to Welcome Quiz intro', service: 'pairing');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const WelcomeQuizIntroScreen(),
          ),
        );
      }
    }
  }

  void _listenForPairingConfirmation() {
    NotificationService.onPairingComplete = (partnerName, partnerToken) async {
      // When receiving push notification about pairing, fetch status from server
      // to get complete partner data instead of creating locally
      try {
        final status = await _couplePairingService.getStatus();
        if (status != null) {
          // Partner already saved by getStatus()
          await _completeOnboarding();
          return;
        }
      } catch (e) {
        Logger.error('Failed to fetch status after pairing notification', error: e, service: 'pairing');
      }

      // Fallback: create basic partner from notification data
      // This should rarely be needed since getStatus() should work
      final partner = Partner(
        name: partnerName,
        pushToken: partnerToken,
        pairedAt: DateTime.now(),
        avatarEmoji: '💕',
      );

      await _storageService.savePartner(partner);
      await _completeOnboarding();
    };
  }

  void _generateQRCode() async {
    // Use auth service userId - single source of truth
    final authService = AuthService();
    final userId = await authService.getUserId();

    if (userId == null) {
      Logger.error('Not authenticated - cannot generate QR code', service: 'pairing');
      return;
    }

    final user = _storageService.getUser();
    final pushToken = await NotificationService.getToken();

    Logger.debug('Generating QR code for userId: $userId', service: 'pairing');

    final pairingData = {
      'userId': userId,
      'name': user?.name ?? 'Partner',
      'pushToken': pushToken ?? '', // No fallback to placeholder - use empty string
      'platform': Platform.isIOS ? 'ios' : 'android',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    Logger.debug('QR code data: $pairingData', service: 'pairing');

    setState(() {
      _qrData = jsonEncode(pairingData);
    });
  }

  void _openScanner() {
    setState(() {
      _showScanner = true;
    });
  }

  Future<void> _handleScannedCode(String rawValue) async {
    try {
      final data = jsonDecode(rawValue);

      Logger.debug('Scanned QR data: $data', service: 'pairing');

      final partnerId = data['userId'] as String?;
      final partnerName = data['name'] as String? ?? 'Partner';

      if (partnerId == null) {
        throw Exception('Invalid QR code - no userId');
      }

      // Create couple on server via API (this allows partner to poll and detect pairing)
      try {
        final partner = await _couplePairingService.pairDirect(partnerId, partnerName);
        Logger.success('Server pairing successful: ${partner.name}', service: 'pairing');

        // Also try to send push notification as backup (might not work in dev)
        final user = _storageService.getUser();
        final myPushToken = await NotificationService.getToken();
        final partnerPushToken = data['pushToken'] as String?;

        if (user != null && myPushToken != null && partnerPushToken != null && partnerPushToken.isNotEmpty) {
          try {
            await NotificationService.sendPairingConfirmation(
              partnerToken: partnerPushToken,
              myName: user.name ?? 'Partner',
              myPushToken: myPushToken,
            );
            Logger.debug('Sent push notification to partner', service: 'pairing');
          } catch (pushError) {
            Logger.warn('Push notification failed (server pairing still works)', service: 'pairing');
          }
        }

        await _completeOnboarding();
      } catch (apiError) {
        Logger.error('API pairing failed', error: apiError, service: 'pairing');
        // Don't fall back to local-only - server-side pairing is required
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pairing failed: ${apiError.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Error handling scanned QR code', error: e, service: 'pairing');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code. Please try again.')),
        );
      }
    }
  }

  // Remote Pairing Methods
  Future<void> _generateRemoteCode() async {
    setState(() {
      _isGeneratingCode = true;
    });

    try {
      final code = await _couplePairingService.generatePairingCode();
      setState(() {
        _generatedCode = code;
        _isGeneratingCode = false;
        _isWaitingForPartner = true;
      });

      _startCountdownTimer();
      _startPairingStatusPolling();
    } catch (e) {
      setState(() {
        _isGeneratingCode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _generatedCode == null) {
        timer.cancel();
        return;
      }

      if (_generatedCode!.isExpired) {
        timer.cancel();
        _pairingStatusTimer?.cancel();
        setState(() {
          _generatedCode = null;
          _isWaitingForPartner = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code expired. Please generate a new one.')),
        );
      } else {
        setState(() {});
      }
    });
  }

  void _startPairingStatusPolling() {
    _pairingStatusTimer?.cancel();
    _pairingStatusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || !_isWaitingForPartner) {
        timer.cancel();
        return;
      }

      try {
        final status = await _couplePairingService.getStatus();
        if (status != null && mounted) {
          timer.cancel();
          _countdownTimer?.cancel();
          _globalPairingTimer?.cancel();

          // Show success state before navigating
          setState(() {
            _pairingSuccessful = true;
            _pairedPartnerName = status.partnerName;
          });

          // Partner already saved by getStatus() when it parses the partner object
          // Just navigate to home
          await _completeOnboarding();
        }
      } catch (e) {
        Logger.error('Error polling pairing status', error: e, service: 'pairing');
      }
    });
  }

  Future<void> _verifyCode(String code) async {
    // Prevent double submission
    if (_isVerifyingCode || _pairingSuccessful) return;

    setState(() {
      _isVerifyingCode = true;
    });

    try {
      final partner = await _couplePairingService.joinWithCode(code);

      // Show success state before navigation (keeps UI stable)
      if (mounted) {
        setState(() {
          _pairingSuccessful = true;
          _pairedPartnerName = partner.name;
          _partnerCodeController.clear();
        });
      }

      // Cancel all timers since we're paired
      _countdownTimer?.cancel();
      _pairingStatusTimer?.cancel();
      _globalPairingTimer?.cancel();

      if (mounted) {
        await _completeOnboarding();
      }
    } catch (e) {
      setState(() {
        _isVerifyingCode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyCode() {
    if (_generatedCode != null) {
      Clipboard.setData(ClipboardData(text: _generatedCode!.code));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareCode() {
    if (_generatedCode != null) {
      Share.share(
        'My TogetherRemind pairing code: ${_generatedCode!.code}\n\nThis code expires in ${_generatedCode!.formattedTimeRemaining}.',
        subject: 'TogetherRemind Pairing Code',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: NewspaperColors.surface,
        child: SafeArea(
          child: _showScanner ? _buildScanner() : _buildMainView(),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      children: [
        // Masthead
        const NewspaperMasthead(
          date: 'Connection',
          title: 'TogetherRemind',
          subtitle: 'Step 3 of 3',
        ),

        // Content - Option C Minimal Design OR Success State
        Expanded(
          child: _pairingSuccessful
              ? _buildSuccessState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      // Your Code Section
                      _buildYourCodeSection(),

                      const SizedBox(height: 24),

                      // Divider
                      _buildOrDivider('or enter partner\'s code'),

                      const SizedBox(height: 24),

                      // Enter Partner's Code Section
                      _buildEnterCodeSection(),

                      // QR Code option is hidden but code is kept
                      // To re-enable, uncomment below:
                      // const SizedBox(height: 32),
                      // _buildQrCodeLink(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: NewspaperColors.calloutBg,
                border: Border.all(color: NewspaperColors.border, width: 2),
              ),
              child: const Icon(
                Icons.favorite,
                size: 40,
                color: NewspaperColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Success message
            Text(
              'Paired!',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: NewspaperColors.primary,
              ),
            ),
            const SizedBox(height: 8),

            if (_pairedPartnerName != null) ...[
              Text(
                'Connected with $_pairedPartnerName',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 16,
                  color: NewspaperColors.secondary,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Loading indicator
            Text(
              'Preparing your experience...',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 13,
                color: NewspaperColors.tertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: NewspaperColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourCodeSection() {
    return Column(
      children: [
        // Label
        Text(
          'YOUR CODE',
          style: AppTheme.bodyFont.copyWith(
            fontSize: 11,
            letterSpacing: 3,
            color: NewspaperColors.tertiary,
          ),
        ),
        const SizedBox(height: 12),

        // Big Code Display
        if (_generatedCode != null) ...[
          Text(
            key: TestKeys.yourCodeDisplay,
            _generatedCode!.code,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: NewspaperColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Expires in ${_generatedCode!.formattedTimeRemaining}',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 12,
              color: NewspaperColors.tertiary,
            ),
          ),
          const SizedBox(height: 16),
          // Copy/Share buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconButton(Icons.copy, 'Copy', _copyCode),
              const SizedBox(width: 12),
              _buildIconButton(Icons.share, 'Share', _shareCode),
            ],
          ),
        ] else if (_isGeneratingCode) ...[
          const SizedBox(height: 20),
          const CircularProgressIndicator(
            strokeWidth: 2,
            color: NewspaperColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Generating code...',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              color: NewspaperColors.tertiary,
            ),
          ),
        ] else ...[
          // Error state - show retry
          const SizedBox(height: 12),
          Text(
            'Could not generate code',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              color: NewspaperColors.secondary,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _generateRemoteCode,
            child: Text(
              'Tap to retry',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 13,
                color: NewspaperColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: NewspaperColors.calloutBg,
            border: Border.all(color: NewspaperColors.border, width: 1),
          ),
          child: Icon(
            icon,
            size: 20,
            color: NewspaperColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider(String text) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: NewspaperColors.tertiary,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text.toUpperCase(),
            style: AppTheme.bodyFont.copyWith(
              fontSize: 10,
              letterSpacing: 2,
              color: NewspaperColors.tertiary,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: NewspaperColors.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildEnterCodeSection() {
    return Column(
      children: [
        // Single input field
        TextField(
          key: TestKeys.partnerCodeTextField,
          controller: _partnerCodeController,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          style: AppTheme.headlineFont.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: 10,
            color: NewspaperColors.primary,
          ),
          decoration: InputDecoration(
            hintText: '_ _ _ _ _ _',
            hintStyle: AppTheme.headlineFont.copyWith(
              fontSize: 28,
              color: NewspaperColors.tertiary.withOpacity(0.4),
              letterSpacing: 10,
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: NewspaperColors.border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: NewspaperColors.border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: NewspaperColors.primary, width: 2),
            ),
            filled: true,
            fillColor: NewspaperColors.surface,
          ),
          onChanged: (value) {
            // Auto-submit when 6 characters entered
            if (value.length == 6) {
              _verifyCode(value.toUpperCase());
            }
          },
        ),
        const SizedBox(height: 16),

        // Join button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: TestKeys.joinPartnerButton,
            onPressed: _isVerifyingCode
                ? null
                : () {
                    final code = _partnerCodeController.text.trim();
                    if (code.length == 6) {
                      _verifyCode(code.toUpperCase());
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: NewspaperColors.primary,
              foregroundColor: NewspaperColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              disabledBackgroundColor: NewspaperColors.tertiary,
            ),
            child: _isVerifyingCode
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NewspaperColors.surface,
                    ),
                  )
                : Text(
                    'JOIN PARTNER',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // QR Code link - kept but hidden
  // ignore: unused_element
  Widget _buildQrCodeLink() {
    return GestureDetector(
      onTap: _openScanner,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 16,
            color: NewspaperColors.tertiary,
          ),
          const SizedBox(width: 8),
          Text(
            'Use QR Code Instead',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              color: NewspaperColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInPersonTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // QR Code Section
          if (_qrData != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: NewspaperColors.surface,
                border: Border.all(color: NewspaperColors.border, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'YOUR QR CODE',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 10,
                      letterSpacing: 3,
                      color: NewspaperColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: NewspaperColors.border, width: 2),
                    ),
                    child: QrImageView(
                      data: _qrData!,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Have your partner scan this code',
                    style: AppTheme.headlineFont.copyWith(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: NewspaperColors.secondary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          const NewspaperOrDivider(),

          const SizedBox(height: 16),

          NewspaperSecondaryButton(
            text: "Scan Partner's Code",
            onPressed: _openScanner,
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteTab() {
    if (_isWaitingForPartner && _generatedCode != null) {
      return _buildWaitingScreen();
    } else if (_generatedCode != null) {
      return _buildCodeDisplayScreen();
    } else {
      return _buildRemoteChoiceScreen();
    }
  }

  Widget _buildRemoteChoiceScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Code banner (generate first)
          NewspaperPrimaryButton(
            text: 'Generate Pairing Code',
            onPressed: _isGeneratingCode ? null : _generateRemoteCode,
            isLoading: _isGeneratingCode,
          ),

          const SizedBox(height: 16),

          const NewspaperOrDivider(),

          const SizedBox(height: 16),

          NewspaperSecondaryButton(
            text: "Enter Partner's Code",
            onPressed: _showEnterCodeDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeDisplayScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Code banner
          NewspaperCodeBanner(
            label: 'Your Pairing Code',
            code: _generatedCode!.code,
            timer: 'Expires in ${_generatedCode!.formattedTimeRemaining}',
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: NewspaperSecondaryButton(
                  text: 'Copy Code',
                  onPressed: _copyCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NewspaperSecondaryButton(
                  text: 'Share via Text',
                  onPressed: _shareCode,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const NewspaperOrDivider(),

          const SizedBox(height: 16),

          NewspaperSecondaryButton(
            text: "Enter Partner's Code",
            onPressed: _showEnterCodeDialog,
          ),

          const SizedBox(height: 24),

          // Generate new code link
          GestureDetector(
            onTap: () {
              setState(() {
                _generatedCode = null;
                _isWaitingForPartner = false;
              });
              _countdownTimer?.cancel();
              _pairingStatusTimer?.cancel();
            },
            child: Text(
              'Generate New Code',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                color: NewspaperColors.secondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Waiting animation
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(NewspaperColors.primary),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Waiting for partner',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: NewspaperColors.primary,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            "They'll enter your code to complete pairing",
            textAlign: TextAlign.center,
            style: AppTheme.headlineFont.copyWith(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: NewspaperColors.secondary,
            ),
          ),

          const SizedBox(height: 32),

          // Code reminder
          NewspaperCodeBanner(
            label: 'Your Code',
            code: _generatedCode!.code,
            timer: 'Expires in ${_generatedCode!.formattedTimeRemaining}',
          ),

          const SizedBox(height: 24),

          NewspaperSecondaryButton(
            text: 'Copy Code Again',
            onPressed: _copyCode,
          ),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: () {
              setState(() {
                _generatedCode = null;
                _isWaitingForPartner = false;
              });
              _countdownTimer?.cancel();
              _pairingStatusTimer?.cancel();
            },
            child: Text(
              'Cancel Pairing',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                color: NewspaperColors.secondary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEnterCodeDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: NewspaperColors.surface,
        title: Text(
          'ENTER CODE',
          style: AppTheme.bodyFont.copyWith(
            fontSize: 11,
            letterSpacing: 3,
            color: NewspaperColors.secondary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-character code',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 18,
                color: NewspaperColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: 12,
                color: NewspaperColors.primary,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: 32,
                  color: NewspaperColors.tertiary.withOpacity(0.4),
                  letterSpacing: 12,
                ),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: NewspaperColors.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: NewspaperColors.border, width: 2),
                ),
                filled: true,
                fillColor: NewspaperColors.calloutBg,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTheme.bodyFont.copyWith(
                color: NewspaperColors.secondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.length == 6) {
                Navigator.pop(context);
                _verifyCode(code);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: NewspaperColors.primary,
              foregroundColor: NewspaperColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(
              'VERIFY CODE',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationDialog(Partner partner) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: NewspaperColors.surface,
      title: Text(
        'CONFIRM PAIRING',
        style: AppTheme.bodyFont.copyWith(
          fontSize: 11,
          letterSpacing: 3,
          color: NewspaperColors.secondary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pair with this person?',
            style: AppTheme.headlineFont.copyWith(
              fontSize: 18,
              color: NewspaperColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NewspaperColors.calloutBg,
              border: Border.all(color: NewspaperColors.border, width: 1),
            ),
            child: Column(
              children: [
                GrayscaleEmoji(
                  emoji: partner.avatarEmoji ?? '💕',
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  partner.name,
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 24,
                    color: NewspaperColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const NewspaperCalloutBox(
            title: 'Privacy First',
            text: 'You can only be paired with one person at a time. You can unpair anytime from Settings.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: AppTheme.bodyFont.copyWith(
              color: NewspaperColors.secondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: NewspaperColors.primary,
            foregroundColor: NewspaperColors.surface,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          child: Text(
            'YES, PAIR',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _handleScannedCode(barcode.rawValue!);
                break;
              }
            }
          },
        ),
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            decoration: BoxDecoration(
              color: NewspaperColors.surface,
              border: Border.all(color: NewspaperColors.border, width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: NewspaperColors.primary),
              onPressed: () {
                setState(() {
                  _showScanner = false;
                });
              },
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: NewspaperColors.primary,
              child: Text(
                "Point camera at partner's QR code",
                style: AppTheme.bodyFont.copyWith(
                  color: NewspaperColors.surface,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
