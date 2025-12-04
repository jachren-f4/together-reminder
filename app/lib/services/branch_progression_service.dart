import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/branch_progression_state.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/couple_pairing_service.dart';
import '../utils/logger.dart';

/// Service for managing branching content progression.
///
/// Each activity type (classicQuiz, affirmation, youOrMe, linked, wordSearch)
/// has independent branch progression that cycles through branches based on
/// completion count: currentBranch = totalCompletions % maxBranches
///
/// Storage: Hive (local cache) + Supabase via API (authoritative)
///
/// NOTE: This service uses TWO different coupleId formats:
/// - Hive storage: composite key "{userId1}_{userId2}" (from QuestUtilities)
/// - Supabase API: UUID from couples table (from CouplePairingService)
class BranchProgressionService {
  final StorageService _storage;
  final AuthService _authService = AuthService();
  final CouplePairingService _couplePairingService = CouplePairingService();

  BranchProgressionService({StorageService? storage})
      : _storage = storage ?? StorageService();

  /// Get the Supabase couple UUID (different from composite coupleId used in Hive)
  Future<String?> _getSupabaseCoupleId() async {
    return _couplePairingService.getCoupleId();
  }

  /// Get API base URL - uses centralized config
  String get _apiBaseUrl => SupabaseConfig.apiUrl;

  /// Get or create branch progression state for an activity type.
  ///
  /// First checks Hive cache, then falls back to API if not found.
  /// Creates initial state (Branch A) if no state exists anywhere.
  Future<BranchProgressionState> getOrCreateState({
    required String coupleId,
    required BranchableActivityType activityType,
  }) async {
    // 1. Check local Hive cache
    var state = _storage.getBranchProgressionState(coupleId, activityType);
    if (state != null) {
      Logger.debug(
        'Branch state from cache: ${activityType.name} -> ${state.currentBranchFolder}',
        service: 'branch',
      );
      return state;
    }

    // 2. Try to load from API
    state = await _loadFromApi(coupleId, activityType);
    if (state != null) {
      await _storage.saveBranchProgressionState(state);
      Logger.debug(
        'Branch state from API: ${activityType.name} -> ${state.currentBranchFolder}',
        service: 'branch',
      );
      return state;
    }

    // 3. Create initial state (Branch A)
    state = BranchProgressionState.initial(coupleId, activityType);
    await _storage.saveBranchProgressionState(state);
    // Don't sync to API until first completion (avoid creating empty records)
    Logger.info(
      'Created initial branch state: ${activityType.name} -> ${state.currentBranchFolder}',
      service: 'branch',
    );
    return state;
  }

  /// Get the current branch folder name for an activity type.
  ///
  /// Returns folder name like 'lighthearted', 'meaningful', 'emotional', etc.
  Future<String> getCurrentBranch({
    required String coupleId,
    required BranchableActivityType activityType,
  }) async {
    final state = await getOrCreateState(
      coupleId: coupleId,
      activityType: activityType,
    );
    return state.currentBranchFolder;
  }

  /// Mark activity as completed and advance to next branch.
  ///
  /// Updates local Hive state immediately, then syncs to API.
  Future<void> completeActivity({
    required String coupleId,
    required BranchableActivityType activityType,
  }) async {
    final state = await getOrCreateState(
      coupleId: coupleId,
      activityType: activityType,
    );

    final previousBranch = state.currentBranchFolder;
    state.completeActivity();
    final newBranch = state.currentBranchFolder;

    // Save to Hive immediately
    await _storage.updateBranchProgressionState(state);

    Logger.info(
      'Branch progression: ${activityType.name} $previousBranch -> $newBranch '
      '(completion #${state.totalCompletions})',
      service: 'branch',
    );

    // Sync to API (fire and forget, don't block on failure)
    _saveToApi(state).catchError((e) {
      Logger.warn(
        'Failed to sync branch state to API: $e',
        service: 'branch',
      );
    });
  }

  /// Sync all branch states from API (call on app open).
  ///
  /// This ensures partner devices stay in sync by loading
  /// the authoritative state from Supabase.
  Future<void> syncFromApi(String coupleId) async {
    try {
      final states = await _loadAllFromApi(coupleId);
      for (final state in states) {
        final localState = _storage.getBranchProgressionState(
          coupleId,
          state.activityType,
        );

        // Only update if API has newer data (more completions)
        if (localState == null ||
            state.totalCompletions > localState.totalCompletions) {
          await _storage.saveBranchProgressionState(state);
          Logger.debug(
            'Synced branch state: ${state.activityType.name} -> ${state.currentBranchFolder}',
            service: 'branch',
          );
        }
      }
      Logger.info(
        'Branch sync complete: ${states.length} states from API',
        service: 'branch',
      );
    } catch (e) {
      Logger.warn('Failed to sync branch states from API: $e', service: 'branch');
      // Don't rethrow - local state is still valid
    }
  }

