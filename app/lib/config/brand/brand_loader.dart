import 'package:togetherremind/utils/logger.dart';
import 'brand_config.dart';
import 'brand_colors.dart';
import 'brand_assets.dart';
import 'content_paths.dart';
import 'firebase_config.dart';
import 'brand_registry.dart';

/// Singleton that loads and provides the current brand configuration
///
/// The brand is selected at compile time via `--dart-define=BRAND=brandName`.
/// This loader should be initialized FIRST in main.dart, before any other
/// initialization that depends on brand configuration.
///
/// Usage:
/// ```dart
/// // In main.dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   BrandLoader().initialize();  // FIRST
///   // ... rest of initialization
/// }
///
/// // Anywhere in the app
/// final colors = BrandLoader().colors;
/// final appName = BrandLoader().config.appName;
/// ```
class BrandLoader {
  static final BrandLoader _instance = BrandLoader._internal();
  factory BrandLoader() => _instance;
  BrandLoader._internal();

  late final BrandConfig _config;
  bool _isInitialized = false;

  /// Current brand configuration
  ///
  /// Throws StateError if accessed before initialize() is called.
  BrandConfig get config {
    if (!_isInitialized) {
      throw StateError(
        'BrandLoader not initialized. Call BrandLoader().initialize() in main() before any other initialization.',
      );
    }
    return _config;
  }

  /// Whether the loader has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize brand configuration from compile-time define
  ///
  /// Reads the BRAND environment variable set via `--dart-define=BRAND=brandName`.
  /// Defaults to 'togetherRemind' if not specified.
  void initialize() {
    if (_isInitialized) {
      Logger.debug('BrandLoader already initialized, skipping', service: 'brand');
      return;
    }

    // Read brand from compile-time define
    const brandName = String.fromEnvironment('BRAND', defaultValue: 'togetherRemind');

    // Parse brand enum
    final brand = Brand.values.firstWhere(
      (b) => b.name == brandName,
      orElse: () {
        Logger.warn(
          'Unknown brand "$brandName", defaulting to togetherRemind',
          service: 'brand',
        );
        return Brand.togetherRemind;
      },
    );

    // Load configuration from registry
    _config = BrandRegistry.get(brand);
    _isInitialized = true;

    Logger.info(
      'Brand loaded: ${_config.appName} (${_config.brand.name})',
      service: 'brand',
    );
  }

  // ============================================
  // Convenience accessors
  // ============================================

  /// Current brand's color palette
  BrandColors get colors => config.colors;

  /// Current brand's asset paths
  BrandAssets get assets => config.assets;

  /// Current brand's content paths
  ContentPaths get content => config.content;

  /// Current brand's Firebase configuration
  BrandFirebaseConfig get firebase => config.firebase;
}

/// Global shorthand for accessing brand configuration
///
/// Usage:
/// ```dart
/// final appName = brand.appName;
/// final primaryColor = brand.colors.primary;
/// ```
BrandConfig get brand => BrandLoader().config;
