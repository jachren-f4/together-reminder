import 'package:flutter/foundation.dart';

/// Centralized widget keys for integration testing.
///
/// Usage in tests:
/// ```dart
/// find.byKey(TestKeys.continueWithEmailButton)
/// ```
///
/// Usage in widgets:
/// ```dart
/// NewspaperPrimaryButton(
///   key: TestKeys.continueWithEmailButton,
///   text: 'Continue with Email',
///   onPressed: _handleEmailSignIn,
/// ),
/// ```
class TestKeys {
  TestKeys._(); // Prevent instantiation

  // === Onboarding Screen ===
  static const continueWithEmailButton = Key('continueWithEmailButton');
  static const appleSignInButton = Key('appleSignInButton');
  static const signinHereLink = Key('signinHereLink');
  static const useEmailInsteadLink = Key('useEmailInsteadLink');

  // === Auth Screen (Email Entry) ===
  static const emailTextField = Key('emailTextField');
  static const sendVerificationButton = Key('sendVerificationButton');
  static const authErrorMessage = Key('authErrorMessage');

  // === OTP Verification Screen ===
  static const otpTextField = Key('otpTextField');
  static const verifyOtpButton = Key('verifyOtpButton');
  static const resendCodeButton = Key('resendCodeButton');

  // === Pairing Screen ===
  static const yourCodeDisplay = Key('yourCodeDisplay');
  static const partnerCodeTextField = Key('partnerCodeTextField');
  static const joinPartnerButton = Key('joinPartnerButton');
  static const copyCodeButton = Key('copyCodeButton');
  static const shareCodeButton = Key('shareCodeButton');
  static const pairingSuccessIndicator = Key('pairingSuccessIndicator');
  static const qrScannerButton = Key('qrScannerButton');

  // === Home Screen ===
  static const homeGreetingText = Key('homeGreetingText');
  static const dailyQuestsWidget = Key('dailyQuestsWidget');
  static const lovePointsCounter = Key('lovePointsCounter');

  // === Debug ===
  static const debugMenuTrigger = Key('debugMenuTrigger');
}
