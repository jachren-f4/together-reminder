import 'package:hive/hive.dart';

part 'word_pair.g.dart';

@HiveType(typeId: 8) // Badge is 6, LadderSession is 7 (wrong), so using 8
class WordPair extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String startWord;

  @HiveField(2)
  late String endWord;

  @HiveField(3)
  late String language; // 'en' | 'fi'

  @HiveField(4, defaultValue: 'easy')
  late String difficulty; // 'easy' | 'medium' | 'hard'

  @HiveField(5)
  int? optimalSteps; // Target number of steps for bonus

  WordPair({
    required this.id,
    required this.startWord,
    required this.endWord,
    required this.language,
    this.difficulty = 'easy',
    this.optimalSteps,
  });
}
