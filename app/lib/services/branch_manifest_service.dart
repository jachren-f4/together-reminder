import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/branch_manifest.dart';
import '../models/branch_progression_state.dart';
import '../config/brand/brand_loader.dart';
import '../utils/logger.dart';

/// Service for loading and caching branch manifest files.
///
/// Manifests contain branch-specific metadata like video paths
/// and image paths that vary per content branch.
class BranchManifestService {
  static final BranchManifestService _instance =
      BranchManifestService._internal();
  factory BranchManifestService() => _instance;
  BranchManifestService._internal();

  // Cache: "{activityType}_{branch}" -> BranchManifest
  final Map<String, BranchManifest> _cache = {};

  /// Default fallback emojis per activity type
  static const Map<BranchableActivityType, String> _defaultEmojis = {
    BranchableActivityType.classicQuiz: '🧩',
    BranchableActivityType.affirmation: '❤️',
    BranchableActivityType.youOrMe: '🤝',
    BranchableActivityType.linked: '🔗',
    BranchableActivityType.wordSearch: '🔍',
  };

  /// Default video filenames per activity type
  static const Map<BranchableActivityType, String> _defaultVideos = {
    BranchableActivityType.classicQuiz: 'feel-good-foundations.mp4',
    BranchableActivityType.affirmation: 'affirmation.mp4',
    BranchableActivityType.youOrMe: 'getting-comfortable.mp4',
  };

  /// Get manifest for a branch, loading from JSON or returning fallback
  Future<BranchManifest> getManifest({
    required BranchableActivityType activityType,
    required String branch,
  }) async {
    final cacheKey = '${activityType.name}_$branch';

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Try to load from JSON
    try {
      final path = _getManifestPath(activityType, branch);
      final jsonString = await rootBundle.loadString(path);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final manifest = BranchManifest.fromJson(json);

      // Validate branch/activityType match
      if (manifest.branch != branch ||
          manifest.activityType != activityType.name) {
        Logger.warn(
          'Manifest mismatch: expected $branch/${activityType.name}, '
          'got ${manifest.branch}/${manifest.activityType}',
          service: 'manifest',
        );
      }

      _cache[cacheKey] = manifest;
      Logger.debug('Loaded manifest for $cacheKey', service: 'manifest');
      return manifest;
    } catch (e) {
      // Return fallback manifest
      Logger.debug('No manifest found for $cacheKey, using fallback',
          service: 'manifest');
      final fallback = BranchManifest.fallback(
        branch: branch,
        activityType: activityType.name,
        fallbackEmoji: _defaultEmojis[activityType],
      );
      _cache[cacheKey] = fallback;
      return fallback;
    }
  }

  /// Get video path with fallback logic
  ///
  /// Fallback chain:
  /// 1. manifest.videoPath (branch-specific)
  /// 2. Activity default video (e.g., feel-good-foundations.mp4)
  /// 3. null (caller should show fallback emoji)
  Future<String?> getVideoPath({
    required BranchableActivityType activityType,
    required String branch,
  }) async {
    final manifest =
        await getManifest(activityType: activityType, branch: branch);

    // Priority 1: Manifest videoPath
    if (manifest.videoPath != null && manifest.videoPath!.isNotEmpty) {
      return manifest.videoPath;
    }

    // Priority 2: Activity-level default video
    final defaultVideo = _defaultVideos[activityType];
    if (defaultVideo != null) {
      final brandId = BrandLoader().config.brandId;
      return 'assets/brands/$brandId/videos/$defaultVideo';
    }

    return null;
  }

  /// Get image path with fallback logic
  ///
  /// Fallback chain:
  /// 1. manifest.imagePath (branch-specific)
  /// 2. Activity default image
  /// 3. null (caller should use type-based fallback)
  Future<String?> getImagePath({
    required BranchableActivityType activityType,
    required String branch,
  }) async {
    final manifest =
        await getManifest(activityType: activityType, branch: branch);

    // Priority 1: Manifest imagePath
    if (manifest.imagePath != null && manifest.imagePath!.isNotEmpty) {
      return manifest.imagePath;
    }

    // Priority 2: Activity-level default image
    final brandId = BrandLoader().config.brandId;
    final activityFolder = _activityFolderName(activityType);
    final defaultPath =
        'assets/brands/$brandId/images/quests/$activityFolder-default.png';

    // Check if default exists (return null if not)
    try {
      await rootBundle.load(defaultPath);
      return defaultPath;
    } catch (_) {
      return null;
    }
  }

  /// Get fallback emoji for activity type
  String getFallbackEmoji(BranchableActivityType activityType) {
    return _defaultEmojis[activityType] ?? '💝';
  }

  /// Clear cache (for brand switching or testing)
  void clearCache() {
    _cache.clear();
    Logger.debug('Manifest cache cleared', service: 'manifest');
  }

  /// Preload all manifests for an activity type
  Future<void> preloadActivityManifests(
      BranchableActivityType activityType) async {
    final branches = branchFolderNames[activityType] ?? [];
    for (final branch in branches) {
      await getManifest(activityType: activityType, branch: branch);
    }
  }

  String _getManifestPath(BranchableActivityType activityType, String branch) {
    final brandId = BrandLoader().config.brandId;
    final activityFolder = _activityFolderName(activityType);
    return 'assets/brands/$brandId/data/$activityFolder/$branch/manifest.json';
  }

  String _activityFolderName(BranchableActivityType activityType) {
    switch (activityType) {
      case BranchableActivityType.classicQuiz:
        return 'classic-quiz';
      case BranchableActivityType.affirmation:
        return 'affirmation';
      case BranchableActivityType.youOrMe:
        return 'you-or-me';
      case BranchableActivityType.linked:
        return 'linked';
      case BranchableActivityType.wordSearch:
        return 'word-search';
    }
  }

  /// Convert activity type to branchable activity type
  static BranchableActivityType? fromQuestTypeAndFormat(
    String questType,
    String? formatType,
  ) {
    if (questType == 'quiz') {
      if (formatType == 'affirmation') {
        return BranchableActivityType.affirmation;
      }
      return BranchableActivityType.classicQuiz;
    } else if (questType == 'youOrMe') {
      return BranchableActivityType.youOrMe;
    } else if (questType == 'linked') {
      return BranchableActivityType.linked;
    } else if (questType == 'wordSearch') {
      return BranchableActivityType.wordSearch;
    }
    return null;
  }
}
