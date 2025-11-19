/**
 * Connection Limit Load Test
 * 
 * Tests database connection pooling under load
 * Target: Handle 60 concurrent connections (Supabase limit)
 * 
 * Usage: npx ts-node scripts/test_connection_limits.ts
 */

import { getPool } from '../lib/db/pool';

interface LoadTestResult {
  success: boolean;
  total_connections: number;
  max_connections_reached: number;
  errors: number;
  duration_ms: number;
}

async function simulateLoad(concurrentRequests: number): Promise<LoadTestResult> {
  console.log(`\n🧪 Testing with ${concurrentRequests} concurrent connections...`);
  const startTime = Date.now();
  
  const pool = getPool();
  const results = {
    success: true,
    total_connections: 0,
    max_connections_reached: 0,
    errors: 0,
    duration_ms: 0,
  };

  // Create concurrent queries
  const queries = Array.from({ length: concurrentRequests }, async (_, i) => {
    try {
      const client = await pool.connect();
      
      // Simulate real query
      await client.query('SELECT NOW()');
      
      // Track max connections
      results.max_connections_reached = Math.max(
        results.max_connections_reached,
        pool.totalCount
      );
      
      // Release client back to pool
      client.release();
      
      return { success: true, index: i };
    } catch (error) {
      results.errors++;
      results.success = false;
      console.error(`  ❌ Connection ${i} failed:`, error);
      return { success: false, index: i, error };
    }
  });

  // Execute all queries concurrently
  await Promise.all(queries);

  results.duration_ms = Date.now() - startTime;
  results.total_connections = pool.totalCount;

  return results;
}

async function runLoadTests() {
  console.log('🚀 Starting Database Connection Load Tests\n');
  console.log('Target: Handle 60 concurrent connections');
  console.log('Connection Pool Strategy: Single connection per worker\n');

  const testCases = [10, 25, 50, 60];
  const allResults: LoadTestResult[] = [];

  for (const concurrentConnections of testCases) {
    const result = await simulateLoad(concurrentConnections);
    allResults.push(result);

    // Print results
    console.log(`  ✅ Completed in ${result.duration_ms}ms`);
    console.log(`  📊 Max connections: ${result.max_connections_reached}`);
    console.log(`  ❌ Errors: ${result.errors}`);
    
    if (result.errors > 0) {
      console.log(`  ⚠️  WARNING: ${result.errors} failed connections`);
    }

    // Wait between tests
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 Load Test Summary\n');

  allResults.forEach((result, i) => {
    const testCase = testCases[i];
    const status = result.success ? '✅ PASS' : '❌ FAIL';
    console.log(`${status} ${testCase} connections: ${result.max_connections_reached} max, ${result.errors} errors`);
  });

  console.log('\n' + '='.repeat(60));

  // Final verdict
  const allPassed = allResults.every(r => r.success);
  const maxConnectionsHandled = Math.max(...allResults.map(r => r.max_connections_reached));

  if (allPassed && maxConnectionsHandled >= 60) {
    console.log('\n✅ ALL TESTS PASSED - Ready for production');
    console.log(`   Maximum connections handled: ${maxConnectionsHandled}`);
    process.exit(0);
  } else {
    console.log('\n❌ TESTS FAILED - Connection pooling needs adjustment');
    console.log(`   Maximum connections handled: ${maxConnectionsHandled}/60`);
    process.exit(1);
  }
}

// Run tests
runLoadTests().catch(error => {
  console.error('\n❌ Load test failed:', error);
  process.exit(1);
});
