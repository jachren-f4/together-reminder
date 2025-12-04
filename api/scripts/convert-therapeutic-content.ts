/**
 * Convert therapeutic quiz content from Flutter app format to API server format
 *
 * Flutter format: questions.json with array of {id, question, options, category}
 * Server format: individual quiz_XXX.json files with {quizId, title, branch, questions: [{id, text, choices, category}]}
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';

const FLUTTER_DATA_PATH = join(__dirname, '../../app/assets/brands/togetherremind/data');
const SERVER_DATA_PATH = join(__dirname, '../data/puzzles');

const QUESTIONS_PER_QUIZ = 5;

interface FlutterQuestion {
  id: string;
  question: string;
  options: string[];
  category: string;
  difficulty?: number;
  tier?: number;
}

interface ServerQuestion {
  id: string;
  text: string;
  choices: string[];
  category: string;
}

interface ServerQuiz {
  quizId: string;
  title: string;
  branch: string;
  questions: ServerQuestion[];
}

function convertQuestion(q: FlutterQuestion): ServerQuestion {
  return {
    id: q.id,
    text: q.question,
    choices: q.options,
    category: q.category,
  };
}

function convertBranch(
  activityType: 'classic-quiz' | 'affirmation' | 'you-or-me',
  branch: string,
  displayName: string
) {
  const flutterPath = join(FLUTTER_DATA_PATH, activityType, branch, 'questions.json');
  const serverPath = join(SERVER_DATA_PATH, activityType, branch);

  if (!existsSync(flutterPath)) {
    console.log(`⚠️  Skipping ${activityType}/${branch} - no questions.json found`);
    return;
  }

  // Create directory if it doesn't exist
  if (!existsSync(serverPath)) {
    mkdirSync(serverPath, { recursive: true });
  }

  // Read Flutter questions
  const flutterData = JSON.parse(readFileSync(flutterPath, 'utf-8'));
  const questions: FlutterQuestion[] = Array.isArray(flutterData) ? flutterData : flutterData.questions;

  console.log(`📖 Converting ${activityType}/${branch}: ${questions.length} questions`);

  // Split into quizzes of 5 questions each
  const quizIds: string[] = [];
  let quizNum = 1;

  for (let i = 0; i < questions.length; i += QUESTIONS_PER_QUIZ) {
    const quizQuestions = questions.slice(i, i + QUESTIONS_PER_QUIZ);
    const quizId = `quiz_${String(quizNum).padStart(3, '0')}`;
    quizIds.push(quizId);

    const quiz: ServerQuiz = {
      quizId,
      title: `${displayName} Quiz ${quizNum}`,
      branch,
      questions: quizQuestions.map((q, idx) => ({
        id: `${quizId}_q${idx + 1}`,
        text: q.question,
        choices: q.options,
        category: q.category,
      })),
    };

    const quizPath = join(serverPath, `${quizId}.json`);
    writeFileSync(quizPath, JSON.stringify(quiz, null, 2));
    console.log(`  ✅ Created ${quizId}.json (${quiz.questions.length} questions)`);

    quizNum++;
  }

  // Write quiz-order.json
  const orderPath = join(serverPath, 'quiz-order.json');
  writeFileSync(orderPath, JSON.stringify({ quizzes: quizIds }, null, 2));
  console.log(`  ✅ Created quiz-order.json (${quizIds.length} quizzes)`);
}

// Affirmation quizzes use a different format (quizzes.json with scale questions)
function convertAffirmationBranch(
  activityType: 'affirmation',
  branch: string,
  displayName: string
) {
  const flutterPath = join(FLUTTER_DATA_PATH, activityType, branch, 'quizzes.json');
  const serverPath = join(SERVER_DATA_PATH, activityType, branch);

  if (!existsSync(flutterPath)) {
    console.log(`⚠️  Skipping ${activityType}/${branch} - no quizzes.json found`);
    return;
  }

  // Create directory if it doesn't exist
  if (!existsSync(serverPath)) {
    mkdirSync(serverPath, { recursive: true });
  }

  // Read Flutter quizzes
  const flutterData = JSON.parse(readFileSync(flutterPath, 'utf-8'));
  const quizzes = flutterData.quizzes || [];

  console.log(`📖 Converting ${activityType}/${branch}: ${quizzes.length} quizzes`);

  const quizIds: string[] = [];
  const scaleLabels = ['Strongly Disagree', 'Disagree', 'Neutral', 'Agree', 'Strongly Agree'];

  quizzes.forEach((quiz: any, quizIdx: number) => {
    const quizId = `affirmation_${String(quizIdx + 1).padStart(3, '0')}`;
    quizIds.push(quizId);

    const serverQuiz = {
      quizId,
      title: quiz.name || `${displayName} ${quizIdx + 1}`,
      category: quiz.category || branch,
      branch,
      description: quiz.description || `Rate your ${branch} together`,
      questions: (quiz.questions || []).map((q: any, qIdx: number) => ({
        id: `${quizId}_q${qIdx + 1}`,
        text: q.question,
        type: 'scale',
        scaleLabels,
      })),
    };

    const quizPath = join(serverPath, `${quizId}.json`);
    writeFileSync(quizPath, JSON.stringify(serverQuiz, null, 2));
    console.log(`  ✅ Created ${quizId}.json (${serverQuiz.questions.length} questions)`);
  });

  // Write quiz-order.json
  const orderPath = join(serverPath, 'quiz-order.json');
  writeFileSync(orderPath, JSON.stringify({ quizzes: quizIds }, null, 2));
  console.log(`  ✅ Created quiz-order.json (${quizIds.length} quizzes)`);
}

// Convert therapeutic branches for each activity type
console.log('\n🔄 Converting Classic Quiz therapeutic branches...\n');
convertBranch('classic-quiz', 'meaningful', 'Meaningful');
convertBranch('classic-quiz', 'connection', 'Connection');
convertBranch('classic-quiz', 'attachment', 'Attachment');
convertBranch('classic-quiz', 'growth', 'Growth');

console.log('\n🔄 Converting Affirmation therapeutic branches...\n');
convertAffirmationBranch('affirmation', 'connection', 'Connection');
convertAffirmationBranch('affirmation', 'attachment', 'Attachment');
convertAffirmationBranch('affirmation', 'growth', 'Growth');

console.log('\n🔄 Converting You-or-Me therapeutic branches...\n');
convertBranch('you-or-me', 'connection', 'Connection');
convertBranch('you-or-me', 'attachment', 'Attachment');
convertBranch('you-or-me', 'growth', 'Growth');

console.log('\n✨ Conversion complete!\n');
