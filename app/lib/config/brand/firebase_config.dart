import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Brand-specific Firebase configuration
///
/// Each brand requires its own Firebase project for proper isolation
/// of analytics, FCM tokens, and database access.
class BrandFirebaseConfig {
  final String projectId;
  final String storageBucket;
  final String databaseURL;
  final String messagingSenderId;

  // Platform-specific credentials
  final String androidApiKey;
  final String androidAppId;

  final String iosApiKey;
  final String iosAppId;
  final String? iosBundleId;

  final String webApiKey;
  final String webAppId;
  final String? webAuthDomain;

  const BrandFirebaseConfig({
    required this.projectId,
    required this.storageBucket,
    required this.databaseURL,
    required this.messagingSenderId,
    required this.androidApiKey,
    required this.androidAppId,
    required this.iosApiKey,
    required this.iosAppId,
    this.iosBundleId,
    required this.webApiKey,
    required this.webAppId,
    this.webAuthDomain,
  });

  /// Convert to FirebaseOptions for the current platform
  FirebaseOptions toFirebaseOptions() {
    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: webApiKey,
        appId: webAppId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: webAuthDomain,
        databaseURL: databaseURL,
        storageBucket: storageBucket,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: androidApiKey,
          appId: androidAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
          databaseURL: databaseURL,
        );
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: iosApiKey,
          appId: iosAppId,
          messagingSenderId: messagingSenderId,
          projectId: projectId,
          storageBucket: storageBucket,
          databaseURL: databaseURL,
          iosBundleId: iosBundleId,
        );
      default:
        throw UnsupportedError(
          'BrandFirebaseConfig is not supported for this platform.',
        );
    }
  }
}
