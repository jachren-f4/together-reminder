/**
 * Auth Flow Load Test using k6
 * 
 * Tests authentication endpoints under high load
 * Target: 10K concurrent requests with <1ms JWT verification
 * 
 * Install k6: brew install k6
 * Run: k6 run tests/auth_load_test.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const jwtVerificationTime = new Trend('jwt_verification_ms');
const authErrorRate = new Rate('auth_errors');

// Test configuration
export const options = {
  stages: [
    // Ramp up to 100 users over 1 minute
    { duration: '1m', target: 100 },
    // Ramp up to 1000 users over 2 minutes
    { duration: '2m', target: 1000 },
    // Ramp up to 10000 users over 2 minutes
    { duration: '2m', target: 10000 },
    // Hold 10K users for 10 minutes
    { duration: '10m', target: 10000 },
    // Ramp down to 0 users over 1 minute
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    // HTTP errors should be less than 0.1%
    http_req_failed: ['rate<0.001'],
    // 95% of requests should be below 200ms
    http_req_duration: ['p(95)<200'],
    // JWT verification should be below 1ms (p95)
    jwt_verification_ms: ['p(95)<1'],
    // Auth error rate should be below 0.1%
    auth_errors: ['rate<0.001'],
  },
};

// Test JWT token (generate a valid one for your environment)
const TEST_TOKEN = __ENV.TEST_JWT_TOKEN || 'your-test-token-here';
const API_BASE_URL = __ENV.API_BASE_URL || 'http://localhost:3000';

export default function () {
  // Test 1: JWT Verification Endpoint
  const verifyStart = Date.now();
  
  const verifyResponse = http.get(`${API_BASE_URL}/api/auth/verify`, {
    headers: {
      'Authorization': `Bearer ${TEST_TOKEN}`,
    },
  });
  
  const verifyDuration = Date.now() - verifyStart;
  jwtVerificationTime.add(verifyDuration);
  
  const verifySuccess = check(verifyResponse, {
    'verify status is 200': (r) => r.status === 200,
    'verify response time < 100ms': (r) => r.timings.duration < 100,
    'verify has user ID': (r) => JSON.parse(r.body).userId !== undefined,
  });
  
  if (!verifySuccess) {
    authErrorRate.add(1);
  } else {
    authErrorRate.add(0);
  }
  
  // Test 2: Health Check (no auth required)
  const healthResponse = http.get(`${API_BASE_URL}/api/health`);
  
  check(healthResponse, {
    'health status is 200': (r) => r.status === 200,
    'health response time < 50ms': (r) => r.timings.duration < 50,
  });
  
  // Test 3: Metrics Endpoint (no auth required)
  const metricsResponse = http.get(`${API_BASE_URL}/api/metrics`);
  
  check(metricsResponse, {
    'metrics status is 200': (r) => r.status === 200,
  });
  
  // Small delay between iterations
  sleep(0.1);
}

export function handleSummary(data) {
  return {
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
    'auth_load_test_results.json': JSON.stringify(data, null, 2),
  };
}

function textSummary(data, options) {
  const indent = options.indent || '';
  const enableColors = options.enableColors !== false;
  
  let summary = '\n';
  summary += `${indent}=== Auth Load Test Summary ===\n\n`;
  
  // Requests
  summary += `${indent}HTTP Requests:\n`;
  summary += `${indent}  Total: ${data.metrics.http_reqs.values.count}\n`;
  summary += `${indent}  Failed: ${data.metrics.http_req_failed.values.rate * 100}%\n`;
  summary += `${indent}  Duration (p95): ${data.metrics.http_req_duration.values['p(95)']}ms\n\n`;
  
  // JWT Verification
  if (data.metrics.jwt_verification_ms) {
    summary += `${indent}JWT Verification:\n`;
    summary += `${indent}  Avg: ${data.metrics.jwt_verification_ms.values.avg.toFixed(2)}ms\n`;
    summary += `${indent}  P95: ${data.metrics.jwt_verification_ms.values['p(95)'].toFixed(2)}ms\n`;
    summary += `${indent}  P99: ${data.metrics.jwt_verification_ms.values['p(99)'].toFixed(2)}ms\n\n`;
  }
  
  // Auth Errors
  if (data.metrics.auth_errors) {
    summary += `${indent}Auth Errors:\n`;
    summary += `${indent}  Error Rate: ${(data.metrics.auth_errors.values.rate * 100).toFixed(3)}%\n\n`;
  }
  
  // Virtual Users
  summary += `${indent}Virtual Users:\n`;
  summary += `${indent}  Max: ${data.metrics.vus_max.values.max}\n\n`;
  
  return summary;
}
