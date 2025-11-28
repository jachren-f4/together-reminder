# Migration Project Handover

**Date:** 2025-11-19
**Status:** Phase 1 Issues Created, Cloud Automation Ready
**Repository:** https://github.com/jachren-f4/together-reminder

---

## Executive Summary

The Firebase RTDB to PostgreSQL/Supabase migration project is ready for implementation. All Phase 1 GitHub issues have been created with detailed specifications, and cloud automation infrastructure is configured.

### Current State

| Component | Status | Notes |
|-----------|--------|-------|
| Documentation | ✅ Complete | Full technical specs in `docs/MIGRATION_TO_NEXTJS_POSTGRES.md` |
| GitHub Issues | ✅ Created | 6 Phase 1 issues with labels and dependencies |
| Cloud Automation | ✅ Configured | Codespaces devcontainer ready |
| Infrastructure | ❌ Not deployed | Vercel + Supabase projects need creation |
| Database | ❌ Not deployed | Schema designed, not executed |
| API Endpoints | ❌ Not implemented | Specifications complete |

---

## Phase 1 GitHub Issues

All issues are live at: https://github.com/jachren-f4/together-reminder/issues

### Infrastructure (Week 1)

| Issue | Title | Priority | Team | Dependencies |
|-------|-------|----------|------|--------------|
| #2 | [INFRA-101] Create Vercel & Supabase Projects | Critical | DevOps | None |
| #4 | [INFRA-102] Database Schema & Indexing | Critical | Backend | INFRA-101 |
| #3 | [INFRA-103] Monitoring & Alerting Infrastructure | High | DevOps | INFRA-101 |

### Authentication (Week 2)

| Issue | Title | Priority | Team | Dependencies |
|-------|-------|----------|------|--------------|
| #5 | [AUTH-201] JWT Verification Middleware | Critical | Backend | INFRA-103 |
| #6 | [AUTH-202] Flutter Auth Service with Token Refresh | Critical | Frontend | AUTH-201 |
| #7 | [AUTH-203] Auth Flow Testing & Validation | High | QA | AUTH-201, AUTH-202 |

### Labels Created

- **Priority:** `priority/critical`, `priority/high`
- **Team:** `team/backend`, `team/frontend`, `team/devops`, `team/qa`
- **Phase:** `phase/infra`, `phase/auth`

---

## Cloud Automation Setup

### GitHub Codespaces (Recommended)

A devcontainer configuration has been created at `.devcontainer/devcontainer.json`.

#### Setup Steps

1. **Add API Key to Codespaces Secrets**
   ```bash
   gh codespace secret set ANTHROPIC_API_KEY
   # Paste your Anthropic API key when prompted
   ```

   Or via GitHub UI:
   - Go to https://github.com/settings/codespaces
   - Click "New secret"
   - Name: `ANTHROPIC_API_KEY`
   - Value: Your Anthropic API key
   - Repository access: Select `together-reminder`

2. **Launch Codespace**
   - Go to https://github.com/jachren-f4/together-reminder
   - Click **Code** → **Codespaces** → **Create codespace on main**
   - Wait ~2 minutes for environment setup

3. **Start Working**
   ```bash
   # Work on highest priority issue
   claude "Implement issue #2 INFRA-101 - Create Vercel and Supabase projects"

   # Or get an overview
   claude "Analyze issues #2-7 and create an implementation plan"
   ```

### Workflow Pattern

```bash
# Morning: Review and prioritize
claude "What's the highest priority unblocked issue?"

# Implement
claude "Implement issue #5 AUTH-201"

# Review and commit
claude "Review changes and commit"

# Create PR
claude "Create a pull request linking to issue #5"
```

---

## Critical Path

The implementation should follow this order due to dependencies:

```
INFRA-101 (Vercel + Supabase)
    ↓
INFRA-102 (Database Schema) ←── INFRA-103 (Monitoring)
    ↓
AUTH-201 (JWT Middleware)
    ↓
AUTH-202 (Flutter Auth)
    ↓
AUTH-203 (Testing)
```

**Start with INFRA-101** - it has no dependencies and unblocks everything else.

---

## Key Documentation

| Document | Location | Purpose |
|----------|----------|---------|
| Migration Plan | `docs/MIGRATION_TO_NEXTJS_POSTGRES.md` | Complete technical specification |
| Database Schema | `docs/database_migration.md` | SQL schema definitions |
| GitHub Setup | `docs/GITHUB_PROJECTS_SETUP.md` | Issue structure and labels |
| AI Automation | `.github/AI_DEVELOPMENT_AUTOMATION.md` | Agent architecture |
| Sync Architecture | `docs/BACKEND_SYNC_ARCHITECTURE.md` | Current Firebase patterns |

---

## What This Migration Fixes

The migration eliminates these documented bugs:

1. **Duplicate LP Awards (60 LP bug)** - Database UNIQUE constraint on `(couple_id, related_id)`
2. **Memory Flip Sync Failures** - Server-generated deterministic IDs
3. **Quest Title Display Issues** - Already fixed with metadata denormalization
4. **Race Conditions** - Database constraints handle atomically
5. **Listener Duplication** - Polling model eliminates listeners entirely

---

## Steps Together Feature Migration

**Status:** Dual-write implemented, ready for validation

The Steps Together feature tracks daily step counts from both partners via HealthKit (iOS) and awards LP based on combined totals. This feature was added with dual-write from the start.

### Current State

