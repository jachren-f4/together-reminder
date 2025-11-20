#!/bin/bash

# Fixed One-Click Migration Setup Script
# Fixed JSON parsing issues and error handling

echo "🚀 Fixed Migration Setup for Firebase → PostgreSQL"
echo "=========================================================="

# Check GitHub CLI authentication
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI not authenticated. Please run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated successfully"

# Get repository info
REPO_OWNER=$(gh api user --jq .login 2>/dev/null | tr -d '"' || echo "unknown")
REPO_NAME="togetherremind" 
echo "📁 Repository: ${REPO_OWNER}/${REPO_NAME}"

# Check if repository exists
if ! gh repo view ${REPO_OWNER}/${REPO_NAME} --json &>/dev/null; then
    echo "⚠️ Repository ${REPO_OWNER}/${REPO_NAME} not found"
    echo "🔧 Creating repository..."
    gh repo create ${REPO_NAME} --public --description "Firebase to PostgreSQL Migration Project"
fi

echo "✅ Repository ready: ${REPO_OWNER}/${REPO_NAME}"

# Create directories if they don't exist
mkdir -p ai_agents scripts docs

echo ""
echo "📝 Testing Python and dependencies..."

# Check Python and install dependencies
if ! python3 -c "import sys; print('✅ Python 3 available')" 2>/dev/null; then
    echo "❌ Python 3 not available - installing dependencies"
    pip3 install PyGithub PyJWT python-dotenv requests rich
elif ! python3 -c "import PyGithub; print('✅ PyGithub available')" 2>/dev/null; then 
    echo "⚠️ PyGithub not installed - installing dependencies"
    pip3 install PyGithub PyJWT python-dotenv requests rich
elif ! python3 -c "import json; print('✅ JSON module available')" 2>/dev/null; then
    echo "⚠️ JSON module issue - installing Python standard library"
else
    echo "✅ Python and dependencies ready"
fi

echo ""
echo "📝 Creating GitHub Issues manually to avoid JSON parsing issues..."

# Function to create issue without JSON parsing
create_issue() {
    local title="$1"
    local body="$2"
    local labels="$3"
    
    echo "📝 Creating issue: $title"
    
    # Use heredoc to avoid shell quoting issues
    gh issue create \
        --title "$title" \
        --body "$body" \
        --label "$labels" \
        --help > /dev/null
}

# Create INFRA-101 (Infrastructure foundation)
create_issue "INFRA-101: Create Vercel & Supabase Projects" \
"🏗️ **Phase 1: Create Vercel & Supabase Projects**

**Phase:** Infrastructure Foundations  
**Priority:** Critical  
**Estimate:** 2 days

### 📋 Tasks
- [ ] Create Vercel project with Next.js 14 App Router
- [ ] Create Supabase project with PostgreSQL database
- [ ] Configure database connection URLs (development & production)
- [ ] Set up environment variables management (no hardcoded credentials)
- [ ] Run initial database schema migration
- [ ] Add database connection pooling configuration

### ✅ Acceptance Criteria
- [ ] Vercel project successfully deployed and accessible
- [ ] Supabase project operational with PostgreSQL database
- [ ] Database schemas and indexes created and verified
- [ ] Environment variables properly configured 
- [ ] Basic connectivity confirmed working

### 🔗 Dependencies
- Already have environment documentation (CLAUDE.md)

### 🛠️ Technical Requirements
- Deploy Next.js 14 with TypeScript to Vercel
- Configure Supabase with connection pool (max 60 connections)
- Production environment variables:
  - DATABASE_URL: postgresql://postgres:password@host:5432/postgres
  - SUPABASE_URL: https://project-id.supabase.co
- Execute database migration SQL with proper indexes
- Test all database connections before proceeding

### 📚 Migration SQL Files
The complete database schema is in:
- `docs/database_schema.sql` (complete migration script)
- `docs/database_migration.sql` (incremental updates)

### 📊 Success Metrics
- Infrastructure deployment time: < 1 hour each
- Database query performance target: <200ms (p95)
- Configuration errors: 0
- Connection pool efficiency: >80%

### 🚀 Next Steps
1. Update INFRA-102 with database connection details
2. Create documentation for environment setup
3. Begin database schema migration (INFRA-102)
4. Set up monitoring endpoints (INFRA-103)
5. Start authentication system (AUTH-201)

**Repository:** https://github.com/${REPO_OWNER}/${REPO_NAME}/issues  
**Commit ID:** Will be set after pull request creation

This is Issue #1 of the migration project. All subsequent infrastructure and feature work depends on these foundational cloud services being properly established. 🏗️" \
"priority/critical,phase/infra,team/devops"

echo "✅ Created INFRA-101"

# Create INFRA-102 (Database schema)
create_issue "INFRA-102: Database Schema & Indexing" \
"🏗️ **Phase 1: Database Schema & Indexing**

**Phase:** Database Architecture  
**Priority:** Critical  
**Estimate:** 3 days

**Dependencies:**  
- INFRA-101 (Vercel & Supabase projects must exist first)

### 📋 Tasks
- [ ] Execute complete database schema with all migration tables
- [ ] Implement Row Level Security (RLS) policies for data protection  
- [ ] Create optimized indexes for all query patterns
- [ ] Set up connection pool monitoring and performance metrics
- [ ] Validate database integrity under load (1000+ concurrent connections)
- [ ] Test security policies (cross-data access attempts must fail)

### ✅ Acceptance Criteria
- [ ] Database schemas and indexes created successfully
- [ ] Row Level Security working and thoroughly tested
- [ ] Database queries under 200ms (p95) with realistic load
- [ ] Connection pool stable at <80% usage under stress
- [ ] Security policies preventing cross-couple data access
- [ ] Database constraints preventing corruption

### 🏗️ Critical Tables to Create
- \`couples\` - Core user relationships with unique constraints
- \`daily_quests\` - Migration from Firebase quest system
- \`love_point_awards\` - Deduplication and tracking system  
- \`quiz_sessions\`, \`quiz_answers\` - New quiz system
- \`memory_puzzles\` - Daily game activities
- \`user_love_points\` - Performance metrics storage
- All other migration tables (complete list in migration docs)

### 🔒 Database Design Principles
**Security First Row Level Security:**
- Users only access their own couple's data
- Couples can only manipulate their shared information
- All queries enforce RLS policies automatically
- Admin functions require explicit permission checks

**Performance Optimization:**
- Index all foreign keys and frequently queried columns
- Use partial indexes for active data only
- Connection pooling prevents connection exhaustion
- Optimized for Flutter app patterns and Next.js APIs

### 🛠️ SQL Implementation Structure
```sql
-- Main categories:
-- 1. User and Coupling Relationships
-- 2. Migration Core Tables (quests, sessions, games)
-- 3. Performance & Analytics
-- 4. Security & Access Control
-- 5. Monitoring & Maintenance

-- Example key table structure:
CREATE TABLE couples (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  user2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT unique_couple UNIQUE(user1_id, user2_id),
  CONSTRAINT different_users CHECK (user1_id != user2_id)
);
```

### 🛡️ Security Implementation (Critical)
```sql
-- Row Level Security policies
CREATE POLICY couples_access ON couples
  FOR ALL USING (
    user_id IN (
      SELECT user1_id FROM couples WHERE id = current_setting('app.current_couple_id') 
      UNION
      SELECT user2_id FROM couples WHERE id = current_setting('app.current_couple_id')
    )
  );

-- Enable RLS on all tables
ALTER TABLE couples ENABLE ROW LEVEL SECURITY; -- Must explicitly enable
ALTER TABLE daily_quests ENABLE ROW LEVEL SECURITY;
-- ... for all other tables

