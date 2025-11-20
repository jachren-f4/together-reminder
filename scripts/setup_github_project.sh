#!/bin/bash

# GitHub Migration Project Setup Script
# Run this to set up the complete GitHub Issues structure
#
# Usage: ./scripts/setup_github_project.sh

echo "🚀 Setting up Firebase → PostgreSQL Migration Project"

# Configuration
REPO="togetherremind"
PROJECT_NAME="Firebase → PostgreSQL Migration"
CURRENT_DIR=$(pwd)

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first."
    echo "Visit: https://cli.github.com/manual/installation"
    exit 1
fi

# Check authentication
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub. Run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI ready"

# Step 1: Create labels
echo "🏷️  Creating labels..."

# Priority labels
gh label create -c "ff0000" -R "Critical priority, must complete for milestone" "priority/critical"
gh label create -c "ff8c00" -R "High priority, important for timeline" "priority/high"  
gh label create -c "ffd700" -R "Medium priority, nice to have" "priority/medium"
gh label create -c "0088cc" -R "Low priority, optional" "priority/low"

# Team labels
gh label create -c "7f8c8d" -R "Backend Developer tasks" "team/backend"
gh label create -c "f39c12" -R "Frontend Developer tasks" "team/frontend"
gh label create -c "8e44ad" -R "DevOps/Infrastructure tasks" "team/devops"
gh label create -c "27ae60" -R "Testing and validation tasks" "team/qa"
gh label create -c "2c3e50" -R "Project Management tasks" "team/pm"

# Phase labels
gh label create -c "3498db" -R "Infrastructure setup phase" "phase/infra"
gh label create -c "9b59b6" -R "Authentication flow phase" "phase/auth"
gh label create -c "1abc9c" -R "Feature migration phase" "phase/features"
gh label create -c "f1c40f" -R "Testing and validation phase" "phase/validation"
gh label create -c "e74c3c" -R "Production deployment phase" "phase/cutover"

# Status labels
gh label create -c "c0392b" -R "Dependency not met, blocked" "status/blocked"
gh label create -c "3498db" -R "Currently being worked on" "status/in-progress"
gh label create -c "f39c12" -R "Ready for code review" "status/review"
gh label create -c "27ae60" -R "Task completed successfully" "status/done"

echo "✅ Labels created"

# Step 2: Create Phase 1 Issues
echo "📝 Creating Phase 1 Issues..."

# Infrastructure Week 1 Issues
cat > /tmp/infra-101.md << 'EOF'
## [INFRA-101] Create Vercel & Supabase Projects

**Team:** DevOps @devops-lead  
**Priority:** #priority/critical  
**Phase:** #phase/infra  
**Estimate:** 2 days

### Tasks
- [ ] Create Vercel project with Next.js boilerplate
- [ ] Create Supabase project with PostgreSQL
- [ ] Configure database connection URLs
- [ ] Set up environment variables management
- [ ] Run initial database schema migration

### Dependencies
- Environment documentation complete

### Acceptance Criteria
- Vercel project deployed and accessible
- Supabase project with PostgreSQL running
- Database schemas created and tested
- Environment variables properly configured
- Basic connectivity verified

**Blocked by:** None  
**Blocks:** INFRA-102, INFRA-103
EOF

gh issue create --title "[INFRA-101] Create Vercel & Supabase Projects" \
                --body-file /tmp/infra-101.md \
                --label "priority/critical,phase/infra,team/devops" \
                --assignee @devops-lead

# Database setup issue
cat > /tmp/infra-102.md << 'EOF'
## [INFRA-102] Database Schema & Indexing

**Team:** Backend @backend-lead  
**Priority:** #priority/critical  
**Phase:** #phase/infra  
**Estimate:** 3 days

### Dependencies
- #101 Create Vercel & Supabase Projects

### Tasks
- [ ] Execute complete migration SQL with proper indexes
- [ ] Set up Row Level Security policies
- [ ] Create connection pool monitoring tables
- [ ] Validate database constraints and uniqueness
- [ ] Test connection limits with load simulation

### Acceptance Criteria
- All database tables created with proper indexes
- RLS policies working correctly
- Connection pool monitoring functional
- Load testing up to 100 connections successful
- Performance benchmarks established

**Blocks:** INFRA-201 (JWT middleware needs database)
EOF

gh issue create --title "[INFRA-102] Database Schema & Indexing" \
                --body-file /tmp/infra-102.md \
                --label "priority/critical,phase/infra,team/backend" \
                --assignee @backend-lead

