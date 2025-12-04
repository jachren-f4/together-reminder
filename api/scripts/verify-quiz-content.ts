import * as fs from 'fs';
import * as path from 'path';

const PUZZLES_DIR = path.join(__dirname, '../data/puzzles');

interface QuizOrder {
  quizzes: string[];
}

interface ClassicQuestion {
  id: string;
  text: string;
  choices: string[];
  category?: string;
}

interface ClassicQuiz {
  quizId: string;
  title: string;
  branch: string;
  questions: ClassicQuestion[];
}

interface AffirmationQuestion {
  id: string;
  text: string;
  type: string;
  scaleLabels: string[];
}

interface AffirmationQuiz {
  quizId: string;
  title: string;
  branch: string;
  questions: AffirmationQuestion[];
}

interface YouOrMeQuestion {
  id: string;
  prompt: string;
  content: string;
  category?: string;
}

interface YouOrMeQuiz {
  quizId: string;
  title: string;
  branch: string;
  questions: YouOrMeQuestion[];
}

type GameType = 'classic-quiz' | 'affirmation' | 'you-or-me';
const BRANCHES = ['lighthearted', 'playful', 'connection', 'attachment', 'growth'];
const GAME_TYPES: GameType[] = ['classic-quiz', 'affirmation', 'you-or-me'];

let errors: string[] = [];
let warnings: string[] = [];

function validateClassicQuiz(quiz: ClassicQuiz, filePath: string): void {
  if (!quiz.quizId) errors.push(`${filePath}: Missing quizId`);
  if (!quiz.title) errors.push(`${filePath}: Missing title`);
  if (!quiz.branch) errors.push(`${filePath}: Missing branch`);
  if (!quiz.questions || quiz.questions.length === 0) {
    errors.push(`${filePath}: No questions found`);
    return;
  }
  if (quiz.questions.length !== 5) {
    warnings.push(`${filePath}: Expected 5 questions, found ${quiz.questions.length}`);
  }
  quiz.questions.forEach((q, i) => {
    if (!q.id) errors.push(`${filePath}: Question ${i + 1} missing id`);
    if (!q.text) errors.push(`${filePath}: Question ${i + 1} missing text`);
    if (!q.choices || q.choices.length < 2) {
      errors.push(`${filePath}: Question ${i + 1} needs at least 2 choices`);
    }
  });
}

function validateAffirmationQuiz(quiz: AffirmationQuiz, filePath: string): void {
  if (!quiz.quizId) errors.push(`${filePath}: Missing quizId`);
  if (!quiz.title) errors.push(`${filePath}: Missing title`);
  if (!quiz.branch) errors.push(`${filePath}: Missing branch`);
  if (!quiz.questions || quiz.questions.length === 0) {
    errors.push(`${filePath}: No questions found`);
    return;
  }
  if (quiz.questions.length !== 5) {
    warnings.push(`${filePath}: Expected 5 questions, found ${quiz.questions.length}`);
  }
  quiz.questions.forEach((q, i) => {
    if (!q.id) errors.push(`${filePath}: Question ${i + 1} missing id`);
    if (!q.text) errors.push(`${filePath}: Question ${i + 1} missing text`);
    if (q.type !== 'scale') {
      warnings.push(`${filePath}: Question ${i + 1} has type '${q.type}' instead of 'scale'`);
    }
    if (!q.scaleLabels || q.scaleLabels.length !== 5) {
      errors.push(`${filePath}: Question ${i + 1} needs 5 scaleLabels`);
    }
  });
}

function validateYouOrMeQuiz(quiz: YouOrMeQuiz, filePath: string): void {
  if (!quiz.quizId) errors.push(`${filePath}: Missing quizId`);
  if (!quiz.title) errors.push(`${filePath}: Missing title`);
  if (!quiz.branch) errors.push(`${filePath}: Missing branch`);
  if (!quiz.questions || quiz.questions.length === 0) {
    errors.push(`${filePath}: No questions found`);
    return;
  }
  if (quiz.questions.length !== 5 && quiz.questions.length !== 10) {
    warnings.push(`${filePath}: Expected 5 or 10 questions, found ${quiz.questions.length}`);
  }
  quiz.questions.forEach((q, i) => {
    if (!q.id) errors.push(`${filePath}: Question ${i + 1} missing id`);
    if (!q.prompt) errors.push(`${filePath}: Question ${i + 1} missing prompt`);
    if (!q.content) errors.push(`${filePath}: Question ${i + 1} missing content`);
  });
}