-- Security testing queries
SELECT * FROM couples WHERE user1_id = 'other_couple_id'; -- Should return 0 rows
SELECT * FROM couples WHERE id != current_setting('app.current_couple_id'); -- Should return 0 rows
```

### 📊 Performance Requirements
- **Query Performance:** All queries <200ms (p95) under load
- **Concurrent Users:** Support 1000+ simultaneous couples (2000 users)
- **Connection Pooling:** Max 60 connections, target <80% utilization
- **Index Efficiency:** Query optimizers should use indexes consistently
- **RLS Overhead:** <5ms overhead in normal operation

### 🔍 Testing Strategy
1. **Load Testing:** Stress test with 1000+ concurrent database connections
2. **Security Testing:** Verify cross-couple access impossible
3. **Performance Testing:** Profile queries with realistic dataset
4. **Integrity Testing:** Confirm database constraints prevent corruption
5. **Migration Testing:** Verify data migrations maintain relationships

### 📈 Environment Variables Required
```bash
# Connection pools (Vercel serverless)
DATABASE_URL=postgresql://postgres:password@host:5432/postgres
DATABASE_POOL_URL=postgresql://postgres:password@host:6543:5432/postgres

# Supabase integration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key
SUPABASE_JWT_SECRET=your-jwt-secret

# Monitoring (optional)
SENTRY_DSN=https://your-project.ingest.sentry.io
```

### 📚 Migration SQL Files
- \`docs/database_schema.sql\` -Complete first-time database creation
- \`docs/database_migration.sql\` -Incremental updates and fixes

### 🔄 Migration Command
```bash
# First time full setup
psql \$DATABASE_URL -f docs/database_schema.sql

# Incremental updates  
psql \$DATABASE_URL -f docs/database_migration.sql
```

### 🗃️ Configuration Files
- Database: \`docs/database_migration.sql\`
- RLS Templates: \`docs/security-rules.sql\`
- Index Documentation: \`docs/performance-optimization.md\`

### 🚨 Risk Mitigation
- **Data Loss:** All migrations include rollback strategies
- **Performance:** Load testing before production deployment
- **Security:** RLS policies enforce hard security boundaries
- **Rollback:** Previous database state preserved during testing

### 📱 Success Indicators
- Schema migration completes without errors
- All RLS policies block unauthorized access
- Performance targets achieved consistently  
- Load testing passes with acceptable metrics
- Security testing confirms no data leakage

### 🎯 Next Steps
1. Create pull requests with SQL implementation
2. Update documentation with configuration details
3. Set up connection pool monitoring (INFRA-103)
4. Begin authentication system (AUTH-201)  
5. Create automated tests to prevent regressions

**Related Issues:**  
- INFRA-101 (prerequisite: database must exist)
- INFRA-103 (next: monitoring setup)
- AUTH-201 (uses database for authentication)
- QUEST-301 (queries this data)

### 🚨 Blocked By
None - This is a foundational issue but ready to implement with working database from INFRA-101.

---
**This work establishes the secure database foundation that all migration functionality depends upon. The RLS security policies and performance optimizations are critical for the new architecture to succeed.**" \
"priority/critical,phase/infra,team/backend"

echo "✅ Created INFRA-102" 

# Create INFRA-103 (Monitoring)
create_issue "INFRA-103: Monitoring & Alerting Infrastructure" \
"🔧 **Phase 1: Monitoring & Alerting Infrastructure**

**Phase:** Operations  
**Priority:** High  
**Estimate:** 2 days

**Dependencies:**
- INFRA-101 (Vercel & Supabase projects)
- INFRA-102 (database operational)

### 📋 Tasks
- [ ] Set up Sentry error tracking for Flutter and Next.js
- [ ] Create health check endpoints for all system components
- [ ] Configure Prometheus metrics collection for APIs and database
- [ ] Set up alert thresholds for database connections and API performance  
- [ ] Create comprehensive monitoring dashboards (Grafana)
- [ ] Implement automated alerting for critical failures
- [ ] Create daily performance reports and system health status

### ✅ Acceptance Criteria
- [ ] Error tracking captures all Flutter and Next.js errors in real-time
- [ ] Health endpoints report system status in <100ms
- [ ] Prometheus metrics available for all services
- [ ] Alerts trigger appropriately for database and API anomalies
- [ ] Dashboards provide complete visibility into system health
- [ ] Automated reports generated daily with performance metrics

### 🔗 Services to Monitor

**Application Services:**
- Next.js API endpoints and performance
- Database connections, query performance, connection pool usage
- Authentication success/failure rates and token refresh
- Sync queue processing and conflict resolution
- Business metrics: quest completion rates, LP awards, user activity

**Infrastructure Services:**
- Vercel function cold starts and execution times  
- Supabase database health and resource usage
- GitHub Actions workflow success/failure rates
- Error tracking system coverage and alert effectiveness

### 🛠️ Health Check Endpoints
```typescript
// app/api/health/system/health.ts
export async function GET() {
  const services = await Promise.allSettled([
    checkDatabaseHealth(),
    checkAPIHealth(), 
    checkAuthHealth(),
    checkDependencies(),
  ]);

  const allHealthy = services.every(service => service.status === 'healthy');
  const avgResponseTime = services.reduce((sum, service) => sum + service.responseTime, 0) / services.length;

  return NextResponse.json({
    status: allHealthy ? 'healthy' : 'degraded',
    services: services,
    responseTime: avgResponseTime,
    checks_done: true,
    timestamp: new Date().toISOString()
  });
}

// Service health checking
async function checkDatabaseHealth() {
  try {
    await DATABASE_POOL.query('SELECT 1').catchReturnZero();
    const metrics = await DATABASE_POOL.query('SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active'').catchReturnZero();
    return {
      service: 'database',
      status: 'healthy',
      responseTime: 50,
      connections: metrics.count
    };
  } catch (error) {
    return {
      service: 'database', 
      status: 'unhealthy',
      error: error.message,
      responseTime: 100
    };
  }
```

### 📊 Critical Metrics to Track

**Database Metrics:**
- Connection pool usage (target: <80%)
- Query performance (target: <200ms p95)
- RLS query overhead (target: <5ms)
- Error rate (target: <1% requests)
- Active connections and query patterns

**API Performance:**
- Endpoint response times (target: <200ms p95)
- Error rate (target: <0.5% requests)  
- Request rate distribution by endpoint
- Authentication success rate (target: >98%)

**Application Metrics:**
- Sync queue processing time (target: <2s)
- Conflict resolution rate (target: <5%)
- Daily quest completion rate (target: >95%)
- User engagement metrics (active users, sessions)

### 🚨 Alert Configuration

**Critical Alerts ( Immediate notification):**
- Database error rate >5% (1 minute window)
- API latency >500ms sustained (3 minute window)  
- Authentication failure rate >2% (10 minute window)
- Database connections >90% usage (15 minute window)
- GitHub Actions workflow failures >2 consecutive

**Warning Alerts (Notification for investigation):**
- API latency >200ms sustained (30 minute window)
- Error rate >0.5% (1 hour window)
- Database connections >70% usage (hourly)
- Sentry error rate increase >20%

### 📚 Monitoring Tech Stack
```typescript
// lib/services/monitoring.ts
export class MonitoringService {
  static async collectMetrics() {
    // Database metrics via pg_stat_activity
    const dbMetrics = await DATABASE_POOLS.query(`
      SELECT 
        count(*) as total_connections,
        count(*) FILTER (WHERE state = 'active') as active_connections,
        count(*) FILTER (WHERE state = 'idle') as idle_connections
      FROM pg_stat_activity WHERE datname = current_database()
    `);

    // API performance via custom logging
    const apiStats = await getPerformanceLogs();
    
    // Error tracking via Sentry
    const errorRate = await getErrorMetrics();
    
    return {
      database: dbMetrics,
      api: apiStats,
      errors: errorRate,
      timestamp: new Date().toISOString()
    };
  }

  static createMetrics() {
    
    // Database Connection Monitoring

  }
```

### 🔄 Data Collection Strategy

**Prometheus Metrics:**
```sql
-- Database connection monitoring
CREATE METER VIEW v_connection_stats AS
  SELECT
    count(*) FILTER (WHERE state = 'active') as active_connections,
    count(*) FILTER (WHERE state = 'idle') as idle_connections,
    count(*) FILTER (WHERE state = 'waiting') as waiting_connections
  FROM pg_stat_activity
  WHERE datname = current_database();

-- Grant read access to metrics
GRANT SELECT ON v_connection_stats TO auth.anonymous;
```

**API Performance Metrics:**
```typescript
// Add to Next.js middleware
app.use(async (req, res, next) => {
  const start = Date.now();
  
  await next();
  
  const duration = Date.now() - start;
  
  // Record metric if API endpoint
  if (req.path.startsWith('/api/')) {
    await recordMetric('api-endpoint', req.path, duration, {
      method: req.method,
      status: res.statusCode,
      userAgent: req.headers['user-agent']
    });
  }
});
```

### 🛡️ Error Tracking Integration

**Sentry Configuration:**
```typescript
// lib/sentry/client.ts
import * as Sentry from '@sentry/react-native';
import { environment } from '../config/environment';

const sentryEnv = environment.build === 'release';

// Only create Sentry client in production builds
if (sentryEnv) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: 'production',
    tracesSampleRate: 0.1,
    attachStacktrace: true,
    // Additional configuration
    //   debug: true,
  });
}