  /// Load single branch state from API.
  /// Note: Uses Supabase couple UUID for API, but returns state with composite coupleId for Hive storage
  Future<BranchProgressionState?> _loadFromApi(
    String hiveCoupleId,
    BranchableActivityType activityType,
  ) async {
    try {
      // Get Supabase UUID for API call
      final supabaseCoupleId = await _getSupabaseCoupleId();
      if (supabaseCoupleId == null) {
        Logger.debug('No Supabase couple ID found, skipping API call', service: 'branch');
        return null;
      }

      final uri = Uri.parse(
        '$_apiBaseUrl/api/sync/branch-progression?couple_id=$supabaseCoupleId&activity_type=${activityType.name}',
      );

      final response = await http.get(
        uri,
        headers: await _authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['state'] != null) {
          final state = BranchProgressionState.fromJson(
            Map<String, dynamic>.from(data['state']),
          );
          // Override coupleId with Hive composite key for local storage
          state.coupleId = hiveCoupleId;
          return state;
        }
      } else if (response.statusCode == 404) {
        // No state exists yet - that's fine
        return null;
      }

      Logger.debug(
        'API response ${response.statusCode}: ${response.body}',
        service: 'branch',
      );
      return null;
    } catch (e) {
      Logger.debug('Error loading branch state from API: $e', service: 'branch');
      return null;
    }
  }

  /// Load all branch states for a couple from API.
  /// Note: Uses Supabase couple UUID for API, but returns states with composite coupleId for Hive storage
  Future<List<BranchProgressionState>> _loadAllFromApi(String hiveCoupleId) async {
    try {
      // Get Supabase UUID for API call
      final supabaseCoupleId = await _getSupabaseCoupleId();
      if (supabaseCoupleId == null) {
        Logger.debug('No Supabase couple ID found, skipping API call', service: 'branch');
        return [];
      }

      final uri = Uri.parse(
        '$_apiBaseUrl/api/sync/branch-progression?couple_id=$supabaseCoupleId',
      );

      final response = await http.get(
        uri,
        headers: await _authService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> statesJson = data['states'] ?? [];
        return statesJson.map((s) {
          final state = BranchProgressionState.fromJson(
            Map<String, dynamic>.from(s),
          );
          // Override coupleId with Hive composite key for local storage
          state.coupleId = hiveCoupleId;
          return state;
        }).toList();
      }

      return [];
    } catch (e) {
      Logger.debug('Error loading branch states from API: $e', service: 'branch');
      return [];
    }
  }

  /// Save branch state to API.
  /// Note: Uses Supabase couple UUID for API, not the Hive composite key
  Future<void> _saveToApi(BranchProgressionState state) async {
    try {
      // Get Supabase UUID for API call
      final supabaseCoupleId = await _getSupabaseCoupleId();
      if (supabaseCoupleId == null) {
        Logger.debug('No Supabase couple ID found, skipping API save', service: 'branch');
        return;
      }

      final uri = Uri.parse('$_apiBaseUrl/api/sync/branch-progression');

      // Create JSON with Supabase UUID instead of Hive composite key
      final jsonBody = state.toJson();
      jsonBody['couple_id'] = supabaseCoupleId;

      final authHeaders = await _authService.getAuthHeaders();
      final response = await http.post(
        uri,
        headers: {
          ...authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(jsonBody),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('API error: ${response.statusCode} ${response.body}');
      }

      Logger.debug(
        'Saved branch state to API: ${state.activityType.name}',
        service: 'branch',
      );
    } catch (e) {
      Logger.warn('Failed to save branch state to API: $e', service: 'branch');
      rethrow;
    }
  }

  /// Get all local branch states (for debugging).
  List<BranchProgressionState> getAllLocalStates(String coupleId) {
    return _storage.getAllBranchProgressionStates(coupleId);
  }

  /// Clear all local branch states (for testing/reset).
  Future<void> clearAllLocalStates() async {
    await _storage.clearAllBranchProgressionStates();
    Logger.info('Cleared all local branch states', service: 'branch');
  }
}
