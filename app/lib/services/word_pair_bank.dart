import '../models/word_pair.dart';
import 'package:uuid/uuid.dart';

class WordPairBank {
  static const _uuid = Uuid();

  /// Get all curated word pairs
  static List<WordPair> getAllPairs() {
    return [
      ...getEnglishPairs(),
      ...getFinnishPairs(),
    ];
  }

  /// Get English word pairs only
  static List<WordPair> getEnglishPairs() {
    return [
      // ===== EASY (4 letters) =====
      WordPair(
        id: _uuid.v4(),
        startWord: 'LOVE',
        endWord: 'HATE',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 3, // LOVE → LONE → LANE → HATE (or similar)
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'WARM',
        endWord: 'COLD',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 4,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'LIFE',
        endWord: 'HOPE',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 3,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'CARE',
        endWord: 'CURE',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 2, // CARE → CORE → CURE
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'FEAR',
        endWord: 'HEAR',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 1,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'LOST',
        endWord: 'LAST',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 1,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'WORK',
        endWord: 'WORD',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 1,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'DARK',
        endWord: 'DAWN',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 2,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'HOME',
        endWord: 'COME',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 2, // HOME → HOVE → COVE → COME
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'FINE',
        endWord: 'WINE',
        language: 'en',
        difficulty: 'easy',
        optimalSteps: 1,
      ),

      // ===== MEDIUM (5 letters) =====
      WordPair(
        id: _uuid.v4(),
        startWord: 'TRUST',
        endWord: 'LIGHT',
        language: 'en',
        difficulty: 'medium',
        optimalSteps: 5,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'HEART',
        endWord: 'PEACE',
        language: 'en',
        difficulty: 'medium',
        optimalSteps: 5,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'SMILE',
        endWord: 'WORLD',
        language: 'en',
        difficulty: 'medium',
        optimalSteps: 6,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'DREAM',
        endWord: 'SHARE',
        language: 'en',
        difficulty: 'medium',
        optimalSteps: 4,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'QUICK',
        endWord: 'STICK',
        language: 'en',
        difficulty: 'medium',
        optimalSteps: 2, // QUICK → SLICK → STICK (or similar)
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'THINK',
        endWord: 'THING',
        language: 'en',
        difficulty: 'medium',
        optimalSteps: 1,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'STAND',
        endWord: 'GRAND',
        language: 'en',
        difficulty: 'medium',
        optimalSteps: 1,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'BRAND',
        endWord: 'BREAD',
        language: 'en',
        difficulty: 'medium',
        optimalSteps: 1,
      ),

      // ===== HARD (6 letters) =====
      WordPair(
        id: _uuid.v4(),
        startWord: 'FUTURE',
        endWord: 'HONEST',
        language: 'en',
        difficulty: 'hard',
        optimalSteps: 8,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'CARING',
        endWord: 'LOVING',
        language: 'en',
        difficulty: 'hard',
        optimalSteps: 3,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'WARMTH',
        endWord: 'BRIGHT',
        language: 'en',
        difficulty: 'hard',
        optimalSteps: 6,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'GENTLE',
        endWord: 'CHANGE',
        language: 'en',
        difficulty: 'hard',
        optimalSteps: 5,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'BROKEN',
        endWord: 'FROZEN',
        language: 'en',
        difficulty: 'hard',
        optimalSteps: 1,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'GOLDEN',
        endWord: 'GARDEN',
        language: 'en',
        difficulty: 'hard',
        optimalSteps: 2,
      ),
    ];
  }

  /// Get Finnish word pairs only
  static List<WordPair> getFinnishPairs() {
    return [
      // ===== EASY (4 letters) - minimum 2 steps =====
      WordPair(
        id: _uuid.v4(),
        startWord: 'RATA',
        endWord: 'SANA',
        language: 'fi',
        difficulty: 'easy',
        optimalSteps: 2, // RATA → SATA → SANA
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'KALA',
        endWord: 'LOMA',
        language: 'fi',
        difficulty: 'easy',
        optimalSteps: 3,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'TALO',
        endWord: 'PORA',
        language: 'fi',
        difficulty: 'easy',
        optimalSteps: 3,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'VALO',
        endWord: 'SATO',
        language: 'fi',
        difficulty: 'easy',
        optimalSteps: 2, // VALO → PALO → SATO (or similar)
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'KONE',
        endWord: 'SORI',
        language: 'fi',
        difficulty: 'easy',
        optimalSteps: 2, // KONE → KORI → SORI
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'MATO',
        endWord: 'VETO',
        language: 'fi',
        difficulty: 'easy',
        optimalSteps: 2, // MATO → KATO → KETO → VETO (could be 3)
      ),

      // ===== MEDIUM (5 letters) =====
      WordPair(
        id: _uuid.v4(),
        startWord: 'RAUTA',
        endWord: 'KUKKA',
        language: 'fi',
        difficulty: 'medium',
        optimalSteps: 4,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'TAIKA',
        endWord: 'RANTA',
        language: 'fi',
        difficulty: 'medium',
        optimalSteps: 3,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'KAULA',
        endWord: 'SAUNA',
        language: 'fi',
        difficulty: 'medium',
        optimalSteps: 2,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'MATTO',
        endWord: 'LATTE',
        language: 'fi',
        difficulty: 'medium',
        optimalSteps: 2,
      ),

      // ===== HARD (6 letters) =====
      WordPair(
        id: _uuid.v4(),
        startWord: 'TAIVAS',
        endWord: 'TAISTO',
        language: 'fi',
        difficulty: 'hard',
        optimalSteps: 3,
      ),
      WordPair(
        id: _uuid.v4(),
        startWord: 'RAKAUS',
        endWord: 'KUKKIA',
        language: 'fi',
        difficulty: 'hard',
        optimalSteps: 5,
      ),
    ];
  }

  /// Get random pairs for initial ladder generation (alternating difficulty)
  /// Returns 3 pairs: [easy, medium, easy] for good variety - FINNISH ONLY
  static List<WordPair> getInitialPairs() {
    final finnishPairs = getFinnishPairs();
    final easy = finnishPairs.where((p) => p.difficulty == 'easy').toList()..shuffle();
    final medium = finnishPairs.where((p) => p.difficulty == 'medium').toList()..shuffle();

    return [
      easy.first, // Easy
      medium.first, // Medium
      easy.length > 1 ? easy[1] : easy.first, // Easy
    ];
  }

  /// Get a random word pair of specified difficulty - FINNISH ONLY
  static WordPair? getRandomPair({String? difficulty, String? language}) {
    // Force Finnish only
    final finnishPairs = getFinnishPairs();
    var filtered = finnishPairs;

    if (difficulty != null) {
      filtered = filtered.where((p) => p.difficulty == difficulty).toList();
    }

    if (filtered.isEmpty) return null;

    filtered.shuffle();
    return filtered.first;
  }
}
