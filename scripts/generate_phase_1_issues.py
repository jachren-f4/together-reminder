#!/usr/bin/env python3
"""
Generate Phase 1 GitHub Issues for Firebase → PostgreSQL Migration
"""

import argparse
import subprocess
import sys
import json
import os

def create_issue(title, body, labels, assignee):
    """Create a GitHub issue using gh CLI"""
    cmd = ['gh', 'issue', 'create', '--title', title, '--body', body]
    
    # Add labels
    if labels:
        cmd.extend(['--label', ','.join(labels)])
    
    # Add assignee
    if assignee:
        cmd.extend(['--assignee', assignee])
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        # Extract issue number from output (gh returns URL in success case)
        if result.returncode == 0:
            output_lines = result.stdout.strip().split('\n')
            for line in output_lines:
                if 'github.com' in line and '/issues/' in line:
                    issue_number = line.split('/issues/')[-1].split('#')[-1]
                    return result.stdout.strip(), int(issue_number)
        return result.stdout.strip(), None
    except subprocess.CalledProcessError as e:
        print(f"Error creating issue '{title}': {e.stderr}")
        return None, None

def generate_phase_1_issues():
    """Generate all Phase 1 migration issues"""
    
    print("📝 Generating Phase 1 GitHub Issues...")
    
    # Get GitHub username
    try:
        username_result = subprocess.run(['gh', 'api', 'user', '--jq', '.login'], 
                                     capture_output=True, text=True, check=True)
        github_username = username_result.stdout.strip().strip('"')
    except:
        github_username = "your-github-username"  # Fallback
    
    # Repository name
    repo_name = "togetherremind"
    
    # Build issue URLs for reference
    base_repo_url = f"{github_username}/{repo_name}"
    
    issues = [
        {
            "prefix": "INFRA-101",
            "title": "Create Vercel & Supabase Projects",
            "body": f"""## [INFRA-101] Create Vercel & Supabase Projects

**Team:** DevOps  
**Priority:** 🚨 Critical  
**Phase:** 🏗️ Infrastructure  
**Estimate:** 2 days

### 📋 Tasks
- [ ] Create Vercel project with Next.js boilerplate
- [ ] Create Supabase project with PostgreSQL
- [ ] Configure database connection URLs  
- [ ] Set up environment variables management
- [ ] Run initial database schema migration

### ✅ Acceptance Criteria
- [ ] Vercel project deployed and accessible
- [ ] Supabase project with PostgreSQL running
- [ ] Database schemas created and tested
- [ ] Environment variables properly configured
- [ ] Basic connectivity verified

### 🔗 Dependencies
- Environment documentation complete

### 🚀 Next Steps
- Add pull request to INFRA-102 when complete
- Update with Vercel and Supabase connection details
- Document access credentials management

**Repository Issues:** https://github.com/{base_repo_url}/issues

### 💬 Notes
This is Issue #1 of the migration project. All subsequent infrastructure tasks depend on these foundational services being set up correctly.
""",
            "labels": ["priority/critical", "phase/infra", "team/devops"],
            "assignee": None  # Update with actual usernames later
        },
        {
            "prefix": "INFRA-102", 
            "title": "Database Schema & Indexing",
            "body": f"""## [INFRA-102] Database Schema & Indexing

**Team:** Backend  
**Priority:** 🚨 Critical  
**Phase:** 🏗️ Infrastructure  
**Estimate:** 3 days

### 🔗 Dependencies
- INFRA-101: Create Vercel & Supabase Projects

### 📋 Tasks
- [ ] Execute complete migration SQL with proper indexes
- [ ] Set up Row Level Security (RLS) policies
- [ ] Create connection pool monitoring tables
- [ ] Validate database constraints and uniqueness
- [ ] Test connection limits with load simulation

### ✅ Acceptance Criteria
- [ ] All database tables created with proper indexes
- [ ] RLS policies working correctly for security
- [ ] Connection pool monitoring functional
- [ ] Load testing up to 100 connections successful
- [ ] Performance benchmarks established (< 200ms queries)

### 📊 Success Metrics
- Table creation success rate: 100%
- RLS policy coverage: All tables secured
- Connection pool efficiency: < 80% utilization under load
- Query performance: All queries under 200ms target

### 🔍 Technical Details

**Critical Tables:**
- `couples` (user relationships)
- `daily_quests` (main feature data)
- `love_point_awards` (gamification)
- `quiz_sessions` (interactive content)
- `memory_puzzles` (daily games)

**Index Strategy:**
- Primary keys + foreign key indexes
- Composite indexes for frequent query patterns
- Partial indexes for active data only

**RLS Policies:**
- Users can only access their couple's data
- Couples can only access their shared data
- Audit logging for all data access

### 🗄️ Database Migration
```sql
-- Main schema file: docs/database_schema.sql
-- Run with: psql -h postgres.xxx.supabase.co -U postgres -d postgres -f database_schema.sql
```

### ⚠️ Critical Success Factors
- Schema must support both Flutter and Next.js access patterns
- Security policies must prevent cross-couple data leakage
- Performance under load is critical for migration success
```,
            "labels": ["priority/critical", "phase/infra", "team/backend"],
            "assignee": None
        },
        {
            "prefix": "INFRA-103",
            "title": "Monitoring & Alerting Infrastructure", 
            "body": f"""## [INFRA-103] Monitoring & Alerting Infrastructure

**Team:** DevOps  
**Priority:** 🔥 High  
**Phase:** 🏗️ Infrastructure  
**Estimate:** 2 days

### 🔗 Dependencies
- INFRA-101: Create Vercel & Supabase Projects

### 📋 Tasks
- [ ] Set up Sentry error tracking for Flutter app
- [ ] Create health check endpoints for Next.js APIs
- [ ] Configure Prometheus metrics collection
- [ ] Set up alert thresholds (DB connections, API latency)
- [ ] Create monitoring dashboards (Grafana)

### ✅ Acceptance Criteria
- [ ] Sentry integrated and receiving error telemetry
- [ ] Health endpoints accessible and reporting system status  
- [ ] Prometheus metrics collection working for all services
- [ ] Alert thresholds configured and tested thoroughly
- [ ] Grafana dashboards displaying real-time system health

### 📊 Monitoring Targets

**Application Metrics:**
- API response times (< 200ms p95)
- Error rates (< 1%)
- Database connection usage (< 80% of limit)
- Active users and sessions
- Sync success rates

**Infrastructure Metrics:**
- Vercel function cold starts
- Database query performance
- Supabase service health
- GitHub Actions workflow success

### 🚨 Alert Scenarios

**Critical Alerts:**
- Database error rate > 5% (1 minute window)  
- API latency > 500ms sustained (5 minute window)
- Authentication failures > 2% (10 minute window)
- Database connections > 90% usage (15 minute window)

**Warning Alerts:**
- API latencies > 200ms sustained (15 minute window)
- Error rates > 0.5% (1 hour window) 
- Failed workflow runs > 2 consecutive

### 🔧 Implementation Details

**Health Endpoints:**
```
/api/health/system - Overall system health
/api/health/database - Database connectivity 
/api/health/auth - Authentication status
/api/health/sync - Sync service status
```

**Dashboards:**
- System Overview (real-time key metrics)
- Database Performance (queries, connections, indexes)
- API Performance (endpoints, errors, latency)  
- Migration Progress (issues, milestones, completion)

### 🔗 Repository Files
- **Monitoring config:** `.github/workflows/monitoring.yml`
- **Health endpoints:** `app/api/health/*.ts`
- **Dashboard definitions:** `monitoring/grafana/`

### 🎯 Success Criteria
- 100% system health visibility
- < 5 minute alert response time
- 99% alert accuracy (no false alarms)
- Team notification system operational
"""
},
            "labels": ["priority/high", "phase/infra", "team/devops"],
            "assignee": None
        }
    ]
    
    return issues

def main():
    parser = argparse.ArgumentParser(description='Generate Phase 1 migration issues')
    parser.add_argument('--dry-run', action='store_true', help='Print issues without creating')
    parser.add_argument('--github-username', help='Override github username detection')
    
    args = parser.parse_args()
    
    issues = generate_phase_1_issues()
    created_issues = []
    
    print(f"📝 Creating {len(issues)} Phase 1 GitHub Issues...")
    
    for issue in issues:
        title = f"[{issue['prefix']}] {issue['title']}"
        
        if args.dry_run:
            print(f"\n📋 DRY RUN - Would create:")
            print(f"Title: {title}")
            print(f"Labels: {', '.join(issue['labels'])}")
            if issue['assignee']:
                print(f"Assignee: {issue['assignee']}")
            print(f"Body length: {len(issue['body'])} characters")
        else:
            print(f"📝 Creating: {issue['prefix']}...")
            result, issue_number = create_issue(
                title=title,
                body=issue['body'],
                labels=issue['labels'],
                assignee=issue['assignee']
            )
            
            if result and issue_number:
                created_issues.append({
                    'prefix': issue['prefix'],
                    'title': issue['title'],
                    'url': result,
                    'number': issue_number
                })
                print(f"✅ Created: #{issue_number} - {result}")
            else:
                print(f"❌ Failed to create: {issue['title']}")
    
    if not args.dry_run:
        print(f"\n🎉 Created {len(created_issues)} Phase 1 issues!")
        
        print(f"\n📊 Created Issues Summary:")
        for issue in created_issues:
            print(f"  - #{issue['number']}: {issue['prefix']} - {issue['url']}")
        
        print(f"\n📋 Next Steps:")
        print(f"1. Visit https://github.com/{os.getenv('GITHUB_REPOSITORY')}/issues")
        print(f"2. Review and assign team members to the issues")
        print(f"3. Create Phase 1 milestone and add issues to it") 
        print(f"4. Start with INFRA-101 (no dependencies)")
        
        print(f"\n🏗️ Critical Path:")
        print(f"→ INFRA-101 → INFRA-102 → INFRA-103")
        print(f"→ AUTH-201 → AUTH-202 → AUTH-203")  
        print(f"→ QUEST-301 → QUEST-302 → QUEST-303")
        
        print(f"\n🔗 Repository Issues: https://github.com/{os.getenv('GITHUB_REPOSITORY')}/issues")
    else:
        print(f"\n📋 DRY RUN complete for {len(issues)} issues")
        print(f"Run without --dry-run to actually create issues")

if __name__ == '__main__':
    main()
