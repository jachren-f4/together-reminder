import jwt from 'jsonwebtoken';
import { performance } from 'perf_hooks';

// Configuration
const API_URL = process.env.API_URL || 'http://localhost:3000';
const JWT_SECRET = process.env.SUPABASE_JWT_SECRET;
const CONCURRENT_USERS = parseInt(process.env.CONCURRENT_USERS || '100');
const REQUESTS_PER_USER = parseInt(process.env.REQUESTS_PER_USER || '5');

if (!JWT_SECRET) {
    console.error('❌ Error: SUPABASE_JWT_SECRET environment variable is required.');
    process.exit(1);
}

interface RequestStats {
    duration: number;
    success: boolean;
    status: number;
}

function generateToken(userId: string): string {
    return jwt.sign(
        {
            sub: userId,
            role: 'authenticated',
            aud: 'authenticated',
            email: `user${userId}@example.com`,
        },
        JWT_SECRET!,
        { expiresIn: '1h' }
    );
}

async function simulateUser(userId: string): Promise<RequestStats[]> {
    const token = generateToken(userId);
    const stats: RequestStats[] = [];

    for (let i = 0; i < REQUESTS_PER_USER; i++) {
        const start = performance.now();
        try {
            // Simulate syncing daily quests
            const response = await fetch(`${API_URL}/api/sync/daily-quests`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${token}`,
                },
                body: JSON.stringify({
                    dateKey: new Date().toISOString().split('T')[0],
                    quests: [
                        {
                            id: `quest-${userId}-${i}`,
                            questType: 'quiz',
                            contentId: '00000000-0000-0000-0000-000000000000', // Mock UUID
                            sortOrder: i,
                            isSideQuest: false,
                            formatType: 'multiple_choice',
                            quizName: 'Load Test Quiz'
                        }
                    ]
                }),
            });

            const duration = performance.now() - start;
            stats.push({
                duration,
                success: response.ok,
                status: response.status,
            });

            // Small random delay between requests
            await new Promise(r => setTimeout(r, Math.random() * 500));

        } catch (error) {
            const duration = performance.now() - start;
            stats.push({
                duration,
                success: false,
                status: 0,
            });
        }
    }

    return stats;
}

async function runLoadTest() {
    console.log(`🚀 Starting Load Test`);
    console.log(`   URL: ${API_URL}`);
    console.log(`   Users: ${CONCURRENT_USERS}`);
    console.log(`   Requests/User: ${REQUESTS_PER_USER}`);
    console.log(`   Total Requests: ${CONCURRENT_USERS * REQUESTS_PER_USER}`);
    console.log('-----------------------------------');

    const startTime = performance.now();
    const userPromises: Promise<RequestStats[]>[] = [];

    for (let i = 0; i < CONCURRENT_USERS; i++) {
        userPromises.push(simulateUser(`user-${i}`));
    }

    const allStats = (await Promise.all(userPromises)).flat();
    const totalTime = performance.now() - startTime;

    // Analysis
    const successful = allStats.filter(s => s.success);
    const failed = allStats.filter(s => !s.success);
    const durations = allStats.map(s => s.duration).sort((a, b) => a - b);

    const avgDuration = durations.reduce((a, b) => a + b, 0) / durations.length;
    const p50 = durations[Math.floor(durations.length * 0.5)];
    const p95 = durations[Math.floor(durations.length * 0.95)];
    const p99 = durations[Math.floor(durations.length * 0.99)];

    console.log('\n📊 Results:');
    console.log(`   Total Time: ${(totalTime / 1000).toFixed(2)}s`);
    console.log(`   Throughput: ${(allStats.length / (totalTime / 1000)).toFixed(2)} req/s`);
    console.log(`   Success Rate: ${((successful.length / allStats.length) * 100).toFixed(2)}%`);
    console.log(`   Failed Requests: ${failed.length}`);
    console.log('\n⏱️ Latency:');
    console.log(`   Avg: ${avgDuration.toFixed(2)}ms`);
    console.log(`   P50: ${p50.toFixed(2)}ms`);
    console.log(`   P95: ${p95.toFixed(2)}ms`);
    console.log(`   P99: ${p99.toFixed(2)}ms`);

    if (failed.length > 0) {
        console.log('\n⚠️ Some requests failed. Check server logs.');
    }
}

runLoadTest().catch(console.error);
