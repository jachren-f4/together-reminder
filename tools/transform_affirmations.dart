/// Transforms affirmations.json from simplified format to QuizQuestion format
///
/// Usage: dart run tools/transform_affirmations.dart

import 'dart:convert';
import 'dart:io';

void main() async {
  print('🔄 Transforming affirmations.json to QuizQuestion format...\n');

  // Read input file
  final inputFile = File('data/affirmations.json');
  if (!inputFile.existsSync()) {
    print('❌ Error: data/affirmations.json not found');
    exit(1);
  }

  final inputJson = jsonDecode(await inputFile.readAsString());
  final quizzes = inputJson['quizzes'] as List;

  // Transform each quiz
  final transformedQuizzes = <Map<String, dynamic>>[];

  for (var quiz in quizzes) {
    final transformed = transformQuiz(quiz as Map<String, dynamic>);
    transformedQuizzes.add(transformed);

    print('✅ Transformed: ${transformed['name']}');
    print('   ID: ${transformed['id']}');
    print('   Category: ${transformed['category']}');
    print('   Questions: ${transformed['questions'].length}');
    print('');
  }

  // Write output file
  final outputFile = File('data/affirmations_transformed.json');
  final output = {
    'quizzes': transformedQuizzes,
  };

  await outputFile.writeAsString(
    JsonEncoder.withIndent('  ').convert(output)
  );

  print('✨ Success! Written to: data/affirmations_transformed.json');
  print('📊 Total quizzes transformed: ${transformedQuizzes.length}');
}

Map<String, dynamic> transformQuiz(Map<String, dynamic> quiz) {
  final name = quiz['name'] as String;
  final difficultyStage = quiz['difficulty_stage'] as int;
  final tags = List<String>.from(quiz['tags'] as List);
  final items = List<String>.from(quiz['items'] as List);

  return {
    'id': _generateId(name),
    'name': name,
    'category': _inferCategory(tags),
    'difficulty': difficultyStage,
    'formatType': 'affirmation',
    'questions': items.map((item) => {
      'question': item,
      'questionType': 'scale',
      'options': [],
      'correctAnswer': null,
    }).toList(),
  };
}

String _generateId(String name) {
  // Convert "Gentle Beginnings" -> "gentle_beginnings"
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
}

String _inferCategory(List<String> tags) {
  // Map common tags to categories
  // Categories: trust, communication, conflict, emotional_support

  if (tags.any((t) => ['trust', 'early-connection', 'beginner'].contains(t))) {
    return 'trust';
  }

  if (tags.any((t) => ['communication', 'conversation'].contains(t))) {
    return 'communication';
  }

  if (tags.any((t) => ['conflict', 'disagreement', 'challenge'].contains(t))) {
    return 'conflict';
  }

  if (tags.any((t) => ['emotional', 'support', 'warmth', 'positivity'].contains(t))) {
    return 'emotional_support';
  }

  // Default to trust for light/playful early-stage quizzes
  return 'trust';
}
