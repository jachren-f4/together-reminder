/**
 * Migration Script: Convert Flutter Assets to Server JSON Files
 *
 * This script reads quiz content from Flutter assets and generates
 * pre-packaged quiz sets for the server-centric architecture.
 *
 * Run with: node scripts/migrate_quiz_content.js
 */

const fs = require('fs');
const path = require('path');

// Paths
const FLUTTER_ASSETS_PATH = path.join(__dirname, '../../app/assets/brands/togetherremind/data');
const OUTPUT_PATH = path.join(__dirname, '../data/puzzles');

// Configuration
const CLASSIC_QUESTIONS_PER_QUIZ = 5;
const AFFIRMATION_QUESTIONS_PER_QUIZ = 5;
const YOUORME_QUESTIONS_PER_QUIZ = 10;

// Branch mappings
const CLASSIC_BRANCHES = {
  lighthearted: ['favorites', 'preferences', 'would_you_rather'],
  deep: ['memories', 'future'],
  spicy: ['daily_habits']
};

const AFFIRMATION_BRANCH_MAPPING = {
  practical: ['gentle_beginnings', 'getting_comfortable'],
  emotional: ['warm_vibes', 'simple_joys'],
  spiritual: ['playful_moments', 'feelgood_foundations']
};

const YOUORME_BRANCH_MAPPING = {
  playful: ['personality', 'comparative'],
  reflective: ['scenarios'],
  intimate: ['actions']
};

// Helper to ensure directory exists
function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

