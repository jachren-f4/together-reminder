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

  /// Check if Supabase is properly configured
  static bool get isConfigured {
    return url != 'https://your-project.supabase.co' &&
           anonKey != 'your-anon-key';
  }
}