function validateBranch(gameType: GameType, branch: string): number {
  const branchDir = path.join(PUZZLES_DIR, gameType, branch);

  if (!fs.existsSync(branchDir)) {
    errors.push(`${gameType}/${branch}: Directory does not exist`);
    return 0;
  }

  // Check quiz-order.json
  const orderPath = path.join(branchDir, 'quiz-order.json');
  if (!fs.existsSync(orderPath)) {
    errors.push(`${gameType}/${branch}: Missing quiz-order.json`);
    return 0;
  }

  const orderData: QuizOrder = JSON.parse(fs.readFileSync(orderPath, 'utf-8'));
  if (!orderData.quizzes || orderData.quizzes.length === 0) {
    errors.push(`${gameType}/${branch}: quiz-order.json has no quizzes`);
    return 0;
  }

  if (orderData.quizzes.length !== 12) {
    warnings.push(`${gameType}/${branch}: Expected 12 quizzes in order, found ${orderData.quizzes.length}`);
  }

  // Validate each quiz file
  let validQuizCount = 0;
  for (const quizId of orderData.quizzes) {
    const quizFile = `${quizId}.json`;
    const quizPath = path.join(branchDir, quizFile);

    if (!fs.existsSync(quizPath)) {
      errors.push(`${gameType}/${branch}: Missing quiz file ${quizFile}`);
      continue;
    }

    try {
      const quizData = JSON.parse(fs.readFileSync(quizPath, 'utf-8'));

      if (gameType === 'classic-quiz') {
        validateClassicQuiz(quizData, `${gameType}/${branch}/${quizFile}`);
      } else if (gameType === 'affirmation') {
        validateAffirmationQuiz(quizData, `${gameType}/${branch}/${quizFile}`);
      } else if (gameType === 'you-or-me') {
        validateYouOrMeQuiz(quizData, `${gameType}/${branch}/${quizFile}`);
      }

      validQuizCount++;
    } catch (e) {
      errors.push(`${gameType}/${branch}/${quizFile}: Invalid JSON - ${e}`);
    }
  }

  return validQuizCount;
}

function main(): void {
  console.log('=== Quiz Content Verification ===\n');

  let totalQuizzes = 0;
  const summary: Record<string, Record<string, number>> = {};

  for (const gameType of GAME_TYPES) {
    summary[gameType] = {};
    for (const branch of BRANCHES) {
      const count = validateBranch(gameType, branch);
      summary[gameType][branch] = count;
      totalQuizzes += count;
    }
  }

  // Print summary
  console.log('Quiz Counts:');
  console.log('─'.repeat(60));
  for (const gameType of GAME_TYPES) {
    console.log(`\n${gameType}:`);
    for (const branch of BRANCHES) {
      const count = summary[gameType][branch];
      const status = count === 12 ? '✓' : '✗';
      console.log(`  ${status} ${branch}: ${count}/12`);
    }
  }

  console.log('\n' + '─'.repeat(60));
  console.log(`Total Quizzes: ${totalQuizzes}/180`);

  // Print errors and warnings
  if (errors.length > 0) {
    console.log('\n❌ ERRORS:');
    errors.forEach(e => console.log(`  - ${e}`));
  }

  if (warnings.length > 0) {
    console.log('\n⚠️  WARNINGS:');
    warnings.forEach(w => console.log(`  - ${w}`));
  }

  if (errors.length === 0 && warnings.length === 0) {
    console.log('\n✅ All quizzes validated successfully!');
  }

  // Exit with error code if errors found
  if (errors.length > 0) {
    process.exit(1);
  }
}

main();
