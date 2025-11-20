#!/usr/bin/env python3
"""
Generate GitHub Issues for Migration Phases
Usage: python scripts/generate_phase_issues.py --phase <phase-number>
"""

import argparse
import json
import subprocess
import sys

def create_issue(title, body, labels, assignee=None):
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
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error creating issue '{title}': {e.stderr}")
        return None

def generate_phase_2_issues():
    """Generate Dual-Write Validation (Weeks 4-5) issues"""
    
    issues = [
        {
            "prefix": "DUAL-401",
            "title": "Dual-Write Sync Implementation",
            "body": """
## [DUAL-401] Dual-Write Sync Implementation

**Team:** Backend @backend-lead  
**Priority:** #priority/critical  
**Phase:** #phase/validation  
**Estimate:** 4 days

### Dependencies
- QUEST-303 Adaptive Polling & Push Integration

### Tasks
- [ ] Implement dual-write to RTDB + PostgreSQL
- [ ] Create data comparison service
- [ ] Build drift detection algorithms
- [ ] Add dual-write rollback mechanisms
- [ ] Implement comprehensive logging

### Acceptance Criteria
- All writes go to both RTDB and PostgreSQL successfully
- Data comparison service identifies any discrepancies
- Drift detection alerts within 5 minutes of divergence
- Rollback mechanism can disable PostgreSQL writes instantly
- All operations logged with correlation IDs

### Success Metrics
- <0.1% data drift rate
- <5s average dual-write latency
- 100% write success rate to both systems
- Zero data loss during validation period

**Blocks:** DUAL-402 (Dashboard needs implementation)
            """,
            "labels": ["priority/critical", "phase/validation", "team/backend"],
            "assignee": "@backend-lead"
        },
        {
            "prefix": "DUAL-402", 
            "title": "Data Validation Dashboard",
            "body": """
## [DUAL-402] Data Validation Dashboard

**Team:** DevOps @devops-lead  
**Priority:** #priority/high  
**Phase:** #phase/validation  
**Estimate:** 2 days

### Dependencies
- DUAL-401 Dual-Write Sync Implementation

### Tasks
- [ ] Create data consistency checker
- [ ] Build validation monitoring dashboard
- [ ] Add automated consistency alerts
- [ ] Set up data reconciliation tools
- [ ] Create drift report generation

### Acceptance Criteria
- Real-time consistency checking operational
- Dashboard shows sync status for all data types
- Automated alerts trigger on any divergence
- Reconciliation tools can manually fix discrepancies
- Drift reports generated hourly with statistics

**Blocks:** DUAL-403 (Load testing needs monitoring)
            """,
            "labels": ["priority/high", "phase/validation", "team/devops"],
            "assignee": "@devops-lead"
        },
        {
            "prefix": "DUAL-403",
            "title": "Load Testing Environment", 
            "body": """
## [DUAL-403] Load Testing Environment

**Team:** QA @qa-lead  
**Priority:** #priority/high  
**Phase:** #phase/validation  
**Estimate:** 3 days

### Dependencies
- DUAL-401 Dual-Write Sync Implementation

### Tasks
- [ ] Set up 1K+ simulated couples
- [ ] Create realistic usage patterns
- [ ] Test dual-write under concurrent load
- [ ] Validate data integrity under stress
- [ ] Document performance baselines

### Acceptance Criteria
- Test environment supports 1000+ concurrent couples
- Usage patterns simulate real app behavior
- Dual-write performs under max expected load
- No data corruption or loss during stress testing
- Performance baselines established for all operations

### Success Metrics
- 1000 couples dual-writing simultaneously
- <200ms average write latency under load
- 100% data consistency under stress
- No database connection exhaustion

**Blocks:** VAL-501 (7-day run needs load testing)
            """,
            "labels": ["priority/high", "phase/validation", "team/qa"],
            "assignee": "@qa-lead"
        }
    ]
    
    return issues

