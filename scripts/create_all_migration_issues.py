#!/usr/bin/env python3
"""
Create all migration issues for Phases 2-6 in GitHub
Based on docs/GITHUB_PROJECTS_SETUP.md
"""

import os
import subprocess
import json
from typing import List, Dict

# Phase 1 already exists (issues #2-7)
# Creating Phase 2-6

ISSUES = [
    # ========================================================================
    # PHASE 2: DUAL-WRITE VALIDATION (Weeks 4-5)
    # ========================================================================
    {
        "title": "[DUAL-401] Dual-Write Sync Implementation",
        "body": """## 🔄 Dual-Write Implementation

**Phase:** 2 - Dual-Write Validation  
**Team:** Backend  
**Priority:** Critical  
**Estimate:** 4 days  
**Dependencies:** Issue #7 (AUTH-203)

---

## Description

Implement dual-write system that writes to both Firebase RTDB and PostgreSQL simultaneously. This allows gradual migration while maintaining data consistency.

## Acceptance Criteria

- [ ] Implement dual-write to RTDB + PostgreSQL for all operations
- [ ] Create data comparison service
- [ ] Build drift detection algorithms
- [ ] Add dual-write rollback mechanisms
- [ ] Implement comprehensive logging for both systems
- [ ] Create monitoring dashboard for dual-write status

## Technical Details

### Implementation Pattern
```typescript
async function saveQuestCompletion(data) {
  // Write to both systems
  const [rtdbResult, pgResult] = await Promise.all([
    writeToFirebase(data),
    writeToPostgres(data)
  ]);
  
  // Compare results
  if (!isConsistent(rtdbResult, pgResult)) {
    logDrift('quest_completion', data.id);
  }
  
  return pgResult; // PostgreSQL is source of truth
}
```

## Definition of Done

- [ ] All data operations write to both systems
- [ ] Drift detection running in production
- [ ] Monitoring dashboard accessible
- [ ] Documentation updated
- [ ] Load testing passed

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md` (Dual-Write section)
""",
        "labels": ["priority/critical", "team/backend", "phase/dual-write"]
    },
    
    {
        "title": "[DUAL-402] Data Validation Dashboard",
        "body": """## 📊 Data Validation Dashboard

**Phase:** 2 - Dual-Write Validation  
**Team:** DevOps  
**Priority:** High  
**Estimate:** 2 days  
**Dependencies:** Issue #8 (DUAL-401)

---

## Description

Create real-time dashboard to monitor data consistency between Firebase RTDB and PostgreSQL during dual-write phase.

## Acceptance Criteria

- [ ] Create data consistency checker service
- [ ] Build validation monitoring dashboard
- [ ] Add automated consistency alerts
- [ ] Set up data reconciliation tools
- [ ] Create drift report generation
- [ ] Document reconciliation procedures

## Technical Details

### Metrics to Track
- Read/write success rates for both systems
- Data drift incidents per hour
- Consistency percentage (target: 99.99%)
- Dual-write latency (P50, P95, P99)
- Reconciliation queue size

### Dashboard Features
- Real-time consistency percentage
- Drift alerts with details
- Historical consistency graphs
- Manual reconciliation tools

## Definition of Done

- [ ] Dashboard deployed and accessible
- [ ] Alerts configured and tested
- [ ] Team trained on dashboard usage
- [ ] Reconciliation procedures documented

---

**Related Documentation:** `docs/GITHUB_PROJECTS_SETUP.md`
""",
        "labels": ["priority/high", "team/devops", "phase/dual-write"]
    },
    
    {
        "title": "[DUAL-403] Load Testing Environment",
        "body": """## 🧪 Load Testing Setup

**Phase:** 2 - Dual-Write Validation  
**Team:** QA  
**Priority:** High  
**Estimate:** 3 days  
**Dependencies:** Issue #8 (DUAL-401)

---

## Description

Set up comprehensive load testing environment to validate dual-write system performs under production-like conditions.

## Acceptance Criteria

- [ ] Set up 1K+ simulated couples with realistic data
- [ ] Create realistic usage patterns (morning/evening peaks)
- [ ] Test dual-write under concurrent load
- [ ] Validate data integrity under stress
- [ ] Document performance baselines
- [ ] Create repeatable load test suite

## Technical Details

### Load Test Scenarios
1. **Daily Quest Generation** - 1K couples, 4 quests each = 4K writes/day
2. **Quest Completion** - 80% completion rate = 3.2K completions/day
3. **Concurrent Users** - Simulate 100 concurrent active users
4. **Peak Load** - 20x normal load for 15 minutes

### Tools
- k6 for load generation
- PostgreSQL pg_stat_statements for query analysis
- Firebase console for RTDB metrics

## Definition of Done

- [ ] Load test environment configured
- [ ] All scenarios tested and passing
- [ ] Performance baselines documented
- [ ] Load test automation in CI/CD

---

**Related Documentation:** `docs/CODEX_ITERATION_2_SOLUTIONS.md`
""",
        "labels": ["priority/high", "team/qa", "phase/dual-write"]
    },
    
    {
        "title": "[VAL-501] 7-Day Consistency Validation Run",
        "body": """## ⏱️ Week-Long Consistency Test

**Phase:** 2 - Dual-Write Validation  
**Team:** QA  
**Priority:** Critical  
**Estimate:** 7 days (continuous)  
**Dependencies:** Issue #10 (DUAL-403)

---

## Description

Run 7-day continuous dual-write test with production-like load to validate zero data loss and consistency.

## Acceptance Criteria

- [ ] Run 7-day continuous dual-write test
- [ ] Monitor data drift in real-time
- [ ] Validate zero data loss threshold (99.99%+)
- [ ] Test failure scenarios and recovery
- [ ] Produce comprehensive consistency validation report

## Technical Details

### Success Criteria
- **Data Consistency:** ≥99.99% (max 10 drift incidents/1M operations)
- **Zero Data Loss:** No unrecoverable data loss events
- **Reconciliation Time:** <5 minutes for any drift
- **System Uptime:** ≥99.9% for both systems

### Monitoring Checklist
- [ ] Daily consistency reports
- [ ] Automated drift alerts reviewed
- [ ] Manual spot checks (3x daily)
- [ ] Performance metrics tracked
- [ ] Incident log maintained

## Definition of Done

- [ ] 7 days completed with metrics above thresholds
- [ ] Final validation report published
- [ ] Go/no-go decision for next phase
- [ ] Stakeholder approval obtained

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/critical", "team/qa", "phase/dual-write"]
    },
    
    {
        "title": "[VAL-502] Performance Comparison Analysis",
        "body": """## 📈 Performance Benchmarking

**Phase:** 2 - Dual-Write Validation  
**Team:** QA  
**Priority:** High  
**Estimate:** 2 days  
**Dependencies:** Issue #11 (VAL-501)

---

## Description

Comprehensive performance comparison between original Firebase-only architecture and new dual-write system.

## Acceptance Criteria

- [ ] Benchmark adaptive vs fixed polling
- [ ] Measure battery impact on real devices (iOS/Android)
- [ ] Document 40%+ load reduction proof
- [ ] Validate API latency targets (<200ms p95)
- [ ] Create performance comparison report
- [ ] Verify 39% sync request reduction

## Technical Details

### Metrics to Measure

**Original (Firebase Only):**
- Polling frequency: Fixed 30s
- Daily requests per user: ~2,880
- Battery drain: Baseline
- Data usage: ~230KB/user/day

**New (PostgreSQL + Adaptive):**
- Polling frequency: Adaptive 10s-5min
- Daily requests per user: ~1,750 (39% reduction)
- Battery drain: 35% improvement
- Data usage: ~140KB/user/day

### Test Devices
- iPhone 14 Pro (iOS 17)
- Samsung Galaxy S23 (Android 14)
- 24-hour battery drain test

## Definition of Done

- [ ] All metrics collected and validated
- [ ] Performance gains confirmed
- [ ] Report published with graphs
- [ ] Stakeholder approval

---

**Related Documentation:** `docs/CODEX_ITERATION_2_SOLUTIONS.md`
""",
        "labels": ["priority/high", "team/qa", "phase/dual-write"]
    },
    
    {
        "title": "[VAL-503] Network Resilience Testing",
        "body": """## 🌐 Network Failure Scenarios

**Phase:** 2 - Dual-Write Validation  
**Team:** QA  
**Priority:** High  
**Estimate:** 3 days  
**Dependencies:** Issue #11 (VAL-501)

---

## Description

Test system behavior under poor network conditions and validate offline-first architecture works correctly.

## Acceptance Criteria

- [ ] Test sync under poor connectivity (2G, 3G, flaky WiFi)
- [ ] Validate offline queue overflow handling
- [ ] Test network transition scenarios (WiFi ↔ Cellular)
- [ ] Verify data consistency after interruptions
- [ ] Document edge case handling
- [ ] Create network resilience test suite

## Technical Details

### Test Scenarios

1. **Poor Connectivity**
   - 2G simulation (50kbps, 500ms latency)
   - Packet loss (10%, 25%, 50%)
   - Intermittent disconnections

2. **Offline Mode**
   - Complete offline for 1 hour
   - Queue 100+ operations
   - Sync on reconnect

3. **Network Transitions**
   - WiFi to Cellular handoff
   - Airplane mode toggle
   - Connection quality changes

### Tools
- Charles Proxy for network simulation
- iOS/Android network link conditioner
- Custom Flutter network test harness

## Definition of Done

- [ ] All scenarios tested and passing
- [ ] Edge cases documented
- [ ] Automated test suite created
- [ ] Resilience report published

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/high", "team/qa", "phase/dual-write"]
    },
    
    # ========================================================================
    # PHASE 3: AUTHENTICATION MIGRATION (Weeks 6-7)
    # ========================================================================
    
    {
        "title": "[MIG-601] Anonymous Account Migration Flow",
        "body": """## 👤 Anonymous to Authenticated Migration

**Phase:** 3 - Authentication Migration  
**Team:** Frontend  
**Priority:** Critical  
**Estimate:** 4 days  
**Dependencies:** Issue #13 (VAL-503)

---

## Description

Build seamless migration flow for users to transition from anonymous FCM-based auth to proper Supabase authentication.

## Acceptance Criteria

- [ ] Build anonymous to authenticated flow
- [ ] Create optional email enrollment UI
- [ ] Implement magic link authentication
- [ ] Add multi-device account linking
- [ ] Build migration monitoring dashboard
- [ ] Test migration success rate >80%

## Technical Details

### Migration UX Flow

```
User Opens App
  ↓
[One-time prompt] "Secure your account with email?"
  ↓
[Yes] → Enter email → Magic link → Account linked ✅
[No] → Continue as anonymous (can migrate later)
```

### Implementation
- Flutter onboarding screen
- Email input validation
- Magic link handler (deep link)
- Success/error states
- Analytics tracking

### Success Metrics
- Migration opt-in rate >80%
- Magic link completion >90%
- No data loss during migration
- <2% error rate

## Definition of Done

- [ ] Migration flow implemented and tested
- [ ] UI/UX approved by stakeholders
- [ ] Analytics dashboard configured
- [ ] Documentation updated
- [ ] Ready for beta testing

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/critical", "team/frontend", "phase/auth-migration"]
    },
    
    {
        "title": "[MIG-602] Account Recovery & Multi-Device Support",
        "body": """## 🔐 Account Recovery System

**Phase:** 3 - Authentication Migration  
**Team:** Frontend  
**Priority:** High  
**Estimate:** 3 days  
**Dependencies:** Issue #14 (MIG-601)

---

## Description

Implement account recovery mechanisms and multi-device session management for authenticated users.

## Acceptance Criteria

- [ ] Implement account recovery flows
- [ ] Add device management interface
- [ ] Create cross-device session sync
- [ ] Build authentication troubleshooting tools
- [ ] Test migration edge cases
- [ ] Document recovery procedures

## Technical Details

### Features

1. **Account Recovery**
   - Email-based recovery
   - Magic link reset
   - Partner verification (couples app specific)

2. **Device Management**
   - List all logged-in devices
   - Remote device logout
   - Primary device designation

3. **Session Sync**
   - JWT refresh across devices
   - Session invalidation propagation
   - Conflict resolution

## Definition of Done

- [ ] All recovery flows tested
- [ ] Device management UI complete
- [ ] Multi-device sync working
- [ ] Support documentation ready

---

**Related Documentation:** `docs/CODEX_ITERATION_2_SOLUTIONS.md`
""",
        "labels": ["priority/high", "team/frontend", "phase/auth-migration"]
    },
    
    {
        "title": "[MIG-603] App Store Submission Preparation",
        "body": """## 📱 Mobile App Store Releases

**Phase:** 3 - Authentication Migration  
**Team:** Project Management  
**Priority:** High  
**Estimate:** 2 days  
**Dependencies:** Issue #14 (MIG-601)

---

## Description

Prepare iOS and Android app submissions with new authentication system for app store review.

## Acceptance Criteria

- [ ] Prepare iOS App Store submission
- [ ] Create Google Play submission
- [ ] Document new permissions and changes
- [ ] Write app review communication
- [ ] Set up staged rollout configuration
- [ ] Create review response templates

## Technical Details

### iOS App Store
- Update app description
- Screenshot updates (new auth screens)
- Privacy policy updates
- Review notes for Apple

### Google Play
- Update store listing
- Screenshot updates
- Privacy policy updates
- Staged rollout config (5% → 20% → 100%)

### New Permissions
- Email (optional for migration)
- Network state (for sync optimization)

## Definition of Done

- [ ] iOS submission ready
- [ ] Android submission ready
- [ ] All materials prepared
- [ ] Review team briefed
- [ ] Rollback plan documented

---

**Related Documentation:** `docs/GITHUB_PROJECTS_SETUP.md`
""",
        "labels": ["priority/high", "team/pm", "phase/auth-migration"]
    },
    
    {
        "title": "[ROLL-701] 5% Migration Beta Test",
        "body": """## 🧪 5% User Migration Test

**Phase:** 3 - Authentication Migration  
**Team:** QA  
**Priority:** Critical  
**Estimate:** 2 days  
**Dependencies:** Issue #16 (MIG-603)

---

## Description

Enable migration flow for 5% of users to validate process before broader rollout.

## Acceptance Criteria

- [ ] Enable migration flow for 5% users (feature flag)
- [ ] Monitor success metrics (>80% target)
- [ ] Track authentication error rates
- [ ] Collect user feedback on migration experience
- [ ] Prepare escalation procedures
- [ ] Daily progress reports

## Technical Details

### Feature Flag
```typescript
const MIGRATION_ENABLED_PERCENTAGE = 5; // Start with 5%

function shouldShowMigration(userId: string): boolean {
  const hash = hashUserId(userId);
  return (hash % 100) < MIGRATION_ENABLED_PERCENTAGE;
}
```

### Monitoring
- Migration opt-in rate
- Magic link completion rate
- Error rates by type
- User feedback sentiment
- Support ticket volume

### Success Thresholds
- ✅ >80% opt-in rate
- ✅ >90% successful migration
- ✅ <2% error rate
- ✅ <10 support tickets

## Definition of Done

- [ ] 5% rollout complete
- [ ] Metrics above thresholds
- [ ] No critical issues
- [ ] Go/no-go decision for 20%

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/critical", "team/qa", "phase/auth-migration"]
    },
    
    {
        "title": "[ROLL-702] 20% Migration Expansion",
        "body": """## 📊 20% User Migration Rollout

**Phase:** 3 - Authentication Migration  
**Team:** QA  
**Priority:** High  
**Estimate:** 2 days  
**Dependencies:** Issue #17 (ROLL-701)

---

## Description

Scale migration to 20% of users after successful 5% validation.

## Acceptance Criteria

- [ ] Scale migration to 20% users
- [ ] Monitor authentication performance
- [ ] Validate error rates (<2% target)
- [ ] Analyze user feedback patterns
- [ ] Document migration patterns
- [ ] Prepare for full rollout

## Technical Details

### Rollout Strategy
- Increase feature flag from 5% → 20%
- Monitor for 48 hours
- Collect performance metrics
- Analyze support tickets
- Validate database load

### Key Metrics
- Migration success rate
- API latency (auth endpoints)
- Database connection usage
- Support ticket volume
- User satisfaction scores

## Definition of Done

- [ ] 20% rollout complete
- [ ] Performance stable
- [ ] No critical issues
- [ ] Approval for 100% rollout

---

**Related Documentation:** `docs/CODEX_ITERATION_2_SOLUTIONS.md`
""",
        "labels": ["priority/high", "team/qa", "phase/auth-migration"]
    },
    
    {
        "title": "[ROLL-703] Full Migration Execution (100%)",
        "body": """## 🚀 Complete Authentication Migration

**Phase:** 3 - Authentication Migration  
**Team:** QA  
**Priority:** Critical  
**Estimate:** 3 days  
**Dependencies:** Issue #18 (ROLL-702)

---

## Description

Enable migration for all users while maintaining anonymous fallback for users who decline.

## Acceptance Criteria

- [ ] Enable migration for all users (100%)
- [ ] Maintain anonymous fallback for declined users
- [ ] Monitor overall authentication metrics
- [ ] Document final migration results
- [ ] Prepare support documentation
- [ ] Create post-migration report

## Technical Details

### Rollout Phases
1. **Day 1:** 100% feature flag enabled
2. **Day 2:** Monitor metrics, address issues
3. **Day 3:** Final validation and reporting

### Final Success Metrics
- Total migration rate
- Anonymous user percentage
- System stability
- Performance benchmarks
- User satisfaction

### Anonymous Fallback
- Users can skip migration
- Continue with FCM-based auth
- Can migrate later from settings
- No functionality loss

## Definition of Done

- [ ] 100% rollout complete
- [ ] Metrics documented
- [ ] Post-migration report published
- [ ] Phase 3 complete ✅

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/critical", "team/qa", "phase/auth-migration"]
    },
    
    # ========================================================================
    # PHASE 4: FEATURE MIGRATION (Weeks 8-10) - Core Features
    # ========================================================================
    
    {
        "title": "[FEAT-801] Quiz System Migration",
        "body": """## 🎯 Quiz System Migration

**Phase:** 4 - Feature Migration  
**Team:** Backend + Frontend  
**Priority:** Critical  
**Estimate:** 5 days  
**Dependencies:** Issue #19 (ROLL-703)

---

## Description

Migrate quiz system from Firebase RTDB to PostgreSQL with quiz sessions, answers, and progression tracking.

## Acceptance Criteria

- [ ] Migrate quiz_sessions table
- [ ] Migrate quiz_answers table  
- [ ] Migrate quiz_progression tracking
- [ ] Implement sync API endpoints
- [ ] Update Flutter quiz service
- [ ] Migrate historical quiz data
- [ ] Test quiz flow end-to-end

## Technical Details

### API Endpoints
- POST /api/sync/quiz-session
- GET /api/quiz/progression
- POST /api/quiz/answer

### Database Tables
- quiz_sessions (questions stored as JSONB)
- quiz_answers (with session_id references)
- quiz_progression (track completed quizzes)

### Flutter Changes
- Update QuizService to use new API
- Implement offline queue for answers
- Add optimistic UI updates

## Definition of Done

- [ ] All quiz features working on PostgreSQL
- [ ] Historical data migrated
- [ ] Tests passing
- [ ] Documentation updated

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md` (Quiz System section)
""",
        "labels": ["priority/critical", "team/backend", "team/frontend", "phase/features"]
    },
    
    {
        "title": "[FEAT-802] You or Me Game Migration",
        "body": """## 🎮 You or Me Game Migration

**Phase:** 4 - Feature Migration  
**Team:** Backend + Frontend  
**Priority:** High  
**Estimate:** 4 days  
**Dependencies:** Issue #20 (FEAT-801)

---

## Description

Migrate You or Me game from Firebase to PostgreSQL with session management and progression tracking.

## Acceptance Criteria

- [ ] Migrate you_or_me_sessions table
- [ ] Migrate you_or_me_answers table
- [ ] Migrate you_or_me_progression (used questions)
- [ ] Implement sync API endpoints
- [ ] Update Flutter game service
- [ ] Test game flow end-to-end

## Technical Details

### API Endpoints
- POST /api/sync/you-or-me-session
- POST /api/you-or-me/answer
- GET /api/you-or-me/progression

### Database Schema
- you_or_me_sessions (questions as JSONB)
- you_or_me_answers (user responses)
- you_or_me_progression (track used questions)

## Definition of Done

- [ ] Game working on PostgreSQL
- [ ] All features functional
- [ ] Tests passing
- [ ] Documentation updated

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/high", "team/backend", "team/frontend", "phase/features"]
    },
    
    {
        "title": "[FEAT-803] Memory Flip Game Migration",
        "body": """## 🃏 Memory Flip Game Migration

**Phase:** 4 - Feature Migration  
**Team:** Backend + Frontend  
**Priority:** High  
**Estimate:** 4 days  
**Dependencies:** Issue #20 (FEAT-801)

---

## Description

Migrate Memory Flip puzzle game from Firebase to PostgreSQL with card state management.

## Acceptance Criteria

- [ ] Migrate memory_puzzles table
- [ ] Implement puzzle generation logic
- [ ] Create sync API endpoint
- [ ] Update Flutter memory game service
- [ ] Test card matching and sync
- [ ] Validate puzzle completion flow

## Technical Details

### API Endpoint
- POST /api/sync/memory-puzzle

### Database Schema
```sql
CREATE TABLE memory_puzzles (
  id UUID PRIMARY KEY,
  couple_id UUID REFERENCES couples(id),
  date DATE NOT NULL,
  cards JSONB NOT NULL, -- Card state array
  matched_pairs INT DEFAULT 0,
  total_pairs INT NOT NULL,
  status TEXT DEFAULT 'active',
  UNIQUE(couple_id, date)
);
```

### Key Features
- Server-authoritative card matching
- Optimistic UI updates
- Sync on match attempt
- Daily puzzle generation

## Definition of Done

- [ ] Memory game working on PostgreSQL
- [ ] Card state syncing correctly
- [ ] Tests passing
- [ ] Documentation updated

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md` (Memory Flip section)
""",
        "labels": ["priority/high", "team/backend", "team/frontend", "phase/features"]
    },
    
    {
        "title": "[FEAT-804] Love Points System Migration",
        "body": """## 💕 Love Points Migration

**Phase:** 4 - Feature Migration  
**Team:** Backend + Frontend  
**Priority:** Critical  
**Estimate:** 4 days  
**Dependencies:** Issue #21 (FEAT-802)

---

## Description

Migrate Love Points system with award tracking and user totals. **Critical: Fixes duplicate LP awards bug.**

## Acceptance Criteria

- [ ] Migrate love_point_awards table
- [ ] Migrate user_love_points (materialized totals)
- [ ] Implement deduplication via related_id
- [ ] Create sync API endpoint
- [ ] Update Flutter LP service
- [ ] Test duplicate prevention
- [ ] Migrate historical LP data

## Technical Details

### Database Schema
```sql
CREATE TABLE love_point_awards (
  id UUID PRIMARY KEY,
  couple_id UUID REFERENCES couples(id),
  related_id UUID, -- Quest/session ID
  amount INT NOT NULL,
  reason TEXT NOT NULL,
  CONSTRAINT unique_related_award UNIQUE(couple_id, related_id)
);
```

### Key Fix
The `unique_related_award` constraint **prevents duplicate LP awards** (solves 60 LP bug documented in KNOWN_ISSUES.md).

### API Endpoint
- POST /api/sync/love-points

## Definition of Done

- [ ] LP system working on PostgreSQL
- [ ] Duplicate awards impossible
- [ ] Historical data migrated
- [ ] Tests passing (including duplicate prevention)

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md` (LP Awards section)
""",
        "labels": ["priority/critical", "team/backend", "team/frontend", "phase/features"]
    },
    
    {
        "title": "[FEAT-805] Daily Quests Full Migration",
        "body": """## 📅 Daily Quests Complete Migration

**Phase:** 4 - Feature Migration  
**Team:** Backend + Frontend  
**Priority:** Critical  
**Estimate:** 5 days  
**Dependencies:** Issue #23 (FEAT-804)

---

## Description

Complete migration of daily quests system with server-side generation and completion tracking.

## Acceptance Criteria

- [ ] Migrate daily_quests table
- [ ] Migrate quest_completions table
- [ ] Implement server-side quest generation
- [ ] Update quest sync API endpoint
- [ ] Migrate Flutter quest service
- [ ] Test quest generation and completion
- [ ] Migrate historical quest data

## Technical Details

### Server-Side Generation
```typescript
// Server generates quests, not client
async function generateDailyQuests(coupleId, date) {
  // Load progression
  // Generate 3 quiz quests + 1 you-or-me
  // Insert into daily_quests table
  // Return quests
}
```

### API Endpoint
- POST /api/sync/daily-quests

### Key Improvement
- Server-authoritative (can't cheat)
- Consistent quest generation
- Proper completion validation

## Definition of Done

- [ ] Daily quests working on PostgreSQL
- [ ] Server-side generation working
- [ ] Quest completion tracking correct
- [ ] Historical data migrated
- [ ] Tests passing

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md` (Daily Quests section)
""",
        "labels": ["priority/critical", "team/backend", "team/frontend", "phase/features"]
    },
    
    # ========================================================================
    # PHASE 5: DATA MIGRATION & CLEANUP (Weeks 11-13)
    # ========================================================================
    
    {
        "title": "[DATA-901] Historical Data Migration Script",
        "body": """## 📦 Historical Data Migration

**Phase:** 5 - Data Migration  
**Team:** Backend  
**Priority:** Critical  
**Estimate:** 3 days  
**Dependencies:** Issue #24 (FEAT-805)

---

## Description

Create and execute scripts to migrate all historical data from Firebase RTDB to PostgreSQL.

## Acceptance Criteria

- [ ] Create data extraction script from Firebase
- [ ] Create data transformation script
- [ ] Create PostgreSQL import script
- [ ] Validate data integrity after migration
- [ ] Create rollback procedures
- [ ] Document migration process

## Technical Details

### Migration Strategy
1. **Extract** - Read all data from Firebase RTDB
2. **Transform** - Convert to PostgreSQL schema
3. **Load** - Import into PostgreSQL
4. **Validate** - Compare counts and checksums

### Data to Migrate
- All couples and user relationships
- Historical quiz sessions and answers
- Historical quest completions
- LP award history
- Memory puzzle history

### Validation Checks
- Row count matches
- Data integrity checks
- Foreign key validation
- No null constraint violations

## Definition of Done

- [ ] All scripts created and tested
- [ ] Data migration executed successfully
- [ ] Validation passed
- [ ] Rollback tested
- [ ] Documentation complete

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/critical", "team/backend", "phase/data-migration"]
    },
    
    {
        "title": "[DATA-902] Firebase RTDB Deprecation",
        "body": """## 🗑️ Firebase RTDB Sunset

**Phase:** 5 - Data Migration  
**Team:** Backend  
**Priority:** High  
**Estimate:** 2 days  
**Dependencies:** Issue #25 (DATA-901)

---

## Description

Safely deprecate Firebase RTDB after confirming PostgreSQL is stable and complete.

## Acceptance Criteria

- [ ] Confirm all features running on PostgreSQL
- [ ] Remove dual-write code
- [ ] Remove Firebase RTDB dependencies
- [ ] Archive Firebase data for compliance
- [ ] Update documentation
- [ ] Communicate deprecation to team

## Technical Details

### Deprecation Checklist
- [ ] 30-day soak period on PostgreSQL only
- [ ] Zero critical issues
- [ ] Performance targets met
- [ ] Stakeholder approval

### Code Cleanup
- Remove Firebase RTDB SDK
- Remove dual-write logic
- Update environment variables
- Clean up unused imports

### Data Archival
- Export full Firebase RTDB JSON
- Store in S3/cloud storage
- Document retention policy

## Definition of Done

- [ ] Firebase RTDB no longer in use
- [ ] Code cleaned up
- [ ] Data archived
- [ ] Documentation updated
- [ ] Team notified

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/high", "team/backend", "phase/data-migration"]
    },
    
    {
        "title": "[DATA-903] Post-Migration Performance Validation",
        "body": """## 🚀 Final Performance Validation

**Phase:** 5 - Data Migration  
**Team:** QA  
**Priority:** Critical  
**Estimate:** 3 days  
**Dependencies:** Issue #26 (DATA-902)

---

## Description

Comprehensive performance validation after complete migration to PostgreSQL.

## Acceptance Criteria

- [ ] Run 48-hour production load test
- [ ] Validate all performance targets met
- [ ] Confirm 39% load reduction achieved
- [ ] Verify battery improvement (35% target)
- [ ] Create final migration report
- [ ] Obtain stakeholder sign-off

## Technical Details

### Performance Targets
- ✅ API p95 latency: <200ms
- ✅ JWT verification: <1ms
- ✅ DB connections: <60 concurrent
- ✅ Request reduction: 39%
- ✅ Battery improvement: 35%
- ✅ Error rate: <0.1%

### Test Scenarios
1. Normal load (1K couples)
2. Peak load (3x normal)
3. Network failures
4. Database failover
5. Edge cases

## Definition of Done

- [ ] 48-hour test complete
- [ ] All targets met or exceeded
- [ ] Final report published
- [ ] Migration officially complete ✅

---

**Related Documentation:** `docs/CODEX_ROUND_2_REVIEW_SUMMARY.md`
""",
        "labels": ["priority/critical", "team/qa", "phase/data-migration"]
    },
    
    # ========================================================================
    # PHASE 6: PRODUCTION CUTOVER (Week 14)
    # ========================================================================
    
    {
        "title": "[PROD-1001] Production Deployment Plan",
        "body": """## 🚀 Production Cutover Strategy

**Phase:** 6 - Production Cutover  
**Team:** DevOps  
**Priority:** Critical  
**Estimate:** 2 days  
**Dependencies:** Issue #27 (DATA-903)

---

## Description

Create and execute production cutover plan with rollback procedures.

## Acceptance Criteria

- [ ] Create detailed cutover plan
- [ ] Define rollback triggers
- [ ] Schedule deployment window
- [ ] Brief all stakeholders
- [ ] Prepare monitoring and alerts
- [ ] Execute deployment

## Technical Details

### Cutover Steps
1. Final data sync (T-1 hour)
2. Enable maintenance mode (T-0)
3. Switch DNS/traffic to new system
4. Validate health checks
5. Monitor for 2 hours
6. Disable maintenance mode

### Rollback Triggers
- Error rate >2%
- API latency >500ms
- Database connection failures
- Critical bug discovered

### Communication Plan
- Pre-deployment announcement
- Status updates every 30 min
- Post-deployment summary

## Definition of Done

- [ ] Cutover plan documented
- [ ] Team briefed
- [ ] Deployment successful
- [ ] System stable

---

**Related Documentation:** `docs/MIGRATION_TO_NEXTJS_POSTGRES.md`
""",
        "labels": ["priority/critical", "team/devops", "phase/cutover"]
    },
    
    {
        "title": "[PROD-1002] Post-Cutover Monitoring (48h)",
        "body": """## 👀 48-Hour Production Monitoring

**Phase:** 6 - Production Cutover  
**Team:** DevOps + QA  
**Priority:** Critical  
**Estimate:** 2 days  
**Dependencies:** Issue #28 (PROD-1001)

---

## Description

Intensive 48-hour monitoring period after production cutover to ensure stability.

## Acceptance Criteria

- [ ] 24/7 on-call rotation established
- [ ] Monitor all critical metrics
- [ ] Respond to alerts within 15 minutes
- [ ] Document all incidents
- [ ] Create hourly status reports
- [ ] Obtain final sign-off

## Technical Details

### Monitoring Checklist
- API error rates
- Database performance
- Authentication success rates
- Feature functionality
- User-reported issues
- Performance metrics

### Success Criteria
- Zero critical incidents
- Performance targets met
- User satisfaction maintained
- No rollback required

## Definition of Done

- [ ] 48 hours complete
- [ ] System stable
- [ ] Final report published
- [ ] **Migration project complete!** 🎉

---

**Related Documentation:** `docs/CODEX_ROUND_2_REVIEW_SUMMARY.md`
""",
        "labels": ["priority/critical", "team/devops", "team/qa", "phase/cutover"]
    },
    
    {
        "title": "[RETRO-1003] Migration Retrospective & Documentation",
        "body": """## 📚 Project Retrospective

**Phase:** 6 - Post-Migration  
**Team:** All  
**Priority:** Medium  
**Estimate:** 1 day  
**Dependencies:** Issue #29 (PROD-1002)

---

## Description

Conduct project retrospective and create comprehensive migration documentation.

## Acceptance Criteria

- [ ] Conduct team retrospective meeting
- [ ] Document lessons learned
- [ ] Create migration case study
- [ ] Archive project documentation
- [ ] Celebrate team success! 🎉
- [ ] Plan future improvements

## Technical Details

### Retrospective Topics
- What went well?
- What could be improved?
- What did we learn?
- What surprised us?
- What would we do differently?

### Documentation
- Final migration report
- Technical architecture doc
- Performance improvements summary
- Bug fixes documented
- Future enhancement ideas

## Definition of Done

- [ ] Retrospective complete
- [ ] Documentation archived
- [ ] Team recognition completed
- [ ] Project officially closed ✅

---

**Congratulations on completing the migration!** 🚀
""",
        "labels": ["priority/medium", "team/pm", "phase/cutover"]
    }
]


def create_issue(issue_data: Dict) -> int:
    """Create a single GitHub issue"""
    title = issue_data["title"]
    body = issue_data["body"]
    labels = ",".join(issue_data["labels"])
    
    cmd = [
        "gh", "issue", "create",
        "--repo", "jachren-f4/together-reminder",
        "--title", title,
        "--body", body,
        "--label", labels
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        # Extract issue number from URL
        url = result.stdout.strip()
        issue_num = int(url.split('/')[-1])
        print(f"✅ Created issue #{issue_num}: {title}")
        return issue_num
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to create issue: {title}")
        print(f"   Error: {e.stderr}")
        return 0


def main():
    """Create all migration issues"""
    print("🚀 Creating all migration issues (Phases 2-6)...")
    print(f"📋 Total issues to create: {len(ISSUES)}\n")
    
    created = []
    failed = []
    
    for i, issue in enumerate(ISSUES, 1):
        print(f"[{i}/{len(ISSUES)}] Creating: {issue['title']}")
        issue_num = create_issue(issue)
        
        if issue_num:
            created.append(issue_num)
        else:
            failed.append(issue['title'])
        
        # Small delay to avoid rate limiting
        if i < len(ISSUES):
            import time
            time.sleep(0.5)
    
    print(f"\n{'='*60}")
    print(f"✅ Successfully created: {len(created)} issues")
    if failed:
        print(f"❌ Failed to create: {len(failed)} issues")
        for title in failed:
            print(f"   - {title}")
    
    print(f"\n📊 Issue Summary:")
    print(f"   Phase 1 (existing): Issues #2-7")
    print(f"   Phase 2 (dual-write): Issues #8-13")
    print(f"   Phase 3 (auth migration): Issues #14-19")
    print(f"   Phase 4 (features): Issues #20-24")
    print(f"   Phase 5 (data): Issues #25-27")
    print(f"   Phase 6 (cutover): Issues #28-30")
    
    print(f"\n🔗 View all issues:")
    print(f"   https://github.com/jachren-f4/together-reminder/issues")
    
    print(f"\n🎯 Next step: Start working on Issue #2 (INFRA-101)")


if __name__ == "__main__":
    main()