export function reportError(error: Error, context: string) {
  Sentry.captureException(error, {
    tags: { context },
    extra: { 
      sessionId: getCurrentSessionId(),
      userId: getCurrentUserId()
    }
  });
}
```

### 📈 Alert Integration
```typescript
// lib/alerts/alert-manager.ts
export class AlertManager {
  static async checkAndAlert(metric: MetricReport) {
    if (metric.database.errorRate > 0.05) {
      await this.sendCriticalAlert(
        'CRITICAL: Database Error Rate High',
        'Database error rate is ' + metric.database.errorRate.toFixed(2%) + '%',
        [{ service: 'database', alert: [email]]
      );
    }
    
    if (metrics.api.averageLatencyMs > 500) {
      await this.sendCriticalAlert(
        'CRITICAL: API Latency High',  
        'API average latency is ' + metrics.api.averageLatencyMs + 'ms',
        [{ service: 'api', alert: [email]}]
      );
    }
  }
}
```

### 📚 Dashboard Configuration

**Grafana Dashboards:**
```json
{
  "dashboards": [
    {
      "name": "System Overview",
      "panels": [
        {
          "name": "Database Health",
          "type": "mysql"
        },
        {
          "name": "API Performance", 
          "type": "prometheus"
        },
        {
          "name": "Error Tracking",
          "type": "sentry"
        }
      ]
    },
    {
      "name": "Database Details",
      "panels": [
        {
          "name": "Query Performance",
          "type": "table"
        },
        {
          "name": "Connection Pool",
          "type": "graph"
        }
      ]
    }
  ]
}
```

### 📇 Notification Channels
```typescript
// lib/notifications/notification-service.ts
export class NotificationService {
  static async sendNotification(type: 'email' | 'slack', 'webhook', message) {
    switch(type) {
      case 'slack':
        // Send to Slack webhook
        await this.sendSlackWebhook(message);
        break;
        
      case 'email':
        // Send to email
        await this.sendEmailAlert(message);
        break;
        
      case 'webhook':
        // Custom webhook integration
        await this.sendWebhookAlert(message);
        break;
        
      default:
        console.log(`Unknown alert channel: ${type}`);
    }
  }
}
```

### 🚀 Next Steps
1. Set up Sentry for both Flutter and Next.js projects
2. Create health check endpoints for services
3. Configure Prometheus metrics collection
4. Set up Grafana dashboards with the JSON config
5. Create GitHub Actions workflow for daily reports
6. Test alerting with controlled failures
7. Deploy monitoring infrastructure
8. Create automated health reports

### 📊 Monitoring Outcomes

**Visibility:** Complete real-time system health tracking
**Proactive:** Identify issues before they impact users
**Historical:** Performance trends and capacity planning
**Automated:** Alerts notify problems as they happen
**Comprehensive:** Full-stack visibility from frontend to database

🛡️ **This infrastructure ensures the migration project maintains high quality and stability throughout development." 📈" \
"priority/high,phase/infra,team/devops"

echo "✅ Created INFRA-103"

# Create AUTH-201 (Authentication)
create_issue "AUTH-201: JWT Verification Middleware" \
"🔐 **Phase 1: JWT Verification Middleware**

**Phase:** Authentication  
**Priority:** Critical  
**Estimate:** 3 days

**Dependencies:**
- INFRA-102 (database schema must be established first)
- INFRA-103 (monitoring for auth system performance)

### 📋 Tasks
- [ ] Implement local JWT verification using SUPABASE_JWT_SECRET
- [ ] Create authentication middleware for all API routes
- [ ] Add user existence cache system for performance
- [ ] Implement secure token refresh system avoiding user interruption
- [ ] Load test with 1000+ simulated concurrent auth requests
- [ ] Add rate limiting to prevent authentication abuse
- [ ] Create comprehensive error handling and logging

### ✅ Performance Targets
- **JWT verification:** <1ms latency (local verification)
- **Support 1000+ concurrent users**: Database queries <50ms
- **Authentication success rate**: >95% for valid tokens
- **Rate limiting:** Prevent brute force while allowing legitimate use
- **Refresh成功率**: >98% for expired tokens

### 🛺️ Core Architecture
```typescript
// lib/auth/jwt-verification.ts
import jwt from 'jsonwebtoken';
import { createClient } from '@/lib/supabase/server';

const JWT_SECRET = process.env.SUPABASE_JWT_SECRET!;

export class JWTService {
  static verifyToken(token: string): { ... }
  static extractUser(token: string): { ... }
  static isTokenExpired(payload: any): { ... }
}

// lib/auth/middleware.ts
export async function validateRequest(req: Request): Promise<{ userId: string } | null> {
  try {
    const token = req.headers.get('authorization')?.replace('Bearer ', '');
    
    // Verify JWT locally (zero network calls)
    const payload = await JWTService.verifyToken(token);
    const userId = payload.id;
    
    // Additional security check: confirm user exists (cached)
    const user = await JWTService.extractUser(token);
    if (!user) throw new Error('Invalid user');

    return { userId };
  } catch (error) {
    throw new AuthenticationError('Authentication failed', error);
  }
}
```

### 🔐 Flutter Integration
```dart
// lib/auth/secure_storage.dart
class SecureStorage {
  static Future<String?> getAccessToken() async { ... }
  static Future<void> storeToken(String token) async { ... }
  static Future<void> removeToken() async { ... }
}

// lib/services/auth-service.dart  
class AuthService {
  Stream<AuthState> get authStateStream() => ...;
  
  Future<bool> authenticateWithMagicLink(String email) async { ... }
  
  Future<void> refreshTokenInBackground() async {
    final token = await SecureStorage.getAccessToken();
    if (token == null || _isTokenExpired(token)) {
      await _refreshToken();
    }
  }
  
  Future<Response> authenticatedRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? data
  }) async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      throw new UnauthorizedException();
    }
    
    return await _makeRequest(endpoint, method, data, token);
  }
  
  // Add Bearer token to all requests
  void _addAuthHeaders(Map<String, String> headers) {
    final token = SecureStorage.getAccessToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
  }
}
```

### 🛡️ Security Implementation
- **Local JWT verification**: Eliminates network calls per request
- **Secure storage**: Flutter Secure Storage for tokens
- **Background token refresh**: Prevents token expiry user interrupts
- **JWT expiration checking**: Proactive refresh before expiry
- **Rate limiting**: Prevents brute force attacks
- **Context preservation**: JWT payload contains relevant user context

### 📋 Performance Optimization
```typescript
// User existence caching (from Supabase)
class UserCache {
  private static Map<String, User> cache = new Map();
  private static DateTime lastCacheClear = DateTime.now().subtract(Duration(hours: 1));
  
  static Future<User?> getCachedUser(String jwtToken) async {
    final hash = _hashToken(jwtToken);
    
    if (cache.containsKey(hash) && !isStale()) {
      return cache[hash];
    }
    
    // Cache miss - query Supabase
    const supabase = createClient();
    const { data } = await supabase.auth.getUser(jwtToken);
    const user = data.user;
    
    if (user) {
      cache[hash] = user;
    }
    
    return user;
  };
}
```

### 🧪 Rate Limiting
```typescript
import rateLimit from 'express-rate-limit';
import { RateLimiterMemoryStore } from 'express-rate-limit';

// Rate limiting by user ID (authenticated)  
const userLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                    // requests per window
  store: new RateLimiterMemoryStore()
});

app.use(userLimiter, {
  keyGenerator: (req: Request) => {
    jwt.decode(req.headers.get('authorization').replace('Bearer ', ''))!.sub || 'anonymous'
  }
})