def generate_phase_3_issues():
    """Generate Auth Migration (Weeks 6-7) issues"""
    
    issues = [
        {
            "prefix": "MIG-601",
            "title": "Anonymous Account Migration",
            "body": """
## [MIG-601] Anonymous Account Migration

**Team:** Frontend @frontend-lead  
**Priority:** #priority/critical  
**Phase:** #phase/auth  
**Estimate:** 4 days

### Dependencies
- VAL-503 Network Resilience Testing

### Tasks
- [ ] Build anonymous to authenticated flow
- [ ] Create optional email enrollment UI
- [ ] Implement magic link authentication
- [ ] Add multi-device account linking
- [ ] Build migration monitoring dashboard

### Acceptance Criteria
- Anonymous users can migrate to authenticated accounts
- Email enrollment is optional with clear skip option
- Magic link authentication works reliably
- Same account syncing across multiple devices
- Migration progress monitored in real-time

### Success Metrics
- >80% migration completion rate
- <2% authentication error rate during migration
- <5min average time to complete migration
- 100% data preservation during migration

**Blocks:** MIG-602 (Recovery needs migration)
            """,
            "labels": ["priority/critical", "phase/auth", "team/frontend"],
            "assignee": "@frontend-lead"
        },
        {
            "prefix": "MIG-602",
            "title": "Account Recovery & Multi-Device",
            "body": """
## [MIG-602] Account Recovery & Multi-Device

**Team:** Frontend @frontend-lead  
**Priority:** #priority/high  
**Phase:** #phase/auth  
**Estimate:** 3 days

### Dependencies
- MIG-601 Anonymous Account Migration

### Tasks
- [ ] Implement account recovery flows
- [ ] Add device management interface
- [ ] Create cross-device session sync
- [ ] Build authentication troubleshooting tools
- [ ] Test migration edge cases

### Acceptance Criteria
- Users can recover lost access via email
- Device management allows adding/removing devices
- Sessions sync properly across devices
- Troubleshooting tools help common auth issues
- Edge cases handled gracefully

**Blocks:** MIG-603 (App store needs working auth)
            """,
            "labels": ["priority/high", "phase/auth", "team/frontend"],
            "assignee": "@frontend-lead"
        },
        {
            "prefix": "MIG-603",
            "title": "App Store Submission Preparation",
            "body": """
## [MIG-603] App Store Submission Preparation

**Team:** Project Management @pm-lead  
**Priority:** #priority/high  
**Phase:** #phase/auth  
**Estimate:** 2 days

### Dependencies
- MIG-601 Anonymous Account Migration

### Tasks
- [ ] Prepare iOS app store submission
- [ ] Create Google Play submission
- [ ] Document new permissions and changes
- [ ] Write app review communication
- [ ] Set up staged release preparation

### Acceptance Criteria
- iOS submission package ready with all required assets
- Android submission package complete
- Permission changes documented for reviewers
- App review communication professional and clear
- Staged release strategy planned

### Success Metrics
- Submission packages complete and audit-ready
- Review responses prepared for common concerns
- Staged release plan with success criteria
- Support documentation updated for new auth flow

**Blocks:** ROLL-701 (Rollout needs submission)
            """,
            "labels": ["priority/high", "phase/auth", "team/pm"],
            "assignee": "@pm-lead"
        }
    ]
    
    return issues

