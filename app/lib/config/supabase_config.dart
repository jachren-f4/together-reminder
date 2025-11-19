import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Supabase configuration
///
/// These values should be set from your Supabase project settings.
/// In production, consider using environment variables via --dart-define.
class SupabaseConfig {
  // Supabase project URL
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jcibbrasffhwvjfojviv.supabase.co',
  );

  // Supabase anon key
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjaWJicmFzZmZod3ZqZm9qdml2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1NTQ0NDgsImV4cCI6MjA3OTEzMDQ0OH0.BtA7y2jTTf3T5VUMMCIJhowiyR7A3Wk38mM_8WEAGPw',
  );

  // API base URL for the Next.js backend
  // Android emulator uses 10.0.2.2 to reach host's localhost
  // Web/iOS simulator can use localhost directly
  static String get apiUrl {
    // Check for environment override first
    const envUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (envUrl.isNotEmpty) return envUrl;

    // Use platform-specific localhost
    if (kIsWeb) {
      return 'http://localhost:4000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:4000'; // Android emulator special IP for host
    } else {
      return 'http://localhost:4000'; // iOS simulator
    }
  }

  /// Check if Supabase is properly configured
  static bool get isConfigured {
    return url != 'https://your-project.supabase.co' &&
           anonKey != 'your-anon-key';
  }
}
