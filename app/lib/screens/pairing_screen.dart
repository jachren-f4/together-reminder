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

  int _selectedTabIndex = 0;
  bool _showScanner = false;
  String? _qrData;

  // Remote pairing state
  PairingCode? _generatedCode;
  bool _isGeneratingCode = false;
  bool _isWaitingForPartner = false;
  Timer? _countdownTimer;
  Timer? _pairingStatusTimer;
  bool _isVerifyingCode = false;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
    _listenForPairingConfirmation();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pairingStatusTimer?.cancel();
    super.dispose();
  }

  void _listenForPairingConfirmation() {
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
        if (status != null) {
          timer.cancel();
          _countdownTimer?.cancel();

          final partner = Partner(
            name: status.partnerName ?? status.partnerEmail?.split('@').first ?? 'Partner',
            pushToken: '',
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

      if (mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _buildConfirmationDialog(partner),
        );

        if (confirmed == true) {
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

        // Article header
        const NewspaperArticleHeader(
          kicker: 'Partner Setup',
          headline: 'Connect with your partner',
        ),

        // Tab row
        NewspaperTabRow(
          tabs: const ['In Person', 'Remote'],
          selectedIndex: _selectedTabIndex,
          onTabSelected: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
          },
        ),

        // Tab content
        Expanded(
          child: _selectedTabIndex == 0 ? _buildInPersonTab() : _buildRemoteTab(),
        ),
      ],
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
