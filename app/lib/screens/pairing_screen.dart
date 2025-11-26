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
import 'package:togetherremind/theme/app_theme.dart';
import '../config/brand/brand_loader.dart';
import '../utils/logger.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final CouplePairingService _couplePairingService = CouplePairingService();

  late TabController _tabController;
  bool _showScanner = false;
  String? _qrData;

  // Remote pairing state
  PairingCode? _generatedCode;
  bool _isGeneratingCode = false;
  bool _isWaitingForPartner = false;
  Timer? _countdownTimer;
  Timer? _pairingStatusTimer;
  String? _codeInput;
  bool _isVerifyingCode = false;
  Map<String, dynamic>? _partnerData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateQRCode();
    _listenForPairingConfirmation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    _pairingStatusTimer?.cancel();
    super.dispose();
  }

  void _listenForPairingConfirmation() {
    // Listen for pairing confirmation from partner
    NotificationService.onPairingComplete = (partnerName, partnerToken) async {
      final partner = Partner(
        name: partnerName,
        pushToken: partnerToken,
        pairedAt: DateTime.now(),
        avatarEmoji: '👤',
      );

      await _storageService.savePartner(partner);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    };
  }

  void _generateQRCode() async {
    final user = _storageService.getUser();
    if (user == null) return;

    // Get real FCM token
    final pushToken = await NotificationService.getToken();

    Logger.debug('Generating QR code with push token: $pushToken', service: 'pairing');

    final pairingData = {
      'userId': user.id,
      'name': user.name ?? 'Partner',
      'pushToken': pushToken ?? user.pushToken,
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

      final partner = Partner(
        name: data['name'] ?? 'Partner',
        pushToken: data['pushToken'] ?? '',
        pairedAt: DateTime.now(),
        avatarEmoji: '👤',
      );

      await _storageService.savePartner(partner);

      // Send pairing confirmation back to the QR generator
      final user = _storageService.getUser();
      final myPushToken = await NotificationService.getToken();

      Logger.debug('My push token: $myPushToken', service: 'pairing');
      Logger.debug('Partner push token: ${partner.pushToken}', service: 'pairing');
      Logger.debug('My name: ${user?.name}', service: 'pairing');

      if (user != null && myPushToken != null) {
        await NotificationService.sendPairingConfirmation(
          partnerToken: partner.pushToken,
          myName: user.name ?? 'Partner',
          myPushToken: myPushToken,
        );
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      }
    } catch (e) {
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

      // Start countdown timer
      _startCountdownTimer();

      // Start polling for pairing status
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
        // Trigger rebuild to update timer display
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
        if (status != null) {
          // Pairing completed! Stop polling
          timer.cancel();
          _countdownTimer?.cancel();

          // Create partner from status
          final partner = Partner(
            name: status.partnerName ?? status.partnerEmail?.split('@').first ?? 'Partner',
            pushToken: '', // Will be set up separately
            pairedAt: status.createdAt,
            avatarEmoji: '💕',
          );

          await _storageService.savePartner(partner);

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          }
        }
      } catch (e) {
        Logger.error('Error polling pairing status', error: e, service: 'pairing');
      }
    });
  }

  Future<void> _verifyCode(String code) async {
    setState(() {
      _isVerifyingCode = true;
    });

    try {
      final partner = await _couplePairingService.joinWithCode(code);

      setState(() {
        _isVerifyingCode = false;
      });

      // Show confirmation dialog
      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildConfirmationDialog(partner),
        );

        if (confirmed == true) {
          // Navigate to home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            ),
          );
        }
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
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: _showScanner ? _buildScanner() : _buildTabView(),
        ),
      ),
    );
  }

  Widget _buildTabView() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Text(
                'STEP 2 OF 2',
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pair with Partner',
                style: AppTheme.headlineFont.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share your code or scan theirs',
                textAlign: TextAlign.center,
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Tab Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.borderLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppTheme.primaryWhite,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: BrandLoader().colors.textPrimary.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppTheme.textPrimary,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: AppTheme.bodyFont.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'In Person'),
              Tab(text: 'Remote'),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInPersonTab(),
              _buildRemoteTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInPersonTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            // QR Code Section
            if (_qrData != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryWhite,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: BrandLoader().colors.textPrimary.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Your QR Code',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight, width: 2),
                      ),
                      child: QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 200.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Have your partner scan this code',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Scan Partner's Code Button
            GestureDetector(
              onTap: _openScanner,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryBlack, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      'Scan Partner\'s Code',
                      style: AppTheme.headlineFont.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to open camera',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyFont.copyWith(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryWhite.withAlpha((0.6 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pairing from different locations?',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint('Generate a pairing code'),
                  _buildBulletPoint('Share it with your partner via text or call'),
                  _buildBulletPoint('They\'ll enter the code to pair'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Generate Code Button
            _buildPrimaryButton(
              'Generate Pairing Code',
              _isGeneratingCode ? null : _generateRemoteCode,
              isLoading: _isGeneratingCode,
            ),

            const SizedBox(height: 12),

            // Enter Code Button
            _buildSecondaryButton(
              'Enter Partner\'s Code',
              () {
                _showEnterCodeDialog();
              },
            ),

            const SizedBox(height: 24),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: Color(0xFF2196F3), width: 4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tip',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Codes expire after 24 hours for security. You can regenerate a new code anytime.',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeDisplayScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            // Step Indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Share this code with your partner',
                textAlign: TextAlign.center,
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Code Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: BrandLoader().colors.textPrimary.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Your pairing code:',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.textTertiary.withAlpha((0.3 * 255).round()),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Text(
                      _generatedCode!.code,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Expires in ${_generatedCode!.formattedTimeRemaining}',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 14,
                      color: _generatedCode!.timeRemaining.inMinutes < 3
                          ? BrandLoader().colors.error
                          : AppTheme.textTertiary,
                      fontWeight: _generatedCode!.timeRemaining.inMinutes < 3
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Copy Button
            _buildPrimaryButton('📋 Copy Code', _copyCode),

            const SizedBox(height: 12),

            // Share Button
            _buildSecondaryButton('📱 Share via Text', _shareCode),

            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryWhite.withAlpha((0.6 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to share:',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint('Copy the code and send it via text message'),
                  _buildBulletPoint('Read it aloud during a phone/video call'),
                  _buildBulletPoint('Send through any messaging app'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: Color(0xFF2196F3), width: 4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⏱️', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code expires in 24 hours',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'For security, this code will expire automatically. You can generate a new one anytime.',
                          style: AppTheme.bodyFont.copyWith(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Generate New Code
            TextButton(
              onPressed: () {
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
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Waiting Animation
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlack),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Waiting for partner',
              style: AppTheme.headlineFont.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'They\'ll enter your code to complete pairing',
              textAlign: TextAlign.center,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),

            const SizedBox(height: 40),

            // Code Reminder
            Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                children: [
                  Text(
                    'Your code:',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _generatedCode!.code,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Expires in ${_generatedCode!.formattedTimeRemaining}',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 14,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSecondaryButton('📋 Copy Code Again', _copyCode),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () {
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
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showEnterCodeDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Enter Code',
          style: AppTheme.headlineFont.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-character code',
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: 12,
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 32,
                  color: AppTheme.textTertiary.withAlpha((0.4 * 255).round()),
                  letterSpacing: 12,
                ),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.borderLight, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryBlack, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.borderLight,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips:',
                    style: AppTheme.bodyFont.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSmallBulletPoint('Code is not case-sensitive'),
                  _buildSmallBulletPoint('Letters and numbers only (no spaces)'),
                  _buildSmallBulletPoint('Ask your partner for a new code if expired'),
                ],
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
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
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
              backgroundColor: AppTheme.primaryBlack,
              foregroundColor: AppTheme.primaryWhite,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Verify Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationDialog(Partner partner) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Confirm Pairing',
        style: AppTheme.headlineFont.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pair with this person?',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.borderLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  partner.avatarEmoji ?? '💕',
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 12),
                Text(
                  partner.name,
                  style: AppTheme.headlineFont.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(8),
              border: const Border(
                left: BorderSide(color: Color(0xFF2196F3), width: 4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy First',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can only be paired with one person at a time. You can unpair anytime from Settings.',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: AppTheme.bodyFont.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlack,
            foregroundColor: AppTheme.primaryWhite,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text('Yes, Pair with ${partner.name}'),
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
          child: CircleAvatar(
            backgroundColor: BrandLoader().colors.surface,
            child: IconButton(
              icon: Icon(Icons.close, color: AppTheme.primaryBlack),
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
          child: Text(
            'Point camera at partner\'s QR code',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandLoader().colors.textOnPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: BrandLoader().colors.textPrimary.withOpacity(0.54),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper Widgets
  Widget _buildPrimaryButton(String text, VoidCallback? onPressed,
      {bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlack,
          foregroundColor: AppTheme.primaryWhite,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryWhite),
                ),
              )
            : Text(
                text,
                style: AppTheme.bodyFont.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AppTheme.primaryBlack, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: AppTheme.bodyFont.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: AppTheme.bodyFont.copyWith(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyFont.copyWith(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