# Monitoring infrastructure
cat > /tmp/infra-103.md << 'EOF'
## [INFRA-103] Monitoring & Alerting Infrastructure

**Team:** DevOps @devops-lead  
**Priority:** #priority/high  
**Phase:** #phase/infra  
**Estimate:** 2 days

### Dependencies
- #101 Create Vercel & Supabase Projects

### Tasks
- [ ] Set up Sentry error tracking
- [ ] Create health check endpoints
- [ ] Configure Prometheus metrics
- [ ] Set up alert thresholds (DB connections, API latency)
- [ ] Create monitoring dashboards

### Acceptance Criteria
- Sentry integrated and receiving errors
- Health endpoints accessible and reporting
- Prometheus metrics collection working
- Alert thresholds configured and tested
- Grafana dashboards created and visible

**Blocks:** All subsequent backend tasks need monitoring
EOF

gh issue create --title "[INFRA-103] Monitoring & Alerting Infrastructure" \
                --body-file /tmp/infra-103.md \
                --label "priority/high,phase/infra,team/devops" \
                --assignee @devops-lead

# Authentication Week 2 Issues
cat > /tmp/auth-201.md << 'EOF'
## [AUTH-201] JWT Verification Middleware

**Team:** Backend @backend-lead  
**Priority:** #priority/critical  
**Phase:** #phase/auth  
**Estimate:** 3 days

### Dependencies
- #103 Monitoring & Alerting Infrastructure

### Tasks
- [ ] Implement local JWT verification using SUPABASE_JWT_SECRET
- [ ] Create auth middleware for all API routes
- [ ] Add user existence cache for performance
- [ ] Test with 10K+ simulated concurrent requests
- [ ] Add rate limiting for auth endpoints

### Acceptance Criteria
- JWT verification < 1ms consistently
- Auth middleware working on all protected routes
- User existence cache improving performance
- Load testing with 1000+ concurrent users successful
- Rate limiting prevents abuse while allowing legitimate use

**Blocks:** AUTH-202 (Flutter needs JWT middleware)
**Blocked by:** INFRA-103
EOF

gh issue create --title "[AUTH-201] JWT Verification Middleware" \
                --body-file /tmp/auth-201.md \
                --label "priority/critical,phase/auth,team/backend" \
                --assignee @backend-lead

cat > /tmp/auth-202.md << 'EOF'
## [AUTH-202] Flutter Auth Service with Token Refresh

**Team:** Frontend @frontend-lead  
**Priority:** #priority/critical  
**Phase:** #phase/auth  
**Estimate:** 3 days

### Dependencies
- #201 JWT Verification Middleware

### Tasks
- [ ] Implement AuthService with secure storage
- [ ] Build background token refresh scheduler
- [ ] Add local JWT expiry detection
- [ ] Create authentication error handling
- [ ] Test cross-device token synchronization

### Acceptance Criteria
- AuthService storing tokens securely
- Background refresh working without user interaction
- JWT expiry detected proactively
- Auth errors handled gracefully with user feedback
- Same user account working across multiple devices

**Blocks:** QUEST-301 (API needs working auth)
**Blocked by:** AUTH-201
EOF

gh issue create --title "[AUTH-202] Flutter Auth Service with Token Refresh" \
                --body-file /tmp/auth-202.md \
                --label "priority/critical,phase/auth,team/frontend" \
                --assignee @frontend-lead

cat > /tmp/auth-203.md << 'EOF'
## [AUTH-203] Auth Flow Testing & Validation

**Team:** QA @qa-lead  
**Priority:** #priority/high  
**Phase:** #phase/auth  
**Estimate:** 2 days

### Dependencies
- #201 JWT Verification Middleware
- #202 Flutter Auth Service with Token Refresh

### Tasks
- [ ] Load test auth flow with real user scenarios
- [ ] Test token refresh under network failures
- [ ] Validate auth flow across iOS/Android
- [ ] Security audit of JWT implementation
- [ ] Performance benchmarking (<1ms verification target)

### Acceptance Criteria
- Auth flow handles 1000+ concurrent users
- Token refresh works with poor network connectivity
- iOS and Android both auth successfully
- Security audit passes all checks
- Performance benchmarks meet target (<1ms)

**Blocks:** MIG-601 (Migration needs tested auth)
**Blocked by:** AUTH-201, AUTH-202
EOF

gh issue create --title "[AUTH-203] Auth Flow Testing & Validation" \
                --body-file /tmp/auth-203.md \
                --label "priority/high,phase/auth,team/qa" \
                --assignee @qa-lead