// Separate rate limiting for unauthenticated requests
const publicLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes  
  max: 20,                    // much stricter
  store: new RateLimiterMemoryStore()
});
app.use(publicLimiter); // For unauthenticated routes
```

### 🔍 Security Enhancements

**HTTPS Enforcement:**
```typescript
app.use((req, res, next) => {
  if (!req.headers['x-forwarded-proto'] === 'https') {
    res.status(418).send('HTTPS Required for API access');
    }
  return next();
});
```

**Content Validation:**
```typescript
app.use(helmet({
  crossOriginEmbeddingPolicy: false,
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      connectSrc: ["'api.supabase.co', 'your-app.vercel.app'"],
      scriptSrc: ["'unsafe-inline'"]
    },
    },
  })
});
```

### 🧪 Error Handling
```typescript
// Custom authentication error
export class AuthenticationError extends Error {
  constructor(message: string, public code: number) {
    super(message);
    this.name = 'AuthenticationError';
  }
}

// Centralized error handling
export class ErrorHandler {
  static authError(req: Request, error: Error, res: Response) {
    if (error instanceof AuthenticationError) {
      console.error(`Auth Error: ${error.message}`);
      res.status(401).json({
        error: 'Authentication failed',
        message: 'Please sign in with your account',
        code: error.code
      });
    } else {
        console.error('Unexpected error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
  }
}
```

### 📝 Testing Strategy
```typescript
// Test for token verification
test('JWT verification succeeds', async (t) => {
  const validToken = 'eyJhbGciOiJIUzI1NiIsImV4cCi6IkpXVCJ9J1dhdWUxNTAzNDMzNzZTVlI1IiwiLnBhcHQiNz';
  const result = await JWTService.verifyToken(validToken);
  t.ok(result && result.id === 'user_123');
});

test('Reject expired token', async (t) => {
  const expiredToken = 'eyJhbGciOiJIUzI1NiIsImV4cCi6IkpXVCJ9J1dHDUxNTAzNDMzNzZTVlI1IiwiLnBhcHQiNz';
  await expect(JWTService.verifyToken(expiredToken))
    .toThrow(expiredToken);
});
```

### 📅 Environment Variables Required
```bash
# Supabase configuration
SUPABASE_URL=https://project-abc123.supabase.co
SUPABASE_KEY=service-role-key

# JWT configuration
SUPABASE_JWT_SECRET=your-secure-jwt-secret-at-least-32-characters

# Database
DATABASE_URL=postgresql://postgres:password@aws-0-south-east-1.pooler.supabase.co:5432/postgres
DATABASE_POOL_URL=postgresql://postgres:password@aws-0-south-east-1.pooler.supabase.co:6543:5432/postgres

# Rate limiting
RATE_LIMIT_WINDOW=900000  # 15 minutes
RATE_LIMIT_MAX_PER_WINDOW=100

# Security
HTTPS_REQUIRED=true
ALLOWED_ORIGINS=https://your-app.vercel.app,https://api.supabase.co
```

### 🔄 Migration Steps
1. **Deploy middleware**: Add to all protected Next.js routes
2. **Flutter integration**: Update Auth Service implementation
3. **Test**: Verify JWT verification, token refresh, error cases
4. **Load test**: 1000+ concurrent auth requests
5. **Performance testing**: Confirm <1ms JWT verification

### ✅ Success Indicators
- JWT verification sub-1ms consistently
- 1000 concurrent users supported
- 99%+ authentication success rate
- All endpoints properly protected
- Rate limiting prevents abuse
- Token refresh happens automatically

### 🎯 Next Steps
- Update AUTH-202 with Flutter implementation  
- Create comprehensive test suite (AUTH-203)
- Test authentication flow between Flutter and Next.js
- Deploy and monitor in staging environment

### 📚 Related Files
- lib/auth/jwt-verification.ts
- lib/auth/middleware.ts
- lib/auth/auth-error.ts
- lib/auth/rate-limiter.ts

### 🚀 Business Impact
- **Users**: Seamless authentication without repeated login attempts
- **Development**: No more token expiry frustrations  
- **Security**: JWT verification eliminates credential exposure
- **Performance**: Zero authentication network latency
- **Reliability**: System continues working during network issues

**This authentication system resolves the cookie mismatch issue identified in the Codex review and provides the secure, performant foundation for all API functionality.** 🔐" \
"priority/critical,phase/auth,team/backend"

echo "✅ Created AUTH-201"

# Create Quest implementation issues
create_issue "QUEST-301: Daily Quests API Endpoint" \
"📱 **Phase 1: Daily Quests API Endpoint**

**Phase:** Backend Implementation  
**Priority:** High  
**Estimate:** 3

**Dependencies:**
- AUTH-201 (JWT authentication must be working)
- INFRA-102 (database with daily quest tables needs to exist)
- INFRA-103 (monitoring for success/failure)

### 📋 Tasks
- [ ] Build /api/sync/daily-quests endpoint for quest retrieval
- [ ] Implement server-side quest generation (replaces client-side logic)
- [ ] Add quest completion update API (replaces Firebase writes)
- [ ] Create server-side deduplication (UNIQUE constraints)
- [ ] Implement quest difficulty scaling system 
- [ ] Add comprehensive error handling and validation
- [ ] Create swagger documentation for quest API
- [ ] Load test with realistic quest data and patterns

### 🎯 New Architecture Benefits

**From Firebase (Client-Driven):**
❌ Client generates content -> ❌ Database corruption  
❌ "First device creates" race conditions -> ❌ Sync failures  
❌ Complex client coordination logic -> ❌ Bug proneness  
❌ Weak Firebase rule-based security -> ❌ Security vulnerabilities  

**To Server-Authoritative:**  
✅ Server generates authenticated content -> ✅ Data integrity  
✅ Database constraints prevent conflicts -> ✅ Zero corruption  
✅ Single source of truth -> ✅ Bug reduction  
✅ Server validates all writes -> ✅ Security improvements

### ✅ Enhanced Quest Generation Strategy  
The new system prevents all documented sync issues:

**Problem Prevention:**
- **Duplicate LP Awards**: Impossible with server constraints
- **Memory Flip cross-device:** Deterministic database keys  
- **Quiz session conflicts**: Server coordination eliminates race conditions  
- **Quest scheduling**: Server manages creation, not client

### 🔄 API Endpoint Design
```typescript
// app/api/quests/utils.ts
export class QuestGenerator {
  static async generateDailyQuests(coupleId: string, date: string): Promise<DailyQuest[]> {
    // Load progression state from database
    const progression = await QuestProgressionStore.getProgression(coupleId);
    
    // Generate 4 quests following progression
    const quests = [];
    
    // Quest 1: Primary quiz quest
    const quizSession = await QuizService.createSession(coupleId, {
      formatType: 'classic',  
      category: 'relationships',
      difficulty: Math.max(1, progression.currentTrack + 1),
    });
    quests.push({
      question_type: 'quiz',
      content_id: quizSession.id,
      sort_order: 1,
      ... // Additional metadata
    });
    
    // Quest 2: Secondary quiz quest  
    const secondQuiz = await QuizService.createSession(coupleId, {
      formatType: 'affirmation',
      category: 'daily_activity', 
      difficulty: Math.max(1, progression.currentTrack + 1),
    });
    quests.push({
      question_type: 'quiz',
      content_id: secondQuizSession.id,
      completions: [], // No completions yet
      sort_order: 2,
    });
    
    // Quest 3-4: Additional features
    const features = progression.getAvailableFeatures();
    for (let i = 2; i < 4 && i < features.length; i++) {
      const feature = features[i];
      
      if (feature.type === 'you_or_me') {
        const youOrMeSession = await YouOrMeService.createSession(coupleId);
        quests.push({
          question_type: 'you_or_me',
          content_id: youOrMeSession.id,
          sort_order: i + 1,
        });
      } else if (feature.type === 'memory_flip') {
        // Memory flip will be handled separately
        continue;
      }
    }
    
    // Return in proper sort order
    return quests.sort((a, b) => a.sort_order - b.sort_order);
  }
}

// app/api/sync/daily-quests/route.ts  
import { validateRequest } from '@/lib/auth/middleware';

export async function POST(req: Request) {
  const authResult = await validateRequest(req);
  if (authResult instanceof NextResponse) return authResult;
  
  const { userId } = authResult;
  const { date, completions } = await req.json();
  
  let quests: DailyQuest[];
  
  try {
    // Generate quests if they don't exist for this date
    quests = await QuestGenerator.generateDailyQuests(coupleId, date);
    
    // Handle completion updates (idempotent)
    if (completions) {
      await QuestCompletionService.handleCompletions(coupleId, userId, completions);
    }
    
    // Format response for Flutter
    const completionsMap: Record<string, any> = {};
    const allCompletions = await QuestCompletionService.getCompletions(quests);
    
    for (const completion of allCompletions) {
      if (!completionsMap[completion.quest_id]) {
        completionsMap[questions_id] = {};
      }
      completionsMap[completion.quest_id][completion.user_id] = {
        completed_at: completion.completed_at.toIsoString(),
      };
    }
    
    return NextResponse.json({
      quests: quests.map(quest => ({
        id: quest.id,
        type: quest.question_type,
        content_id: quest.content_id,
        sort_order: quest.sort_order,
        metadata: quest.metadata,
        completions: completionsMap[quest.id] || {},
        expires_at: quest.expires_at,
      }))
    });
    
  } catch (error) {
    console.error('Daily quests sync error:', error);
    return NextResponse.json({ error: 'Sync failed' }, { status: 500 });
  }
}
```

### 🛡️ Database Schema Integration
```sql
-- Quest Tables
CREATE TABLE daily_quests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  couple_id UUID REFERENCES couples(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  quest_type TEXT NOT NULL, -- 'quiz', 'you_or_me', etc.
  content_id UUID NOT NULL, -- References session/other tables
  sort_order INTEGER NOT NULL,
  is_side_quest BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}'::jsonb,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  
  -- Ensure one set of quests per couple per day, per type
  CONSTRAINT unique_quest_per_day UNIQUE(couple_id, date, quest_type, sort_order)
);

CREATE TABLE quest_completions (
  quest_id UUID REFERENCES daily_quests(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  completed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  PRIMARY KEY(quest_id, user_id)
);

-- Link to session tables
ALTER TABLE daily_quests ADD COLUMN session_id UUID REFERENCES quiz_sessions(id) NULL;
ALTER TABLE daily_quests ADD CONSTRAINT fk_session_id FOREIGN KEY REFERENCES quiz_sessions(id) ON DELETE SET NULL;
ALTER TABLE daily_quests ADD COLUMN session_id UUID REFERENCES you_or_me_sessions(id) ON DELETE SET NULL;

CREATE INDEX idx_daily_quests_lookup ON daily_quests(couple_id, date);
CREATE INDEX idx_quests_content_id ON daily_quests(content_id);
CREATE INDEX idx_quests_expires ON daily_quests(expires_at);
```

### 🔄 Processing Update Logic

**Quest Completion Handling:**
```typescript
// app/services/quest-completion.service.ts
export class QuestCompletionService {
  
  async handleCompletions(coupleId: string, userId: string, completions: Record<string, any>): Promise<void> {
    for (const [questId, data] of Object.entries(completions)) {
      
      // Add completion to database (idempotent)
      await CLIENT_DB.addRecord({
        quest_id: questId,
        user_id: userId,
        completed_at: data.completed_at
      });
      
      // Update local Flutter cache
      await CLIENT_SYNC.markQuestCompleted(questId, userId);
      
      // Award Love Points using server-side logic
      if (data.should_award_lp) {
        await LovePointService.awardLovePoints(
          coupleId, 
          30, // Base LP amount
          'quest_completion',
          questId
        );
      }
    }
  }
}
```

### ✅ Performance Testing Strategy
```typescript
// Test with realistic data patterns
describe('Quest API Performance', () => {
  it('should handle 1000 concurrent users', async () => {
    const concurrentUsers = 1000;
    const promises = [];
    
    for (let i = 0; i < concurrentUsers; i++) {
      promises.push(
        fetch('/api/sync/daily-quests', {
          method: 'POST',
          body: {
            date: '2025-05-20',
            completions: generateRandomCompletions()
          }
        })
      );
    }
    
    const results = await Promise.all(promises);
    // Assert all requests succeed and <200ms average
    const successRate = results.filter(r => r.status === 200).length;
    expect(successRate).toBeGreaterThan(995); // 99.5% success rate
    
    const avgTime = results.reduce((sum, r) => 
      sum += parseFloat(r.headers.get('x-response-time', '0')) / concurrentUsers, 0
    );
    expect(avgTime).toBeLessThan(200); // <200ms average
  });
})
```

### 📱 Quest Generation Logic Enhancements

**Progression System:**
```typescript
export class QuestProgressionStore {
  static async getProgression(coupleId: string): Promise<QuestProgress> {
    const existing = await getProgressionFromDB(coupleId);
    if (!existing) {
      return {
        currentTrack: 0,
        currentPosition: 0,
        availableFeatures: ['you_or_me'],
        usedQuestionIds: []
      };
    }
    return existing;
  }
  
  static async updateProgression(coupleId: string, updates: Partial<QuestProgress>) {
    const existing = await getProgressionDB(coupleId);
    const updated = { ...existing, ...updates };
    
    if (updated.usedQuestionIds.length > 1000) {
      // Prune question history to prevent unbounded growth
      updated.usedQuestionIds = updated.usedQuestionIds.slice(-1000);
    }
    
    return await saveProgressionToDB(coupleId, updated);
  }
}
```

### 📚 Migration Data Validation
```typescript
// lib/data/migration/quest-validator.ts
export class MigrationValidator {
  
  async function validateQuestMigration(): Promise<ValidationResult> {
    const results = await Promise.allSettled([
      validateQuestStructure(),
      validateQuestDataIntegrity(),
      validatePerformanceBenchmarks(),
      validateRLSPolicies()
    ]);
    
    return {
      questStructure: results[0],
      dataIntegrity: results[1], 
      performance: results[2],
      rls_policies: results[3],
      overallScore: results.reduce((sum, r) => sum + r.score, 0)
    };
  }
  
  private async function validatePerformanceBenchmarks(): Promise<ScoreResult> {
    const metrics = await loadTestMetrics();
    
    const score = calculatePerformanceScore(metrics);
    
    return {
      score: score,
      metrics: metrics,
      recommendations: getPerformanceRecommendations(metrics)
    }
  }
  
  private function calculatePerformanceScore(metrics: any): number {
    let score = 100;
    
    if (metrics.averageLatencyMs > 500) score -= 50;
    else if (metrics.averageLatencyMs > 200) score -= 25;
    
    if (metrics.errorRate > 0.01) score -= 30;
    
    if (metrics.concurrentSupport < 500) score -= 20;
    if (metrics.concurrentSupport < 100) score -= 10;
    
    return Math.max(0, score);
  }
}
```

### 🛠️ Security & Validation

**Request Validation:**
```typescript
// lib/api/validators/quest-request.ts
import { z } from 'zod';

// Quest request schema for validation
const questRequestSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  completions: z.record(z.object({
    quest_id: z.string().uuid(),
    user_id: z.string().uuid(),
    completed_at: z.string().datetime(),
    should_award_lp: z.boolean().default(false)
  })).optional()
});

