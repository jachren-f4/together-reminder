import 'dart:ui' as ui;
import 'api_client.dart';
import '../utils/logger.dart';

/// Country code to flag emoji mapping
const Map<String, String> countryFlags = {
  'US': '🇺🇸', 'GB': '🇬🇧', 'DE': '🇩🇪', 'FR': '🇫🇷', 'ES': '🇪🇸',
  'IT': '🇮🇹', 'CA': '🇨🇦', 'AU': '🇦🇺', 'NL': '🇳🇱', 'SE': '🇸🇪',
  'NO': '🇳🇴', 'DK': '🇩🇰', 'FI': '🇫🇮', 'PL': '🇵🇱', 'BR': '🇧🇷',
  'MX': '🇲🇽', 'JP': '🇯🇵', 'KR': '🇰🇷', 'IN': '🇮🇳', 'SG': '🇸🇬',
  'CH': '🇨🇭', 'AT': '🇦🇹', 'BE': '🇧🇪', 'PT': '🇵🇹', 'IE': '🇮🇪',
  'NZ': '🇳🇿', 'ZA': '🇿🇦', 'AR': '🇦🇷', 'CL': '🇨🇱', 'CO': '🇨🇴',
  'PH': '🇵🇭', 'TH': '🇹🇭', 'VN': '🇻🇳', 'MY': '🇲🇾', 'ID': '🇮🇩',
  'RU': '🇷🇺', 'UA': '🇺🇦', 'TR': '🇹🇷', 'EG': '🇪🇬', 'IL': '🇮🇱',
  'AE': '🇦🇪', 'SA': '🇸🇦', 'GR': '🇬🇷', 'CZ': '🇨🇿', 'RO': '🇷🇴',
  'HU': '🇭🇺', 'HR': '🇭🇷', 'BG': '🇧🇬', 'SK': '🇸🇰', 'SI': '🇸🇮',
};

/// Country code to name mapping
const Map<String, String> countryNames = {
  'US': 'United States', 'GB': 'United Kingdom', 'DE': 'Germany',
  'FR': 'France', 'ES': 'Spain', 'IT': 'Italy', 'CA': 'Canada',
  'AU': 'Australia', 'NL': 'Netherlands', 'SE': 'Sweden',
  'NO': 'Norway', 'DK': 'Denmark', 'FI': 'Finland', 'PL': 'Poland',
  'BR': 'Brazil', 'MX': 'Mexico', 'JP': 'Japan', 'KR': 'South Korea',
  'IN': 'India', 'SG': 'Singapore', 'CH': 'Switzerland', 'AT': 'Austria',
  'BE': 'Belgium', 'PT': 'Portugal', 'IE': 'Ireland', 'NZ': 'New Zealand',
  'ZA': 'South Africa', 'AR': 'Argentina', 'CL': 'Chile', 'CO': 'Colombia',
  'PH': 'Philippines', 'TH': 'Thailand', 'VN': 'Vietnam', 'MY': 'Malaysia',
  'ID': 'Indonesia', 'RU': 'Russia', 'UA': 'Ukraine', 'TR': 'Turkey',
  'EG': 'Egypt', 'IL': 'Israel', 'AE': 'UAE', 'SA': 'Saudi Arabia',
  'GR': 'Greece', 'CZ': 'Czech Republic', 'RO': 'Romania', 'HU': 'Hungary',
  'HR': 'Croatia', 'BG': 'Bulgaria', 'SK': 'Slovakia', 'SI': 'Slovenia',
};

/// Service for managing user's country code
class CountryService {
  static final CountryService _instance = CountryService._internal();
  factory CountryService() => _instance;
  CountryService._internal();

  final ApiClient _apiClient = ApiClient();

  // Cached country code
  String? _cachedCountryCode;

  /// Get current user's country code from device locale
  String? getDeviceCountryCode() {
    try {
      // Get device locale
      final locale = ui.PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode;

      if (countryCode != null && countryCode.length == 2) {
        Logger.debug('Device country code: $countryCode', service: 'country');
        return countryCode.toUpperCase();
      }

      return null;
    } catch (e) {
      Logger.error('Error getting device country code', error: e, service: 'country');
      return null;
    }
  }

  /// Get country flag emoji for a country code
  String getFlagEmoji(String countryCode) {
    final code = countryCode.toUpperCase();

    // Use mapping if available
    if (countryFlags.containsKey(code)) {
      return countryFlags[code]!;
    }

    // Generate from regional indicator symbols
    // Each letter A-Z has a regional indicator symbol from 0x1F1E6 to 0x1F1FF
    final firstLetter = code.codeUnitAt(0) - 'A'.codeUnitAt(0) + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 'A'.codeUnitAt(0) + 0x1F1E6;

    return String.fromCharCodes([firstLetter, secondLetter]);
  }

  /// Get country name from code
  String getCountryName(String countryCode) {
    return countryNames[countryCode.toUpperCase()] ?? countryCode;
  }

  /// Get user's saved country code from server
  Future<String?> getUserCountry() async {
    // Return cached if available
    if (_cachedCountryCode != null) {
      return _cachedCountryCode;
    }

    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/api/user/country');

      if (response.success && response.data != null) {
        final countryCode = response.data!['country_code'] as String?;
        _cachedCountryCode = countryCode;
        Logger.debug('User country from server: $countryCode', service: 'country');
        return countryCode;
      }
    } catch (e) {
      Logger.error('Error fetching user country', error: e, service: 'country');
    }

    return null;
  }

  /// Update user's country code on server
  Future<bool> updateUserCountry(String countryCode) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/user/country',
        body: {'country_code': countryCode.toUpperCase()},
      );

      if (response.success) {
        _cachedCountryCode = countryCode.toUpperCase();
        Logger.info('Updated user country to: $countryCode', service: 'country');
        return true;
      } else {
        Logger.error('Failed to update country: ${response.error}', service: 'country');
        return false;
      }
    } catch (e) {
      Logger.error('Error updating user country', error: e, service: 'country');
      return false;
    }
  }

  /// Initialize user's country from device locale if not set
  /// Call this on app startup
  Future<void> initializeCountryIfNeeded() async {
    try {
      // Check if user has a country set
      final currentCountry = await getUserCountry();

      if (currentCountry == null) {
        // Get from device locale
        final deviceCountry = getDeviceCountryCode();

        if (deviceCountry != null) {
          Logger.info('Initializing user country from device: $deviceCountry', service: 'country');
          await updateUserCountry(deviceCountry);
        }
      }
    } catch (e) {
      Logger.error('Error initializing country', error: e, service: 'country');
    }
  }

  /// Clear cached country (call on logout)
  void clearCache() {
    _cachedCountryCode = null;
  }
}