def generate_phase_4_issues():
    """Generate Authentication Rollout (Weeks 6-7) issues"""
    
    issues = [
        {
            "prefix": "ROLL-701",
            "title": "5% Migration Test",
            "body": """
## [ROLL-701] 5% Migration Test

**Team:** QA @qa-lead  
**Priority:** #priority/critical  
**Phase:** #phase/auth  
**Estimate:** 2 days

### Dependencies
- MIG-603 App Store Submission Preparation

### Tasks
- [ ] Enable migration flow for 5% users
- [ ] Monitor success metrics (>80% target)
- [ ] Track authentication error rates
- [ ] Collect user feedback on migration experience
- [ ] Prepare escalation procedures

### Acceptance Criteria
- Migration flow working for 5% of users
- Success rate >80% as measured by completed migrations
- Authentication error rate <2%
- User feedback collected and analyzed
- Escalation procedures documented and tested

### Rollback Criteria
- Success rate <70%
- Authentication error rate >5%
- User complaints >5 per day
- Migration blocker discovered

**Blocks:** ROLL-702 (Expansion needs test success)
            """,
            "labels": ["priority/critical", "phase/auth", "team/qa"],
            "assignee": "@qa-lead"
        },
        {
            "prefix": "ROLL-702",
            "title": "20% Migration Expansion",
            "body": """
## [ROLL-702] 20% Migration Expansion

**Team:** QA @qa-lead  
**Priority:** #priority/high  
**Phase:** #phase/auth  
**Estimate:** 2 days

### Dependencies
- ROLL-701 5% Migration Test

### Tasks
- [ ] Scale migration to 20% users
- [ ] Monitor authentication performance
- [ ] Validate error rates (<2% target)
- [ ] Analyze user feedback patterns
- [ ] Document migration patterns

### Acceptance Criteria
- Migration flow successfully serving 20% of users
- Performance metrics within targets
- Error rate remains below 2%
- User feedback analyzed and improvements identified
- Migration patterns documented for future phases

### Success Metrics
- 20% of user base migrated successfully
- Authentication performance degradation <10%
- User satisfaction with migration >85%
- Support burden manageable

**Blocks:** ROLL-703 (Full rollout needs expansion success)
            """,
            "labels": ["priority/high", "phase/auth", "team/qa"],
            "assignee": "@qa-lead"
        },
        {
            "prefix": "ROLL-703",
            "title": "Full Migration Execution",
            "body": """
## [ROLL-703] Full Migration Execution

**Team:** QA @qa-lead  
**Priority:** #priority/critical  
**Phase:** #phase/auth  
**Estimate:** 3 days

### Dependencies
- ROLL-702 20% Migration Expansion

### Tasks
- [ ] Enable migration for all users
- [ ] Maintain anonymous fallback for declined users
- [ ] Monitor overall authentication metrics
- [ ] Document final migration results
- [ ] Prepare support documentation

### Acceptance Criteria
- All users have migration flow available
- Anonymous access continues for users who decline
- Migration metrics tracked and reported
- Final results documented comprehensively
- Support team equipped to handle transition

### Success Metrics
- >95% of users successfully migrated
- Anonymous fallback <5% of user base
- Migration completion within timeline
- Support requests manageable during transition
- No data loss during migration process

**Blocks:** Feature migration phase
            """,
            "labels": ["priority/critical", "phase/auth", "team/qa"],
            "assignee": "@qa-lead"
        }
    ]
    
    return issues

def main():
    parser = argparse.ArgumentParser(description='Generate GitHub issues for migration phases')
    parser.add_argument('--phase', type=int, required=True, help='Phase number (2-14)')
    parser.add_argument('--dry-run', action='store_true', help='Print issues without creating')
    
    args = parser.parse_args()
    
    phase_generators = {
        2: generate_phase_2_issues,
        3: generate_phase_3_issues,
        4: generate_phase_4_issues,
    }
    
    if args.phase not in phase_generators:
        print(f"Phase {args.phase} issues not implemented yet")
        print("Available phases: 2, 3, 4")
        sys.exit(1)
    
    issues = phase_generators[args.phase]()
    created_issues = []
    
    print(f"📝 Creating Phase {args.phase} GitHub Issues...")
    
    for issue in issues:
        if args.dry_run:
            print(f"\n📋 DRY RUN - Would create:")
            print(f"Title: {issue['title']}")
            print(f"Labels: {', '.join(issue['labels'])}")
            print(f"Assignee: {issue.get('assignee', 'None')}")
            print(f"Body length: {len(issue['body'])} characters")
        else:
            print(f"📝 Creating: {issue['prefix']}...")
            result = create_issue(
                title=issue['title'],
                body=issue['body'],
                labels=issue['labels'],
                assignee=issue.get('assignee')
            )
            
            if result:
                created_issues.append(result)
                print(f"✅ Created: {result}")
            else:
                print(f"❌ Failed to create: {issue['title']}")
    
    if not args.dry_run:
        print(f"\n🎉 Created {len(created_issues)} issues for Phase {args.phase}")
        print("📋 Remember to:")
        print("1. Add issues to appropriate milestone")
        print("2. Review and assign team members")
        print("3. Set up dependencies between issues")
        print("4. Update project board columns")
    else:
        print(f"\n📋 DRY RUN complete for Phase {args.phase}")
        print("Run without --dry-run to actually create issues")

if __name__ == '__main__':
    main()