# Week 3 Daily Quests issues
cat > /tmp/quest-301.md << 'EOF'
## [QUEST-301] Daily Quests API Endpoint

**Team:** Backend @backend-lead  
**Priority:** #priority/high  
**Phase:** #phase/features  
**Estimate:** 3 days

### Dependencies
- #201 JWT Verification Middleware

### Tasks
- [ ] Build `/api/sync/daily-quests` endpoint
- [ ] Implement server-side quest generation
- [ ] Add quest completion validation
- [ ] Create quest progression tracking
- [ ] Add comprehensive logging

### Acceptance Criteria
- Daily quests endpoint working with authentication
- Server-side quest generation consistent and reliable
- Quest completion properly validated
- Progression tracking accurate across sessions
- All operations logged for debugging

**Blocks:** QUEST-302 (Flutter needs working API)
**Blocked by:** AUTH-201
EOF

gh issue create --title "[QUEST-301] Daily Quests API Endpoint" \
                --body-file /tmp/quest-301.md \
                --label "priority/high,phase/features,team/backend" \
                --assignee @backend-lead

cat > /tmp/quest-302.md << 'EOF'
## [QUEST-302] Flutter Sync Queue Implementation  

**Team:** Frontend @frontend-lead  
**Priority:** #priority/high  
**Phase:** #phase/features  
**Estimate:** 3 days

### Dependencies
- #301 Daily Quests API Endpoint
- #202 Flutter Auth Service with Token Refresh

### Tasks
- [ ] Implement adaptive sync queue service
- [ ] Add offline-first sync with exponential backoff
- [ ] Create optimistic UI updates
- [ ] Build conflict resolution logic
- [ ] Add sync status indicators

### Acceptance Criteria
- Sync queue functional with adaptive scheduling
- Offline sync works and syncs when online
- UI updates immediately (optimistic)
- Conflicts resolved without data loss
- Users can see sync status and errors

**Blocks:** QUEST-303 (Testing needs implementation)
**Blocked by:** QUEST-301, AUTH-202
EOF

gh issue create --title "[QUEST-302] Flutter Sync Queue Implementation" \
                --body-file /tmp/quest-302.md \
                --label "priority/high,phase/features,team/frontend" \
                --assignee @frontend-lead

cat > /tmp/quest-303.md << 'EOF'
## [QUEST-303] Adaptive Polling & Push Integration

**Team:** Frontend @frontend-lead  
**Priority:** #priority/high  
**Phase:** #phase/features  
**Estimate:** 2 days

### Dependencies
- #302 Flutter Sync Queue Implementation

### Tasks
- [ ] Implement quantified polling schedule
- [ ] Add server hints API integration
- [ ] Build push notification handlers
- [ ] Create activity-based polling adjustment
- [ ] Test battery impact and data usage

### Acceptance Criteria
- Polling adapts based on activity and server hints
- Push notifications trigger immediate sync
- Battery usage reduced by 35%+ vs fixed
- Data usage reduced by 39%+ vs fixed
- User experience responsive to partner activity

**Blocks:** DUAL-401 (Dual-write needs working sync)
**Blocked by:** QUEST-302
EOF

gh issue create --title "[QUEST-303] Adaptive Polling & Push Integration" \
                --body-file /tmp/quest-303.md \
                --label "priority/high,phase/features,team/frontend" \
                --assignee @frontend-lead

echo "✅ Phase 1 Issues Created (10 total)"

# Step 3: Project Milestones
echo "🎯 Creating Milestones..."

# Create milestone for Phase 1
gh milestone create --title "Phase 1: Infrastructure & Authentication" \
                    --description "Week 1-3: Set up foundation including JWT auth, database, and pilot feature" \
                    --due-date "$(date -d '+3 weeks' +%Y-%m-%d)"

# Add issues to milestone (this would need to be done via GitHub API or manual)
echo "📝 NOTE: Add all INFRA, AUTH, QUEST issues to Phase 1 milestone manually"

echo "✅ Milestone created"

# Step 4: Project Board Setup
echo "📋 Setting up Project Board..."

