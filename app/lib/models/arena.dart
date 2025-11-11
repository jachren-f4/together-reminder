import 'package:flutter/material.dart';

/// Represents a vacation arena tier in the TogetherRemind progression system.
/// Users unlock new arenas as they earn Love Points together.
enum ArenaType {
  cozyCabin,
  beachVilla,
  yachtGetaway,
  mountainPenthouse,
  castleRetreat,
}

class Arena {
  final ArenaType type;
  final String name;
  final String emoji;
  final int minLP;
  final int maxLP;
  final LinearGradient gradient;

  const Arena({
    required this.type,
    required this.name,
    required this.emoji,
    required this.minLP,
    required this.maxLP,
    required this.gradient,
  });

  /// All available arenas, ordered by Love Points requirement
  static const List<Arena> arenas = [
    Arena(
      type: ArenaType.cozyCabin,
      name: 'Cozy Cabin',
      emoji: '🏕️',
      minLP: 0,
      maxLP: 1000,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE67E22), Color(0xFFF39C12)],
      ),
    ),
    Arena(
      type: ArenaType.beachVilla,
      name: 'Beach Villa',
      emoji: '🏖️',
      minLP: 1000,
      maxLP: 2500,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF87CEEB), Color(0xFFFFD700)],
      ),
    ),
    Arena(
      type: ArenaType.yachtGetaway,
      name: 'Yacht Getaway',
      emoji: '⛵',
      minLP: 2500,
      maxLP: 5000,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E3A8A), Color(0xFF60A5FA)],
      ),
    ),
    Arena(
      type: ArenaType.mountainPenthouse,
      name: 'Mountain Penthouse',
      emoji: '🏔️',
      minLP: 5000,
      maxLP: 10000,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6B7280), Color(0xFFE5E7EB)],
      ),
    ),
    Arena(
      type: ArenaType.castleRetreat,
      name: 'Castle Retreat',
      emoji: '🏰',
      minLP: 10000,
      maxLP: 999999,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7C3AED), Color(0xFFC084FC)],
      ),
    ),
  ];

  /// Get the current arena based on Love Points
  static Arena getCurrentArena(int lovePoints) {
    return arenas.lastWhere(
      (arena) => lovePoints >= arena.minLP,
      orElse: () => arenas.first,
    );
  }

  /// Get the next arena to unlock, or null if at max tier
  static Arena? getNextArena(int lovePoints) {
    final currentIndex = arenas.indexWhere(
      (arena) => lovePoints >= arena.minLP && lovePoints < arena.maxLP,
    );
    if (currentIndex == -1 || currentIndex == arenas.length - 1) {
      return null; // Already at max tier
    }
    return arenas[currentIndex + 1];
  }

  /// Calculate progress percentage within this arena (0.0 to 1.0)
  double getProgress(int lovePoints) {
    if (lovePoints < minLP) return 0.0;
    if (lovePoints >= maxLP) return 1.0;
    return (lovePoints - minLP) / (maxLP - minLP);
  }

  /// Get formatted progress string (e.g., "1,280 / 2,500 LP")
  String getProgressString(int lovePoints) {
    return '${_formatNumber(lovePoints)} / ${_formatNumber(maxLP)} LP';
  }

  /// Format number with commas (e.g., 1280 -> "1,280")
  static String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
