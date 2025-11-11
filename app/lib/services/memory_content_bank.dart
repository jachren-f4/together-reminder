/// Content bank for Memory Flip game
/// Contains emoji pairs and romantic/playful quotes for card reveals
class MemoryPair {
  final String emoji;
  final String quote;
  final String theme; // 'romantic', 'playful', 'nostalgic'

  const MemoryPair(this.emoji, this.quote, this.theme);
}

class MemoryContentBank {
  // Completion quotes shown when puzzle is fully solved
  static const List<String> completionQuotes = [
    'Together, we make the perfect match',
    'Every memory with you is a treasure',
    'You complete me in every way',
    'Our love story keeps getting better',
    'Two hearts, one beautiful journey',
    'Forever finding our way back to each other',
    'You are my favorite memory',
    'Building beautiful moments, one day at a time',
    'Together is our favorite place to be',
    'Love grows in the little moments we share',
  ];

  // Emoji pairs with romantic and playful quotes
  static const List<MemoryPair> pairs = [
    // Romantic pairs
    MemoryPair('🌸', 'Like flowers, our love blooms every season', 'romantic'),
    MemoryPair('💐', 'You bring color and beauty to my life', 'romantic'),
    MemoryPair('🌹', 'A rose by any other name would still remind me of you', 'romantic'),
    MemoryPair('❤️', 'My heart beats in rhythm with yours', 'romantic'),
    MemoryPair('💕', 'Two hearts dancing together forever', 'romantic'),
    MemoryPair('💖', 'You sparkle in my thoughts all day long', 'romantic'),
    MemoryPair('💍', 'Forever choosing you, every single day', 'romantic'),
    MemoryPair('💎', 'You are the most precious thing in my life', 'romantic'),
    MemoryPair('🌙', 'Under the same moon, always together', 'romantic'),
    MemoryPair('⭐', 'You light up my darkest nights', 'romantic'),
    MemoryPair('🌟', 'You make every ordinary moment shine', 'romantic'),
    MemoryPair('✨', 'Magic happens when we\'re together', 'romantic'),
    MemoryPair('🌈', 'You are my sunshine after every storm', 'romantic'),
    MemoryPair('☀️', 'Every day with you is brighter', 'romantic'),

    // Shared activities & playful pairs
    MemoryPair('☕', 'Every morning with you starts with warmth', 'playful'),
    MemoryPair('🍕', 'You\'re the perfect topping to my day', 'playful'),
    MemoryPair('🍝', 'Life with you is deliciously perfect', 'playful'),
    MemoryPair('🍷', 'Our love gets better with time', 'playful'),
    MemoryPair('🍰', 'Life is sweeter with you by my side', 'playful'),
    MemoryPair('🎵', 'Our song plays in my heart all day', 'nostalgic'),
    MemoryPair('🎶', 'You are the melody in my life', 'playful'),
    MemoryPair('🎬', 'Every moment with you is cinema-worthy', 'playful'),
    MemoryPair('📚', 'Every page of our story gets better', 'romantic'),
    MemoryPair('📖', 'Writing our love story one day at a time', 'romantic'),
    MemoryPair('🎨', 'You color my world in ways I never imagined', 'playful'),
    MemoryPair('🎭', 'With you, every day is an adventure', 'playful'),
    MemoryPair('🎮', 'Playing through life\'s levels together', 'playful'),
    MemoryPair('📷', 'Capturing beautiful moments with you', 'nostalgic'),

    // Travel & adventure pairs
    MemoryPair('🏖️', 'Sunshine feels brighter when we\'re together', 'nostalgic'),
    MemoryPair('🌴', 'Paradise is wherever you are', 'romantic'),
    MemoryPair('🏔️', 'Together we can climb any mountain', 'romantic'),
    MemoryPair('✈️', 'Every journey is better with you', 'playful'),
    MemoryPair('🎒', 'Life\'s greatest adventure is loving you', 'romantic'),
    MemoryPair('🗺️', 'You are my favorite destination', 'romantic'),
    MemoryPair('🚗', 'Road trips are better when you\'re riding shotgun', 'playful'),

    // Nature & animals
    MemoryPair('🐱', 'Purr-fect moments with you', 'playful'),
    MemoryPair('🐶', 'Loyal, loving, and always by your side', 'playful'),
    MemoryPair('🐻', 'You give the best bear hugs', 'playful'),
    MemoryPair('🦋', 'You give me butterflies every day', 'romantic'),
    MemoryPair('🐝', 'You are my honey, my sweetness', 'playful'),
    MemoryPair('🌻', 'You make my heart bloom', 'romantic'),

    // Cozy & home
    MemoryPair('🏡', 'Home is wherever you are', 'romantic'),
    MemoryPair('🛋️', 'Cozy moments with you are my favorite', 'nostalgic'),
    MemoryPair('🕯️', 'You light up my life', 'romantic'),
    MemoryPair('🔥', 'You keep the fire burning in my heart', 'romantic'),
    MemoryPair('🌧️', 'Rainy days are perfect with you', 'nostalgic'),

    // Fun & celebration
    MemoryPair('🎉', 'Every day with you is a celebration', 'playful'),
    MemoryPair('🎊', 'You make life confetti-level exciting', 'playful'),
    MemoryPair('🎈', 'You lift me up in every way', 'romantic'),
    MemoryPair('🎁', 'You are the greatest gift in my life', 'romantic'),
    MemoryPair('🍾', 'Celebrating our love every single day', 'playful'),
  ];

  /// Get a random selection of pairs for a puzzle
  /// Returns [count] unique pairs, ensuring variety
  static List<MemoryPair> getRandomPairs(int count) {
    if (count > pairs.length) {
      throw ArgumentError('Cannot get $count pairs, only ${pairs.length} available');
    }

    final shuffled = List<MemoryPair>.from(pairs)..shuffle();
    return shuffled.take(count).toList();
  }

  /// Get a random completion quote
  static String getRandomCompletionQuote() {
    final shuffled = List<String>.from(completionQuotes)..shuffle();
    return shuffled.first;
  }

  /// Get pairs by theme
  static List<MemoryPair> getPairsByTheme(String theme) {
    return pairs.where((pair) => pair.theme == theme).toList();
  }

  /// Get a balanced selection of pairs across all themes
  static List<MemoryPair> getBalancedPairs(int count) {
    if (count > pairs.length) {
      throw ArgumentError('Cannot get $count pairs, only ${pairs.length} available');
    }

    // Group pairs by theme
    final romantic = getPairsByTheme('romantic');
    final playful = getPairsByTheme('playful');
    final nostalgic = getPairsByTheme('nostalgic');

    // Calculate how many from each theme
    final romanticCount = (count * 0.5).round(); // 50% romantic
    final playfulCount = (count * 0.35).round();  // 35% playful
    final nostalgicCount = count - romanticCount - playfulCount; // Rest nostalgic

    // Shuffle each theme and take required amounts
    romantic.shuffle();
    playful.shuffle();
    nostalgic.shuffle();

    final result = <MemoryPair>[];
    result.addAll(romantic.take(romanticCount));
    result.addAll(playful.take(playfulCount));
    result.addAll(nostalgic.take(nostalgicCount));

    // Shuffle the final result to mix themes
    result.shuffle();
    return result;
  }
}