cat > /tmp/project-setup.json << 'EOF'
{
  "name": "Migration Progress Board",
  "body": "Project board for Firebase to PostgreSQL migration",
  "public": false,
  "views": [
    {
      "name": "By Phase",
      "layout": "board_layout",
      "filters": [],
      "group_by": "phase",
      "sort_by": "priority"
    },
    {
      "name": "By Team", 
      "layout": "board_layout",
      "filters": [],
      "group_by": "team",
      "sort_by": "priority"
    },
    {
      "name": "By Status",
      "layout": "board_layout", 
      "filters": [],
      "group_by": "status",
      "sort_by": "created_at"
    }
  ],
  "columns": [
    {
      "name": "🆕 Backlog",
      "only_issues_for_project_repo": false
    },
    {
      "name": "🔄 In Progress",
      "only_issues_for_project_repo": false
    },
    {
      "name": "👀 Review",
      "only_issues_for_project_repo": false
    },
    {
      "name": "✅ Done", 
      "only_issues_for_project_repo": false
    },
    {
      "name": "🚫 Blocked",
      "only_issues_for_project_repo": false
    }
  ]
}
EOF

echo "📝 Create project board manually in GitHub with the above configuration"

# Step 5: Workflow Setup
echo "⚙️  Creating GitHub Actions workflows..."

# Create progress report workflow
mkdir -p .github/workflows

cat > .github/workflows/migration-progress.yml << 'EOF'
name: Migration Progress Update

on:
  schedule:
    - cron: '0 9 * * 1' # Monday 9am
  workflow_dispatch:

jobs:
  update-progress:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Generate Progress Report
        run: |
          echo "# Migration Progress Report" > progress-report.md
          echo "Generated on: $(date)" >> progress-report.md
          
          # Count issues by status
          echo "## Issue Status Summary" >> progress-report.md
          echo "- Total Issues: $(gh issue list --repo $GITHUB_REPOSITORY --json | jq length)" >> progress-report.md
          
          echo "- In Progress: $(gh issue list --repo $GITHUB_REPOSITORY --label 'status/in-progress' --json | jq length)" >> progress-report.md
          
          echo "- Done: $(gh issue list --repo $GITHUB_REPOSITORY --label 'status/done' --json | jq length)" >> progress-report.md
          
          echo "- Blocked: $(gh issue list --repo $GITHUB_REPOSITORY --label 'status/blocked' --json | jq length)" >> progress-report.md
          
          # Count by phase
          echo "## Phase Progress" >> progress-report.md
          for phase in infra auth features validation cutover; do
            count=$(gh issue list --repo $GITHUB_REPOSITORY --label "phase/$phase" --json | jq length)
            done=$(gh issue list --repo $GITHUB_REPOSITORY --label "phase/$phase,status/done" --json | jq length)
            echo "- $phase: $done/$count complete" >> progress-report.md
          done
          
      - name: Create Progress Issue
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('progress-report.md', 'utf8');
            
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `Migration Progress - ${new Date().toISOString().split('T')[0]}`,
              body: report,
              labels: ['status/review', 'team/pm']
            });
EOF

# Create issue templates
mkdir -p .github/ISSUE_TEMPLATE

cat > .github/ISSUE_TEMPLATE/migration_task.md << 'EOF'
---
name: Migration Task
about: Create a task for the migration project
title: '[PREFIX-XXX] Brief task description'
labels: ['team/backend', 'phase/infra', 'priority/high']
assignees: @github-username
---

## Task Details
**Epic:** [Link to related epic]
**Phase:** [Infrastructure/Auth/Features/etc]
**Team:** [Backend/Frontend/DevOps/QA]

## Acceptance Criteria
- [ ] Criteria 1
- [ ] Criteria 2
- [ ] Criteria 3

## Dependencies
- Linked Issue #xxx
- Prerequisite work complete

## Estimation
**Time:** [X days]
**Complexity:** [Low/Medium/High]

## Definition of Done
- [ ] Code implemented
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] Code review completed
- [ ] Deployed to staging/test environment
EOF

echo "✅ GitHub Actions and issue templates created"

# cleanup
rm -f /tmp/infra-*.md /tmp/auth-*.md /tmp/quest-*.md /tmp/project-setup.json

echo ""
echo "🎉 GitHub Migration Project Setup Complete!"
echo ""
echo "📋 Next Steps:"
echo "1. Create GitHub Project board with provided configuration"
echo "2. Add created issues to Phase 1 milestone"
echo "3. Configure project board columns and views"
echo "4. Assign team members to appropriate issues"
echo "5. Begin work on highest priority issues (critical without dependencies)"
echo ""
echo "📊 Progress Tracking:"
echo "- Check project board for real-time status"
echo "- Monday 9am: Automated progress reports"
echo "- Use labels for filtering and reporting"
echo "- Set up notifications for critical issues"
echo ""
echo "✅ Ready to start Week 1: Infrastructure & Authentication phase!"