| Component | Firebase RTDB | Supabase | Status |
|-----------|--------------|----------|--------|
| Connection status | `/steps_data/{coupleId}/connections/{userId}` | `steps_connections` | ✅ Dual-write active |
| Daily steps | `/steps_data/{coupleId}/today/{userId}` | `steps_daily` | ✅ Dual-write active |
| Yesterday steps | `/steps_data/{coupleId}/yesterday/{userId}` | `steps_daily` | ✅ Dual-write active |
| Claim tracking | `/steps_data/{coupleId}/yesterday/claimed_by` | `steps_rewards` | ✅ Dual-write active |

### Supabase Schema

Created in migration `018_steps_together.sql`:

```sql
-- Connection status per user
steps_connections (
  user_id UUID PRIMARY KEY,
  couple_id UUID,
  is_connected BOOLEAN,
  connected_at TIMESTAMPTZ
)

-- Daily step counts
steps_daily (
  id UUID PRIMARY KEY,
  couple_id UUID,
  user_id UUID,
  date_key DATE,
  steps INT,
  last_sync_at TIMESTAMPTZ,
  UNIQUE(user_id, date_key)
)

-- Claim tracking (prevents double-claiming)
steps_rewards (
  id UUID PRIMARY KEY,
  couple_id UUID,
  date_key DATE,
  combined_steps INT,
  lp_earned INT,
  claimed_by UUID,
  claimed_at TIMESTAMPTZ,
  UNIQUE(couple_id, date_key)
)
```

### API Endpoint

`/api/sync/steps` - Single endpoint with operation parameter:

| Operation | Method | Purpose |
|-----------|--------|---------|
| `connection` | POST | Sync HealthKit connection status |
| `steps` | POST | Sync daily step count |
| `claim` | POST | Record LP claim (with double-claim prevention) |
| - | GET | Get all step data for couple |

### Migration Steps

#### Phase 1: Validation (Current)
- [x] Deploy Supabase migration (`018_steps_together.sql`)
- [x] Deploy API endpoint (`/api/sync/steps`)
- [x] Enable dual-write in Flutter (fire-and-forget)
- [ ] Validate Supabase data matches Firebase for 1 week
- [ ] Run comparison queries to verify data integrity

#### Phase 2: Read Migration
- [ ] Add GET endpoint to fetch step data from Supabase
- [ ] Create `StepsSyncService.fetchFromSupabase()` method
- [ ] A/B test: Some couples read from Supabase
- [ ] Monitor for discrepancies

#### Phase 3: Firebase Removal
- [ ] Remove Firebase writes from `StepsSyncService`
- [ ] Remove Firebase listeners (`_startTodayListener`, `_startYesterdayListener`)
- [ ] Delete Firebase RTDB path `/steps_data/`
- [ ] Update Flutter to read exclusively from Supabase

### Real-Time Sync Consideration

**Current Firebase behavior:**
- Partner step updates appear in real-time via RTDB listeners
- Partner claim status syncs immediately

**Supabase replacement options:**
1. **Polling** - Fetch every 30 seconds (simpler, slight delay)
2. **Supabase Realtime** - Subscribe to `steps_daily` changes (complex setup)
3. **Hybrid** - Polling for steps, push notification for claims

**Recommendation:** Use polling (30s interval) since step data isn't time-critical. Claims can trigger push notification for immediate feedback.

### Files to Modify

| File | Changes Needed |
|------|----------------|
| `lib/services/steps_sync_service.dart` | Remove Firebase, add Supabase reads |
| `lib/services/steps_health_service.dart` | Update data source references |
| `api/app/api/sync/steps/route.ts` | Already complete |
| `api/supabase/migrations/018_steps_together.sql` | Already complete |

---

## Environment Variables Needed

For Vercel deployment (set in Vercel dashboard):

```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx
DATABASE_URL=postgresql://postgres:xxx@xxx.supabase.co:5432/postgres
DATABASE_POOL_URL=postgresql://postgres:xxx@xxx.pooler.supabase.com:6543/postgres
SUPABASE_JWT_SECRET=xxx
```

---

## Next Steps

### Immediate (Today)

1. Push devcontainer config to GitHub:
   ```bash
   git add .devcontainer/ docs/MIGRATION_HANDOVER.md
   git commit -m "Add Codespaces config and migration handover"
   git push
   ```

2. Set up Codespaces secret with your Anthropic API key

3. Launch Codespace and start with INFRA-101

### This Week

1. **Day 1-2:** Complete INFRA-101 (Vercel + Supabase projects)
2. **Day 3-4:** Complete INFRA-102 (Database schema deployment)
3. **Day 5:** Complete INFRA-103 (Monitoring setup)

### Next Week

1. Implement AUTH-201, AUTH-202, AUTH-203
2. Create Phase 2 issues (Quest system implementation)
3. Begin dual-write validation

---

## Success Metrics

### Phase 1 Complete When

- [ ] Vercel project deployed and accessible
- [ ] Supabase database with all tables and indexes
- [ ] Health check endpoint responding
- [ ] JWT middleware authenticating requests
- [ ] Flutter AuthService with secure token storage
- [ ] Load test passing (10K concurrent requests)

### Performance Targets

- API p95 latency: <200ms
- JWT verification: <1ms
- Database connections: <60 concurrent
- Error rate: <0.1%

---

## Support & Resources

- **Flutter Docs:** https://docs.flutter.dev/
- **Next.js Docs:** https://nextjs.org/docs
- **Supabase Docs:** https://supabase.com/docs
- **Project Issues:** https://github.com/jachren-f4/together-reminder/issues

---

**Last Updated:** 2025-11-28