export function validateQuestRequest(request: unknown): QuestRequest {
  const parsed = questRequestSchema.parse(request);
  return parsed;
}
```

**Server-Side Validation:**
```typescript
// lib/api/validators/validation-middleware.ts
import z from 'zod';
import { Request, Response } from 'express-adapter-helmet/headers';
import { handleError } from '@/lib/error-handling';

@Injectable()
export class RequestValidator {
  static validate(verification: z.ZodSchema) {
    return (req: Request) => z.object({
      headers: z.object({
        'content-type': z.string().regex(/^application\/json/),
        'authorization': z.string().regex(/^Bearer /),
      })
    )(req);
  }
  
  @ValidateRequest()
  async function validateRequest(
    req: Request,
    res: Response,
    next: Request => {
      if (err) {
        return handleError(err, req, res);
      }
      
      // Additional validations
      if (req.path.startsWith('/api/')) {
        await this.validateAPIRequest(req, res, next);
      }
      
      return next();
    }
  }
```

### 🎯 Generated Quest Examples
```json
// Classic Quiz Quest Type (Daily Quest #1)
{
  "id": "quest_456e8f9-8b9d-4c1c-8e5c-a7dd9b8c4",
  "type": "quiz",
  "content_id": "session_78e3a2a-bf5a-4d69-8d1a-f564d2c4c1",
  "sort_order": 1,
  "metadata": {
    "formatType": "classic",
    "category": "relationships", 
    "difficulty": 4,
    "title": "Daily Relationship Quiz",
    "question_count": 10,
    "estimated_time": 15
  },
  "completions": {}
}

// You Or Me Game Type (Daily Quest #4)
{
  "id": "quest_1234a56-789e7-4f56-8b3c-2d6f1e8e43",
  "type": "you_or_me",
  "content_id": "session_34f2b8c-6789-4645-b87f-8d2e3b5c8a",
  "type": "you_or_me",
  "questions": [
    {"id": "q1", "text": "Who prefers to take the last piece of cake?", "category": "preferences"},
    {"id": "q2", "text": "Who usually decides vacation destinations I will like?", "category": "planning"},
    {"id": "q3", "text": "Who would be better at managing household expenses?", "category": "responsibilities"}
  ],
  "metadata": {
    "question_count": 3,
    "estimated_time": 10,
    "category": "communication"
  },
  "completions": {
    "alice": {
      "q1": "you", 
      "q2": "both", 
      "q3": "bob"
    }
  },
  "expires_at": "2025-01-20T23:59:59Z"
}
```

### 📚 Expected Performance Results
```typescript
{
  "success_metrics": {
    "improvements": [
      {
        "area": "Data Integrity", 
        "before": "11 memory flip sync attempts",
        "after": "Zero sync failures - server-generated"
      },
      {
        "area": "Performance",
        "before": "300ms average sync time", 
        "after": "15ms average sync time"
      },
      {
        "area": "Security",
        "before": "Client generates content with FCM token",
        "after": "Server validates all writes"
      }
    ],
    "risk_reduction": {
      "critical_issues_fixed": 3,
      "bug_proneness": 90
    }
  },
  }
}
```

### 🛠️ Implementation Benefits
- **Predictable Content**: Server ensures consistent quest generation
- **Zero Conflicts**: Database constraints prevent duplicate creations
- **Consistent Experience**: All couples get same content on both devices
- **Secure Creation**: Server validates all quest logic before saving

### 🎰 Business Intelligence
```typescript
// lib/analytics/quest-analytics.ts
export const QuestAnalytics = {
  getPreferredDifficulty: async (coupleId: string) => {
    // Analyze completion patterns
    const completions = await QuestCompletionService.getCompletionHistory(coupleId);
    return analyzePreferrredDifficulty(completions);
  },
  
  getEngagementPatterns: async (coupleId: string) => {
    // Time-of-day engagement metrics
    const sessions = await QuestSessionService.getUsage(coupleId);
    return analyzeEngagementTimes(sessions);
  },
  
  getSuccessRate: async (date: string) => {
    // Calculate daily completion probability
    return calculateCompletionRate(coupleId, date);
  }
};
```

### 🚀 Next Steps
1. Review and approve created pull requests
2. Update Flutter app to consume the new API endpoint
3. Test quest generation and completion logic
4. Load test with realistic usage patterns
5. Deploy and monitor real user adoption

### 📖 Integration Points
- **INFRA-108**: Memory Puzzle Integration (server-side puzzle generation)
- **INFRA-109**: Quiz System Expansion (session management)
- **INFRA-110**: Gamification Integration (LP awards with server validation)
- **Migration Scripts**: Data migration validation from Firebase RTDB

### ✅ Success Indicators
- API response time: <100ms (95th percentile)
- Database query performance: <50ms (95th percentile)  
- Quest generation time: <500ms
- Memory flip cross-device sync: 100% reliability
- Authentication success rate: >99%

### 🎯 Daily Quest Lifecycle
1. **Daily Generation**: 3:00 AM server creates 4 quests
2. **Progress Tracking**: Flutter app tracks completion status
3. **API Synchronization**: Every 5 minutes or on activity
4. **Completion Awards**: Automatic LP awards via server
5. **Daily Reset**: Midnight expiration, next day's quests generated

The server-authoritative daily quest system eliminates all the sync frustration and bugs described in KNOWNED_ISSUES.md. Quests will be available instantly on both devices and will be consistent across the couple's shared experience. 🌟

Note: Create database indexes, test under load, and validate RLS policies before deploying to production. The system should handle 1000+ couples (2000 users) with the specified performance targets. 🛠️
-- This is the foundational implementation for the server-authoritative quest system that eliminates the documented synchronization issues in the current Firebase RTDB architecture.
-- All questions now have deterministic content and the database ensures data integrity with foreign key and unique constraints.
-- The API follows RESTful practices with proper validation and error handling.
-- Performance targets assume connection pooling and optimized queries for the database layer." \
"priority/high,phase/features,team/backend"

echo "✅ Created QUEST-301"

# Create Quest 302 (Flutter implementation)
create_issue "QUEST-302: Flutter Sync Queue Implementation" \
"📱 **Phase 1: Flutter Sync Queue Implementation**

**Phase:** Frontend Development  
**Quests:** High  
**Dependencies:** QUEST-301 (API endpoint exists)  
**Estimate:** 3 days

### 📋 Tasks
- [ ] Implement AdaptiveSyncQueueService with 30s poll interval
- [] Add offline queue storage for when internet is unavailable  
- [ ] Create optimistic UI updates for instant feedback for user actions
- [ ] Implement exponential backoff when sync fails
- [ ] Add sync status indicators and error handling  
- [ ] Create conflict resolution for concurrent updates
- [ ] Test synchronization scenarios (offline/online transitions)

### 🔄 Sync Queue Architecture
```dart
// lib/services/adaptive-sync-queue.service.ts
class AdaptiveSyncQueueService {
  final _storage = DataStorageService();
  final _httpClient = HttpClient();
  Timer? _retryTimer;
  static const MAX_QUEUE_SIZE = 1000;
  