// Helper to shuffle array (deterministic seed for reproducibility)
function shuffle(array) {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// Generate Classic Quizzes
function generateClassicQuizzes() {
  console.log('\n📝 Generating Classic Quizzes...');

  const rawData = fs.readFileSync(
    path.join(FLUTTER_ASSETS_PATH, 'quiz_questions.json'),
    'utf-8'
  );
  const allQuestions = JSON.parse(rawData);

  // Group by category
  const byCategory = {};
  for (const q of allQuestions) {
    if (!byCategory[q.category]) {
      byCategory[q.category] = [];
    }
    byCategory[q.category].push(q);
  }

  console.log('  Categories found:', Object.keys(byCategory));

  // Generate quizzes for each branch
  for (const [branch, categories] of Object.entries(CLASSIC_BRANCHES)) {
    const branchPath = path.join(OUTPUT_PATH, 'classic-quiz', branch);
    ensureDir(branchPath);

    // Collect questions for this branch
    const branchQuestions = [];
    for (const category of categories) {
      if (byCategory[category]) {
        branchQuestions.push(...byCategory[category]);
      }
    }

    // Shuffle and create quiz sets
    const shuffled = shuffle(branchQuestions);
    const quizCount = Math.floor(shuffled.length / CLASSIC_QUESTIONS_PER_QUIZ);
    const quizIds = [];

    for (let i = 0; i < quizCount; i++) {
      const quizId = `quiz_${String(i + 1).padStart(3, '0')}`;
      const questions = shuffled.slice(
        i * CLASSIC_QUESTIONS_PER_QUIZ,
        (i + 1) * CLASSIC_QUESTIONS_PER_QUIZ
      );

      const quiz = {
        quizId,
        title: `${branch.charAt(0).toUpperCase() + branch.slice(1)} Quiz ${i + 1}`,
        branch,
        questions: questions.map((q, idx) => ({
          id: `${quizId}_q${idx + 1}`,
          text: q.question,
          choices: q.options,
          category: q.category
        }))
      };

      fs.writeFileSync(
        path.join(branchPath, `${quizId}.json`),
        JSON.stringify(quiz, null, 2)
      );
      quizIds.push(quizId);
    }

    // Write quiz-order.json
    fs.writeFileSync(
      path.join(branchPath, 'quiz-order.json'),
      JSON.stringify({ quizzes: quizIds }, null, 2)
    );

    console.log(`  ✓ ${branch}: ${quizCount} quizzes (${branchQuestions.length} questions)`);
  }
}

// Generate Affirmation Quizzes
function generateAffirmationQuizzes() {
  console.log('\n💫 Generating Affirmation Quizzes...');

  const rawData = fs.readFileSync(
    path.join(FLUTTER_ASSETS_PATH, 'affirmation_quizzes.json'),
    'utf-8'
  );
  const data = JSON.parse(rawData);
  const allQuizzes = data.quizzes;

  console.log('  Quizzes found:', allQuizzes.map(q => q.id));

  // Map quizzes to branches
  for (const [branch, quizIds] of Object.entries(AFFIRMATION_BRANCH_MAPPING)) {
    const branchPath = path.join(OUTPUT_PATH, 'affirmation', branch);
    ensureDir(branchPath);

    const outputQuizIds = [];
    let quizNum = 1;

    for (const quizId of quizIds) {
      const sourceQuiz = allQuizzes.find(q => q.id === quizId);
      if (!sourceQuiz) {
        console.warn(`  ⚠️ Quiz ${quizId} not found`);
        continue;
      }

      const outputQuizId = `affirmation_${String(quizNum).padStart(3, '0')}`;

      const quiz = {
        quizId: outputQuizId,
        title: sourceQuiz.name,
        category: sourceQuiz.category,
        branch,
        description: sourceQuiz.description,
        questions: sourceQuiz.questions.map((q, idx) => ({
          id: `${outputQuizId}_q${idx + 1}`,
          text: q.question,
          type: 'scale',
          scaleLabels: ['Strongly Disagree', 'Disagree', 'Neutral', 'Agree', 'Strongly Agree']
        }))
      };

      fs.writeFileSync(
        path.join(branchPath, `${outputQuizId}.json`),
        JSON.stringify(quiz, null, 2)
      );
      outputQuizIds.push(outputQuizId);
      quizNum++;
    }

    // Write quiz-order.json
    fs.writeFileSync(
      path.join(branchPath, 'quiz-order.json'),
      JSON.stringify({ quizzes: outputQuizIds }, null, 2)
    );

    console.log(`  ✓ ${branch}: ${outputQuizIds.length} quizzes`);
  }
}

// Generate You-or-Me Quizzes
function generateYouOrMeQuizzes() {
  console.log('\n🤔 Generating You-or-Me Quizzes...');

  const rawData = fs.readFileSync(
    path.join(FLUTTER_ASSETS_PATH, 'you_or_me_questions.json'),
    'utf-8'
  );
  const data = JSON.parse(rawData);
  const allQuestions = data.questions;

  // Group by category
  const byCategory = {};
  for (const q of allQuestions) {
    if (!byCategory[q.category]) {
      byCategory[q.category] = [];
    }
    byCategory[q.category].push(q);
  }

  console.log('  Categories found:', Object.keys(byCategory));

  // Generate quizzes for each branch
  for (const [branch, categories] of Object.entries(YOUORME_BRANCH_MAPPING)) {
    const branchPath = path.join(OUTPUT_PATH, 'you-or-me', branch);
    ensureDir(branchPath);

    // Collect questions for this branch
    const branchQuestions = [];
    for (const category of categories) {
      if (byCategory[category]) {
        branchQuestions.push(...byCategory[category]);
      }
    }

    // Shuffle and create quiz sets
    const shuffled = shuffle(branchQuestions);
    const quizCount = Math.floor(shuffled.length / YOUORME_QUESTIONS_PER_QUIZ);
    const quizIds = [];

    for (let i = 0; i < quizCount; i++) {
      const quizId = `youorme_${String(i + 1).padStart(3, '0')}`;
      const questions = shuffled.slice(
        i * YOUORME_QUESTIONS_PER_QUIZ,
        (i + 1) * YOUORME_QUESTIONS_PER_QUIZ
      );

      const quiz = {
        quizId,
        title: `${branch.charAt(0).toUpperCase() + branch.slice(1)} Round ${i + 1}`,
        branch,
        questions: questions.map((q, idx) => ({
          id: `${quizId}_q${idx + 1}`,
          prompt: q.prompt,
          content: q.content
        }))
      };

      fs.writeFileSync(
        path.join(branchPath, `${quizId}.json`),
        JSON.stringify(quiz, null, 2)
      );
      quizIds.push(quizId);
    }

    // Write quiz-order.json
    fs.writeFileSync(
      path.join(branchPath, 'quiz-order.json'),
      JSON.stringify({ quizzes: quizIds }, null, 2)
    );

    console.log(`  ✓ ${branch}: ${quizCount} quizzes (${branchQuestions.length} questions)`);
  }
}

// Main
function main() {
  console.log('🚀 Quiz Content Migration Script');
  console.log('================================');

  // Ensure output directories exist
  ensureDir(path.join(OUTPUT_PATH, 'classic-quiz'));
  ensureDir(path.join(OUTPUT_PATH, 'affirmation'));
  ensureDir(path.join(OUTPUT_PATH, 'you-or-me'));

  generateClassicQuizzes();
  generateAffirmationQuizzes();
  generateYouOrMeQuizzes();

  console.log('\n✅ Migration complete!');
  console.log(`   Output directory: ${OUTPUT_PATH}`);
}

main();
