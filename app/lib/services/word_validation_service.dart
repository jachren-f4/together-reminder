import 'dart:convert';
import 'package:flutter/services.dart';

class WordValidationService {
  static WordValidationService? _instance;
  static WordValidationService get instance {
    _instance ??= WordValidationService._();
    return _instance!;
  }

  WordValidationService._();

  // In-memory word dictionaries for O(1) lookup
  final Map<String, Set<String>> _dictionaries = {
    'en': {},
    'fi': {},
  };

  bool _isInitialized = false;

  /// Initialize word dictionaries from JSON assets
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load English words
      final englishJson = await rootBundle.loadString('assets/words/english_words.json');
      final englishData = jsonDecode(englishJson) as Map<String, dynamic>;
      _loadWordsFromJson(englishData, 'en');

      // Load Finnish words
      final finnishJson = await rootBundle.loadString('assets/words/finnish_words.json');
      final finnishData = jsonDecode(finnishJson) as Map<String, dynamic>;
      _loadWordsFromJson(finnishData, 'fi');

      _isInitialized = true;
      print('✅ WordValidationService initialized: ${_dictionaries['en']!.length} English words, ${_dictionaries['fi']!.length} Finnish words');
    } catch (e) {
      print('❌ Error initializing WordValidationService: $e');
      rethrow;
    }
  }

  /// Load words from JSON data into dictionary
  void _loadWordsFromJson(Map<String, dynamic> data, String language) {
    final wordSet = _dictionaries[language]!;

    for (final entry in data.entries) {
      final wordList = entry.value as List<dynamic>;
      for (final word in wordList) {
        wordSet.add((word as String).toLowerCase());
      }
    }
  }

  /// Check if a word exists in the dictionary for the given language
  bool isValidWord(String word, String language) {
    if (!_isInitialized) {
      throw StateError('WordValidationService not initialized. Call initialize() first.');
    }

    final dictionary = _dictionaries[language];
    if (dictionary == null) {
      throw ArgumentError('Unsupported language: $language');
    }

    return dictionary.contains(word.toLowerCase());
  }

  /// Check if two words differ by exactly one letter (same length, same position)
  bool isOneLetterDifferent(String word1, String word2) {
    if (word1.length != word2.length) return false;

    int differenceCount = 0;
    for (int i = 0; i < word1.length; i++) {
      if (word1[i].toLowerCase() != word2[i].toLowerCase()) {
        differenceCount++;
        if (differenceCount > 1) return false;
      }
    }

    return differenceCount == 1;
  }

  /// Validate a move in the word ladder game
  /// Returns ValidationResult with success status and error message
  ValidationResult validateMove({
    required String currentWord,
    required String newWord,
    required String language,
    required List<String> wordChain,
  }) {
    // 1. Check if word is already used in this ladder
    if (wordChain.any((w) => w.toLowerCase() == newWord.toLowerCase())) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Word already used in this ladder',
      );
    }

    // 2. Check if exactly one letter is different
    if (!isOneLetterDifferent(currentWord, newWord)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Must change exactly one letter',
      );
    }

    // 3. Check if word exists in dictionary
    if (!isValidWord(newWord, language)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Not a valid word',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Get all words in the dictionary for a given language and length
  List<String> getWordsOfLength(String language, int length) {
    if (!_isInitialized) {
      throw StateError('WordValidationService not initialized. Call initialize() first.');
    }

    final dictionary = _dictionaries[language];
    if (dictionary == null) {
      throw ArgumentError('Unsupported language: $language');
    }

    return dictionary.where((word) => word.length == length).toList()..sort();
  }

  /// Check if dictionary is loaded
  bool get isInitialized => _isInitialized;
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}