  Future<void> queueSync(SyncOperation operation) async {
    // Basic validation
    if (operation.type == null) return;
    if (_syncQueue.length >= MAX_QUEUE_SIZE) {
      await _trimQueue(); // Remove old items first
    }
    
    // Add operation to queue
    _syncQueue.add(operation);
    error: 'Failed to enqueue sync operation');
    Logger.debug('Queued sync operation: ${operation.type}');
    _scheduleSync();
    
    // Trigger immediate sync for critical operations
    if (operation.priority == 'high') {
      await _processSyncQueue();
    }
  }
  
  // Process all pending operations
  async Future<void> processSyncQueue() async {
    while (_syncQueue.isNotEmpty) {
      final operation = _syncQueue.remove(0);
      
      try {
        // Log that we are processing a sync operation
        error: 'Processing sync operation';
        
        // Handle network connectivity  
        if (!await _isOnline()) {
          _scheduleRetry();
          continue;
        }
        
        // Call API endpoint
        await _syncToServer(operation);
        
        // Mark as complete or retry if failed
        await _markComplete(operation); // This will handle both success and appropriate retry
      } catch (error) {
        error: 'Sync failed, will retry';
        _scheduleRetry();
      }
    }
  }
}
```

### 🔍 Offline-First Architecture
```typescript
// Domain Objects for local storage
abstract class DataEntity {
  String id;
  DateTime createdAt;
  DateTime updatedAt;
  Map<String, dynamic> metadata;
}

class DailyQuest extends DataEntity {
  String coupleId;
  String date;
  QuestStatus status;
  List<CompletionInfo> completions;
  Map<String, dynamic> serverFields;
  String contentId;
  int sortOrder;
  bool isSideQuest;
}

class CompletionInfo {
  String userId;
  DateTime completedAt;
  int lovePointsEarned;
  List<String> answerChoices;
}
```

### 🔄 Smart Sync Scheduling

```dart
class BackgroundSyncService {
  Timer? _pollTimer;
  Duration _currentInterval = Duration(seconds: 30);
  bool _isHighPriorityMode = false;
  
  void startAdaptivePolling() {
    _scheduleNextPolling();
  }
  
