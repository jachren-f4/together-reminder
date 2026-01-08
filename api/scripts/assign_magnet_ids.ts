/**
 * Assign Magnet IDs to Quiz Files
 *
 * Distributes quizzes across magnet packs:
 * - magnet_id: 0 = starter quizzes (first 6 per type)
 * - magnet_id: 1-N = unlocked with that magnet (6 per type per magnet)
 *
 * Usage: npx tsx scripts/assign_magnet_ids.ts
 * Use --dry-run to preview without writing
 */

import { readFileSync, writeFileSync, readdirSync } from 'fs';
import { join } from 'path';

const DRY_RUN = process.argv.includes('--dry-run');
const QUIZZES_PER_MAGNET_PER_TYPE = 6;

interface QuizFile {
  path: string;
  content: any;
  type: 'classic' | 'affirmation' | 'you_or_me';
  branch: string;
}

function loadQuizFiles(): QuizFile[] {
  const puzzlesPath = join(process.cwd(), 'data', 'puzzles');
  const files: QuizFile[] = [];

  const typeConfig = [
    { type: 'classic' as const, folder: 'classic-quiz', prefix: 'quiz_' },
    { type: 'affirmation' as const, folder: 'affirmation', prefix: 'affirmation_' },
    { type: 'you_or_me' as const, folder: 'you-or-me', prefix: 'quiz_' },
  ];

  for (const { type, folder, prefix } of typeConfig) {
    const typePath = join(puzzlesPath, folder);

    try {
      const branches = readdirSync(typePath, { withFileTypes: true })
        .filter(d => d.isDirectory())
        .map(d => d.name);

      for (const branch of branches) {
        const branchPath = join(typePath, branch);
        const quizFiles = readdirSync(branchPath)
          .filter(f => f.startsWith(prefix) && f.endsWith('.json'))
          .sort(); // Ensure consistent ordering

        for (const file of quizFiles) {
          const filePath = join(branchPath, file);
          try {
            const content = JSON.parse(readFileSync(filePath, 'utf-8'));
            files.push({ path: filePath, content, type, branch });
          } catch (e) {
            console.error(`Error reading ${filePath}:`, e);
          }
        }
      }
    } catch (e) {
      console.error(`Error reading ${folder}:`, e);
    }
  }

  return files;
}

function assignMagnetIds(files: QuizFile[]): void {
  // Group by type
  const byType = new Map<string, QuizFile[]>();
  for (const file of files) {
    const existing = byType.get(file.type) || [];
    existing.push(file);
    byType.set(file.type, existing);
  }

  console.log('\n=== Quiz Distribution ===\n');

  for (const [type, typeFiles] of byType.entries()) {
    console.log(`${type}: ${typeFiles.length} quizzes`);

    // Sort by branch then by quiz number for consistent assignment
    typeFiles.sort((a, b) => {
      const branchOrder = ['lighthearted', 'playful', 'connection', 'attachment', 'growth'];
      const branchA = branchOrder.indexOf(a.branch);
      const branchB = branchOrder.indexOf(b.branch);
      if (branchA !== branchB) return branchA - branchB;

      // Extract quiz number
      const numA = parseInt(a.content.quizId.match(/\d+/)?.[0] || '0');
      const numB = parseInt(b.content.quizId.match(/\d+/)?.[0] || '0');
      return numA - numB;
    });

    // Assign magnet IDs
    for (let i = 0; i < typeFiles.length; i++) {
      const magnetId = Math.floor(i / QUIZZES_PER_MAGNET_PER_TYPE);
      typeFiles[i].content.magnet_id = magnetId;
    }

    // Print distribution
    const distribution = new Map<number, number>();
    for (const file of typeFiles) {
      const magnetId = file.content.magnet_id;
      distribution.set(magnetId, (distribution.get(magnetId) || 0) + 1);
    }

    const sortedMagnets = Array.from(distribution.entries()).sort((a, b) => a[0] - b[0]);
    for (const [magnetId, count] of sortedMagnets) {
      const label = magnetId === 0 ? 'Starter' : `Magnet ${magnetId}`;
      console.log(`  ${label}: ${count} quizzes`);
    }
    console.log('');
  }

  // Write files
  if (DRY_RUN) {
    console.log('=== DRY RUN - No files modified ===\n');
    console.log('Sample updates:');
    for (const [type, typeFiles] of byType.entries()) {
      console.log(`\n${type}:`);
      for (const file of typeFiles.slice(0, 3)) {
        console.log(`  ${file.content.quizId} (${file.branch}) -> magnet_id: ${file.content.magnet_id}`);
      }
      console.log('  ...');
    }
  } else {
    console.log('=== Writing Files ===\n');
    let updated = 0;
    for (const file of files) {
      try {
        writeFileSync(file.path, JSON.stringify(file.content, null, 2) + '\n');
        updated++;
      } catch (e) {
        console.error(`Error writing ${file.path}:`, e);
      }
    }
    console.log(`Updated ${updated} quiz files.`);
  }
}

function main(): void {
  console.log('\n========================================');
  console.log('  ASSIGN MAGNET IDs TO QUIZ FILES');
  console.log('========================================');

  if (DRY_RUN) {
    console.log('\n⚠️  DRY RUN MODE - No files will be modified');
  }

  const files = loadQuizFiles();
  console.log(`\nLoaded ${files.length} quiz files.`);

  assignMagnetIds(files);

  console.log('\n========================================');
  console.log('  COMPLETE');
  console.log('========================================\n');

  if (DRY_RUN) {
    console.log('Run without --dry-run to apply changes.\n');
  }
}

main();
