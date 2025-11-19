/**
 * JWT Performance Load Test
 * 
 * Tests JWT verification under high concurrent load
 * Target: <1ms verification time with 10K+ concurrent requests
 * 
 * Usage: npx ts-node scripts/test_jwt_performance.ts
 */

import { performance } from 'perf_hooks';

// Mock environment for testing
process.env.SUPABASE_JWT_SECRET = 'test-secret-key-at-least-32-characters-long';

import { verifyToken } from '../lib/auth/jwt';
import jwt from 'jsonwebtoken';

interface LoadTestResult {
  totalRequests: number;
  successfulVerifications: number;
  failedVerifications: number;
  averageTime: number;
  minTime: number;
  maxTime: number;
  p50: number;
  p95: number;
  p99: number;
}

/**
 * Generate a test JWT token
 */
function generateTestToken(userId: string): string {
  const secret = process.env.SUPABASE_JWT_SECRET!;
  
  return jwt.sign(
    {
      sub: userId,
      email: `user${userId}@test.com`,
      role: 'authenticated',
      aud: 'authenticated',
    },
    secret,
    {
      algorithm: 'HS256',
      expiresIn: '1h',
    }
  );
}

/**
 * Run load test with specified number of concurrent requests
 */
async function runLoadTest(concurrentRequests: number): Promise<LoadTestResult> {
  console.log(`\n🧪 Testing ${concurrentRequests.toLocaleString()} concurrent verifications...`);

  const tokens = Array.from({ length: concurrentRequests }, (_, i) =>
    generateTestToken(`user-${i}`)
  );

  const verificationTimes: number[] = [];
  let successCount = 0;
  let failCount = 0;

  // Execute all verifications concurrently
  const startTime = performance.now();

  await Promise.all(
    tokens.map(async (token) => {
      const verifyStart = performance.now();
      const result = verifyToken(token);
      const verifyTime = performance.now() - verifyStart;

      verificationTimes.push(verifyTime);

      if (result.valid) {
        successCount++;
      } else {
        failCount++;
      }
    })
  );

  const totalTime = performance.now() - startTime;

  // Calculate statistics
  verificationTimes.sort((a, b) => a - b);
  const sum = verificationTimes.reduce((a, b) => a + b, 0);
  const avg = sum / verificationTimes.length;
  const min = verificationTimes[0];
  const max = verificationTimes[verificationTimes.length - 1];
  const p50 = verificationTimes[Math.floor(verificationTimes.length * 0.5)];
  const p95 = verificationTimes[Math.floor(verificationTimes.length * 0.95)];
  const p99 = verificationTimes[Math.floor(verificationTimes.length * 0.99)];

  console.log(`  ✅ Completed in ${totalTime.toFixed(2)}ms`);
  console.log(`  📊 Stats:`);
  console.log(`     Average: ${avg.toFixed(3)}ms`);
  console.log(`     P50: ${p50.toFixed(3)}ms`);
  console.log(`     P95: ${p95.toFixed(3)}ms`);
  console.log(`     P99: ${p99.toFixed(3)}ms`);
  console.log(`     Min: ${min.toFixed(3)}ms, Max: ${max.toFixed(3)}ms`);
  console.log(`     Success: ${successCount}, Failed: ${failCount}`);

  return {
    totalRequests: concurrentRequests,
    successfulVerifications: successCount,
    failedVerifications: failCount,
    averageTime: avg,
    minTime: min,
    maxTime: max,
    p50,
    p95,
    p99,
  };
}

/**
 * Main test suite
 */
async function main() {
  console.log('🚀 JWT Performance Load Test\n');
  console.log('Target: <1ms average verification time');
  console.log('Test: 10K+ concurrent verifications\n');

  const testCases = [100, 1000, 5000, 10000];
  const results: LoadTestResult[] = [];

  for (const testSize of testCases) {
    const result = await runLoadTest(testSize);
    results.push(result);

    // Brief pause between tests
    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  // Final Summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 Performance Summary\n');

  results.forEach((result) => {
    const avgStatus = result.averageTime < 1 ? '✅' : '⚠️';
    const p95Status = result.p95 < 1 ? '✅' : '⚠️';
    const successRate = (result.successfulVerifications / result.totalRequests) * 100;

    console.log(`${result.totalRequests.toLocaleString()} requests:`);
    console.log(`  ${avgStatus} Avg: ${result.averageTime.toFixed(3)}ms`);
    console.log(`  ${p95Status} P95: ${result.p95.toFixed(3)}ms`);
    console.log(`  ${successRate.toFixed(1)}% success rate\n`);
  });

  console.log('='.repeat(60));

  // Determine if test passed
  const finalResult = results[results.length - 1]; // 10K test
  const passed = 
    finalResult.averageTime < 1 && 
    finalResult.p95 < 1 && 
    finalResult.successfulVerifications === finalResult.totalRequests;

  if (passed) {
    console.log('\n✅ ALL TESTS PASSED - Production ready');
    console.log(`   10K concurrent verifications: ${finalResult.averageTime.toFixed(3)}ms avg`);
    console.log(`   Performance target (<1ms): MET ✅`);
    process.exit(0);
  } else {
    console.log('\n❌ TESTS FAILED - Performance below target');
    if (finalResult.averageTime >= 1) {
      console.log(`   Average time: ${finalResult.averageTime.toFixed(3)}ms (target: <1ms)`);
    }
    if (finalResult.p95 >= 1) {
      console.log(`   P95 time: ${finalResult.p95.toFixed(3)}ms (target: <1ms)`);
    }
    if (finalResult.successfulVerifications !== finalResult.totalRequests) {
      console.log(`   Failed verifications: ${finalResult.failedVerifications}`);
    }
    process.exit(1);
  }
}

// Run tests
main().catch((error) => {
  console.error('\n❌ Test failed:', error);
  process.exit(1);
});