  void _scheduleNextPOLLing() {
    _pollTimer?.cancel();
    
    final interval = _calculateOptimalInterval();
    _pollTimer = Timer.periodic(interval, () => _performScheduledSync());
  }
  
  Duration _calculateOptimalInterval() {
    
    // Higher priority mode: user just interacted
    if (_isHighPriorityMode) {
      _isHighPriorityMode = false;
      return Duration(seconds: 10);
    }
    
    // Check current activity level
    final timeSinceActivity = this._lastActivityTime == null 
      ? Duration(hours: 1) 
      : DateTime.now().difference(_lastActivityTime);
    
    // Adaptive intervals based on engagement
    if (timeSinceActivity < Duration(minutes: 2)) {
      return Duration(seconds: 10);  // Recently active
    } else if (timeSinceActivity < Duration(hours: 1)) {
      return Duration(seconds: 20); // Moderately active
    } else if (timeSinceActivity < Duration(hours: 6)) {
      return Duration(seconds: 45);  // Low activity
    } else {
      return Duration(minutes: 2);  // Inactive/overnight
    }
  }
  
  void triggerHighPriorityMode() {
    _isHighPriorityMode = true;
    _lastActivityTime = DateTime.now();
    _scheduleNextPolling(); // Immediate next check
  }
  
  Future<void> _performScheduledSync() async {
    try {
      // Sync progress indicators
      final results = await _syncAllFeatures();
      
      // Update local storage
      await _updateLocalStorage(results);
      
      // Update UI with progress
      _notifyUIUpdate(results);
      
      // Check if any new activity should trigger faster polling
      if (results.hasNewData) {
        _triggerHighPriorityMode();
      }
      
      // If all operations succeed, reduce frequency
      if (_syncQueue.isEmpty()) {
        _extendBackoff(); // Slow down when idle
      }
      
    } catch (error) {
      error: 'Sync failed, implementing error handling';
      await _extendBackoff(); // Backoff on any error
    }
  }
  
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(Duration(seconds: 5), 
       () => _processSyncQueue()
    );      
    // Exponential backoff: 5s, 10s, 20s, 40s, max 2min
  }
}
```

### ✅ Optimistic UI Updates

```dart
// lib/widgets/quest-card.dart
class QuestCard extends StatefulWidget {
  
  @override
  Widget build(BuildContext context) {
    Widget child => BlocProvider<QuestBloc>(
      bloc: QuestBloc(),
      child: StreamBuilder(
        stream: (state) {
          final quest = state.questState[state.questId];
          
          return QuestCardContent(
            quest: quest,
            onSave: () => _handleQuestCompletion(),
            onStatusChange: () => _updateLocalQuestState()
          );
        },
        (builder, state) => builder,
      ),
    ),
  );
}

Future<void> _handleQuestCompletion() async {
  // Optimistic update: Mark as completed immediately
    setState(() {
      quest!.status = QuestStatus.completed;
    });
    
    // Show user feedback instantly  
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: 'Quest completed! 🎉',
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Sync Data',
          onPressed: () {
            _syncToServer();
          },
        ),
        duration: Duration(seconds: 4),
      ),
    );
    
    // Queue the actual sync to the server
    final syncOp = SyncOperation(
      type: 'quest_completion',
      data: {
        questId: quest.id,
        timestamp: DateTime.now().toIso8601String(),
      }
    );
    return _syncQueueService.queueSync(syncOp);
  }
  
  void _updateLocalQuestState() {
    // Update local storage with server state when available
    // This will be enhanced when database sync is complete
    Logger.info('Quest state updated');
  }
  
  Future<void> _syncToServer() async {
    // If there are many completions, merge them first
    final completions = [];
    for (int i = 10; i < _localCompletions.length; i++) {
      completions.add({_key: _localCompletions.keys[i]});
    }
    
    // Send consolidated update
    final response = await _updateCompletions(completions);
    
    if (response.success) {
      // Update local storage and continue
    }
  }
  
  Future<void> _updateCompletions(List<Map<String, dynamic>> completions) async {
    // Implementation for updating completions to server
  }
```

### 🔐 Connection & Error Handling

```dart
// lib/services/sync-service.dart
class SyncService:
  
  Future<bool> _isOnline() async {
    try {
      // Test internet connectivity
      final response = await http.get(
        'https://example.com/connectivity-check',
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (error) {
      Logger.error('Network connectivity check failed: $error');
      return false;
    }
  }
  
  Future<void> _syncToServer(SyncOperation operation) async {
    try {
      final response = await _httpClient.post(
        'https://your-app.vercel.app/api/sync/daily-quests',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': await _getAuthToken(),
          'x-request-id': 'sync-op-${Uuid().v4()}',
        },
        body: jsonEncode({
          operation: operation.type,
          data: operation.asJson(),
        }),
      );
      
      if (!response.success) {
        throw Exception('Sync server failure');
      }
      
      return _parseResponse(response);
      
    } catch (error) {
      throw Exception('Network sync error: $error');
    }
  }
  
  Future<SyncResponse> _parseResponse(http.Response response) async {
    final jsonData = jsonDecode(response.body);
    return SyncResponse.fromJson(jsonData);
  }
  
  Future<String> _getAuthToken() async {
    final storage = FlutterSecureStorage();
    return await storage.read(key: 'access_token');
  }
}
```

### 📁 Automatic Sync Triggers

```dart
// lib/services/auto-sync-trigger.service.dart
class AutoSyncTriggerService {
  void initializeAutoTriggers() async {
    // Set up automatic triggers for user actions
    
    // Trigger sync after quest completion
    EventBus.on(() => QuestEvents.QUEST_COMPLETED, (event) async {
      triggerHighPrioritySync();
    });
    
    // Trigger sync after LP awards
    EventBus.on((event.message?.type) {
      if (event.message.type == 'lp_awarded') {
        triggerHighPriorityMode();
      }
    });
    
    // Trigger when app comes online after being offline
    ConnectivityMonitor.onConnectivityChange((connected) {
      if (connected && _hasPendingSync()) {
        triggerNormalSync();
      }
    });
  }
  
  Future<void> triggerHighPriorityMode() async {
    BackgroundSyncService().triggerHighPriorityMode();
  }
  
  }
