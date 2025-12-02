/**
 * Shared Test Utilities
 *
 * Common assertion functions, test runners, and helper utilities
 * used across all game test suites.
 */

import { TEST_CONFIG } from './test-config';

// ============================================================================
// Types
// ============================================================================

export interface TestResult {
  name: string;
  passed: boolean;
  error?: string;
}

export interface ApiResponse {
  success?: boolean;
  error?: string;
  code?: string;
  [key: string]: unknown;
}

// ============================================================================
// Assertion Helpers
// ============================================================================

/**
 * Assert helper with descriptive error messages
 */
export function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

/**
 * Assert equality with descriptive error messages
 */
export function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

/**
 * Assert greater than or equal
 */
export function assertGte(actual: number, expected: number, message: string): void {
  if (actual < expected) {
    throw new Error(`${message}: expected >= ${expected}, got ${actual}`);
  }
}

// ============================================================================
// Test Runner
// ============================================================================

/**
 * Run a test function and report results
 */
export async function runTest(
  name: string,
  testFn: () => Promise<void>
): Promise<TestResult> {
  console.log(`\n📋 Running: ${name}`);
  try {
    await testFn();
    console.log(`  ✅ PASSED`);
    return { name, passed: true };
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    console.log(`  ❌ FAILED: ${errorMsg}`);
    return { name, passed: false, error: errorMsg };
  }
}

/**
 * Print test summary
 */
export function printSummary(results: TestResult[]): void {
  console.log('\n' + '='.repeat(60));
  console.log('TEST SUMMARY');
  console.log('='.repeat(60));

  const passed = results.filter((r) => r.passed).length;
  const failed = results.filter((r) => !r.passed).length;

  for (const result of results) {
    const icon = result.passed ? '✅' : '❌';
    console.log(`${icon} ${result.name}`);
    if (result.error) {
      console.log(`   └─ ${result.error}`);
    }
  }

  console.log('\n' + '-'.repeat(60));
  console.log(`Total: ${results.length} | Passed: ${passed} | Failed: ${failed}`);
  console.log('='.repeat(60));
}

// ============================================================================
// Data Reset
// ============================================================================

/**
 * Reset all test data for the test couple
 */
export async function resetTestData(): Promise<void> {
  const url = `${TEST_CONFIG.apiBaseUrl}/api/dev/reset-couple-progress`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    'X-Dev-User-Id': TEST_CONFIG.testUserId,
  };

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({ coupleId: TEST_CONFIG.coupleId }),
    });

    if (!response.ok) {
      const data = await response.json();
      console.warn('⚠️ Could not reset test data:', data.error);
      return;
    }

    console.log('✅ Test data reset successfully');
  } catch (error) {
    console.warn('⚠️ Could not reset test data:', error);
  }
}

// ============================================================================
// Timing Helpers
// ============================================================================

/**
 * Sleep for a specified duration
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ============================================================================
// Date Helpers
// ============================================================================

/**
 * Get today's date in YYYY-MM-DD format
 */
export function getTodayDate(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
}

// ============================================================================
// Answer Generation (for quiz-style games)
// ============================================================================

/**
 * Generate random answers for a quiz
 */
export function generateRandomAnswers(questionCount: number, maxChoices: number = 3): number[] {
  return Array.from({ length: questionCount }, () =>
    Math.floor(Math.random() * maxChoices)
  );
}

/**
 * Generate matching answers (both users give same answers)
 */
export function generateMatchingAnswers(questionCount: number): number[] {
  return Array.from({ length: questionCount }, () => 0); // All zeros = 100% match
}

/**
 * Generate non-matching answers (partner gives different answers)
 */
export function generateNonMatchingAnswers(userAnswers: number[], maxChoices: number = 3): number[] {
  return userAnswers.map((answer) => (answer + 1) % maxChoices); // Shift each answer
}

/**
 * Calculate expected match percentage
 */
export function calculateMatchPercentage(user: number[], partner: number[]): number {
  if (user.length === 0 || partner.length === 0) return 0;
  const total = Math.min(user.length, partner.length);
  let matches = 0;
  for (let i = 0; i < total; i++) {
    if (user[i] === partner[i]) matches++;
  }
  return Math.round((matches / total) * 100);
}