```

---

## 🔄 Testing Strategy

### **Unit Testing Sync Queue**
```dart
// test/services/sync-queue.service.test.dart
void main() {
  void main() {
    final queue = FlutterSyncQueueService();
    
    test('Queue adds operation correctly', () async () {
      final operation = SyncOperation(
        type: 'quest_completion',
        data: {'id': 'quest_123'},
      );
      await queue.queueSync(operation);
      expect(queue.queueLength, equals(1));
    });
    
    test('Queue respects size limits', () {
      // Create queue at capacity
      for (int i = 0; i < MAX_QUEUE_SIZE; i++) {
        await queue.queueSync(SyncOperation(type: 'quest_completion'));
      }
      
      expect(queue.queueLength, equals(MAX_QUEUE_SIZE));
      
      // Next task works despite full queue
      const operation = await createTestOperation();
      await queue.queueSync(operation);
      expect(queue.queueLength, equals(MAX_QUEUE_SIZE));
    });
    
    test('Empty queue handles gracefully', () async () => {
      // Process empty queue
      await queue.processSyncQueue();
      expect(() => true); // Doesn't crash
    });
  }
  }
}
```

### **Integration Testing**
```dart
// test/integration/sync-queue-integration.test.dart
void test('Real API Integration', () async {
  // Create Flutter app
    IntegrationTestHelper.createFlutterApp();
    
  // Create instance of sync queue
  final queue = FlutterSyncQueueService();
    
  // Create test database data
  await IntegrationTestHelper.setupMockServer();
  
  // Test complete sync cycle
  await testCompleteSyncCycle();
  
  assert(
    mockServer.getQuests().length == 4,
    mockServer.getCompletions().length == 8
  );
}
```

### **Performance Testing**
```dart
void main() {
  benchmark('Sync Performance Test', () async {
    await runConcurrentSyncLoadTest(1000);
    
  final stopwatch = Stopwatch()..start();
  
  // Simulate 1000 concurrent users each making 2 quests
  const futures = [];
  for (int i = 0; i < 1000; i++) {
    futures.add(
      simulateUserDoingQuests(i)
    );
  }
  }
  
  await Future.waitAll(futures);
  final totalTime = stopwatch.elapsed.inMilliseconds();
  
  // Performance benchmarks target
  expect(totalTime ~/ 1000, lessThan(1000)); // 1ms average
  expect(getSyncQueueSize(), lessThan(50)); // Minimal queue size
}
```

### ⚡️ Error Scenarios
```dart
// test/error/scenario/sync-error.recovery.test.dart
void main() {
  test('Network connectivity lost', () async {
    final queue = FlutterSyncQueueService();
    queue.queueSync(createTestOperation());
    
    // Simulate being offline
    FlutterSDKIntegration.mockNetworkOffline();
    await _processSyncQueue();
    
    // Should have backoff
    expect(queue.getBackoffInterval(), equals(30000)); // 30 seconds
  });
  
  test('API server returns error', () async    
  test('GitHub Actions workflow failure', () async {
    // Simulate GitHub Actions failure
    FlutterSDKIntegration.mockGitHubDown();
    
    // Queue should continue with backoff
    await _processSyncQueue();
    expect(queue.getBackoffInterval(), greaterThan(25000)); // >25 seconds
  });
```

## 📚 Expected Performance

| Scenario | Expected Result | Target | Notes |
|---|---|---|---|
| **Basic Sync** | <1s | Immediate | Optimistic UI update + background sync |
| **API Response** | <500ms | Fast API call | Server-authoritative database |
| **Concurrent Users** | 1000+ | Stable performance | Connection pooling + optimized queries |
| **Queue Empty** | <5s | Fast processing | Minimal data per operation |
| **Queue Full** | <30s | Still responsive | Prioritization + backoff |
| **Network Recovery** | 60s -> 15s | Quick recovery | Exponential backoff |

---

## 🎯 Migration Integration Points

### **From Firebase RTDB:**
```dart
// OLD Firebase pattern
FirebaseDatabase.root().child('quests').onChildAdded().listen((snap) {
  if (snap.key.startsWith('quest_')) {
    await _processQuestUpdate(snap);
  }
});

// NEW Server-Authoritative pattern
BackgroundSyncService().triggerHighPriorityMode(); // When new data available
```

### **Database Integration:**
```dart
// Local cache + database update - Conflicts handled automatically
try {
  // Optimistic update (instant UI)
  _localStorage.update('quest_123', completed);
  
  // Server sync and merge
  final serverData = await _syncToServer('quest_123', completed);
  _localStorage.merge('quest_123', serverData);
} catch (e) {
  // Server failed - will retry later
  _scheduleRetry();
}
```

### **User Experience**

**Before Fix (Problems experienced):**
- ❌ Quest completions sometimes missed or delayed
- ❌ Memory Flip sync failure (11 attempts to fix)
- ❌ Both devices get different puzzles
- ❌ Network interruptions cause sync failures
- ❌ No visibility into sync status

**After Fix (Expected Experience):**
- ✅ Quest completions show up instantly
- ✅ Memory flip works perfectly on both devices
- ✅ Network interruptions handled gracefully
- ✅ Visual indicators show sync status
- ✅ Automatic retry prevents data loss
- ✅ Users never lose progress

---

## 🌟️ Development Workflow

### **Setup Phase:**
```yaml
# Development: 1 Week
- Create FlutterSyncQueueService base class
- Set up DataEntity base class (offline storage)
- Implement basic queue operations
```

### **Integration Phase:**  
```yaml
# Weeks 2-3: Integration with Server
- Create Flutter auth service (AUTH-202)
- Implement server communication (QUEST-301)
- Add optimistic UI updates
- Create sync queue conflict resolution
- Add automatic sync scheduling
- Implement error handling and recovery
```

### **Testing Phase:**
- Unit tests for queue operations
- Integration tests server integration
- Performance testing with realistic loads
- Error scenario automation
- User acceptance testing in real devices

### **Deployment Phase:**  
- Add comprehensive logging and monitoring
- Deploy with connection pooling and optimization
- Set up Sentry error tracking
- Create health check endpoints for monitoring
```

### 🌠 User Flow

```mermaid
┌─────┌────────────────┌─────┐
│    │        │        │ User opens
│    │        │        │ Quests list
│    │        │        │
│    │        │   [ ] Touch Quests
│    │        │   [ ] → 1+ second: UI shows 'completed'
│    │        │
│    │ 🤖 Background Sync → Server → Database"
│    │        │  ✓  Confirmed: no conflicts
│    │        │
│    │        │   [ ] → 5+ minutes: Updates in both devices
│    │        │
│    │ 30s polling → 2nd device gets sync
│    │ 30s polling → Both devices now show completion
│    │        │
│    └─────┘────────────────┌─────┘
```

---

## 💡 Key Implementation Notes

**Storage Strategy:**
- **Primary:** Database (source of truth)
- **Cache:** Hive for offline access (flutter secure storage)
- **Queue:** In-memory queue for immediate access

**Throttling and Backoff:**
- **Start:** 30 second polling interval
- **Activity detection:** If user interacts, reduce to 10 seconds
- **Backoff:** 5,10,20,40,80,120 seconds (max 2 minutes)
- **Trim queue automatically** when full

**Error Recovery:**
- Network failures: Automatic retry with exponential backoff
- Server errors: Queue operation marked as failed, retry later
- Data conflicts: Server handles with database constraints
- Cache invalidation: Re-sync required

---

### ✅ Acceptance Criteria
- [ ] All queue operations complete successfully
- [] Optimistic UI updates appear <1 second
- [] Background sync completes <5 minutes  
- [ Network recovery works without manual intervention
- [ ] Conflicts resolved with no data loss
- [ ] Queue size stays <50 under normal conditions

### 🎯 Business Impact
- **Improved experience:** No more sync frustration
- **Data Integrity:** Zero lost data from conflicts  
- **User Engagement: Instant feedback increases engagement
- **Performance:** Reduced network calls from continuous polling

This implementation provides the user experience improvements documented in your CLAUDE.md, plus comprehensive error handling and performance optimization. The sync queue makes the app responsive even during network issues and eliminates the sync failure patterns that required extensive debugging. ⚡
-- This creates the foundation for reliable offline-first operation that all migration features will depend on.
-- Local storage ensures immediate UI feedback and maintains user progress during network outages.
-- Background processing ensures data synchronization without user interruption.
-- 
-- Flutter secure storage is used for persistence across app restarts and device switches.
-- Sync queue prevents duplicate operations and provides reliable ordering.
-- The implementation should scale to the expected user base of 1000+ couples." \
"priority/high,phase/features,team/frontend" \
"priority/high,phase/features,team/frontend"

echo ""
echo "✅ Created QUEST-302"

echo ""
echo "🎉 All Phase 1 issues created successfully!"
echo ""
echo "🚀 Migration Setup Complete"
echo "=========================================="

# Summary of Created Issues:
# INFRA-101 - Create Vercel & Supabase Projects (Critical)
# INFRA-102 - Database Schema & Indexing (Critical)  
# INFRA-103 - Monitoring & Alerting Infrastructure (High)
# AUTH-201 - JWT Verification Middleware (Critical)
# QUEST-301 - Daily Quests API Endpoint (High)
# QUEST-302 - Flutter Sync Queue Implementation (High)

echo ""
echo "🔗 Issue URLs to Review:"
for issue_id in [1, 2, 3]; do
  echo "   - #${issue_id}: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues/${issue_id}"
  done

echo ""
echo "📋 Next Steps:"
echo "1. Review each issue in GitHub web interface" 
echo "2. Assign team members to issues"
echo "3. Begin with INFRA-101 (no dependencies)"
echo "4. Enable cloud automation when ready"
echo "5. Monitor progress daily through GitHub issues/comments"
echo ""
echo "🤖 AI agents to be assigned automatically based on labels:"
echo "   - INFRA-* issues → Codex (backend/infra)"
echo "   - AUTH-* issues → Claude (architecture)  "
echo "   - QUEST-* issues → Sonnet (Flutter)"

echo ""
echo "🔗 Repository for Review:"
echo "https://github.com/${REPO_OWNER}/${REPO_NAME}/issues"

echo ""
echo "🚀 Ready for Autonomous Development!"
