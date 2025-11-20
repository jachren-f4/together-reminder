# Manual Issue Workflow with Droid/Factory.ai

**Goal:** Complete all migration issues efficiently using Factory.ai (Droid) in focused sessions

**Time Required:** 1-2 hours/day for 2-3 weeks

---

## Daily Workflow (60-90 minutes)

### Morning Session Structure

```bash
# 1. Navigate to project
cd /Users/joakimachren/Desktop/togetherremind

# 2. Check current status
gh issue list --label "priority/critical,priority/high" --json number,title,labels

# 3. Identify next unblocked issue
# Look for issues WITHOUT "status/blocked" or "status/in-progress" labels
```

### Issue Processing Pattern

For each issue (repeat 2-3 times per session):

#### **Step 1: Open Issue Context (2 min)**
```bash
# View issue details
gh issue view 2

# Or open in browser
gh issue view 2 --web
```

#### **Step 2: Tell Droid to Implement (30-40 min)**

Open Factory.ai and say:

```
"Implement GitHub issue #2: Create Vercel and Supabase projects

Context:
- Follow the specs in docs/MIGRATION_TO_NEXTJS_POSTGRES.md
- Use the database schema from docs/MIGRATION_TO_NEXTJS_POSTGRES.md
- Reference CODEX_ITERATION_2_SOLUTIONS.md for production patterns

Tasks:
1. Create Vercel project
2. Create Supabase project  
3. Set up environment variables
4. Deploy initial database schema
5. Create health check endpoint
6. Document setup in README

When done:
- Run all tests
- Create a PR that closes #2
- Ensure all checks pass
"
```

**Droid will:**
- Read all referenced docs
- Implement the solution
- Test the code
- Create a commit and PR
- Link it to the issue

#### **Step 3: Review Droid's Work (5-10 min)**
```bash
# Check the PR Droid created
gh pr list

# Review changes
gh pr view 1 --web

# Check if tests passed
gh pr checks 1
```

#### **Step 4: Merge and Close (2 min)**
```bash
# If everything looks good
gh pr merge 1 --squash --delete-branch

# Verify issue was closed
gh issue view 2
```

#### **Step 5: Move to Next Issue**

Repeat steps 1-4 for the next priority issue.

---

## Weekly Schedule

### **Week 1: Infrastructure (Issues #2, #4, #3)**

**Day 1-2: INFRA-101 - Vercel + Supabase**
- Session 1: Set up Vercel project
- Session 2: Set up Supabase + database schema

**Day 3-4: INFRA-102 - Database Schema**
- Session 1: Deploy full schema with indexes
- Session 2: Set up RLS policies and test

**Day 5: INFRA-103 - Monitoring**
- Session 1: Health checks and monitoring setup

### **Week 2: Authentication (Issues #5, #6, #7)**

**Day 1-2: AUTH-201 - JWT Middleware**
- Session 1: Implement middleware
- Session 2: Test and validate

**Day 3-4: AUTH-202 - Flutter Auth**
- Session 1: Auth service implementation
- Session 2: Token refresh and storage

**Day 5: AUTH-203 - Testing**
- Session 1: Integration tests and load testing

### **Week 3: Complete Phase 1**
- Cleanup and documentation
- Prepare Phase 2 issues

---

## Efficiency Tips

### **Batch Similar Issues**
Group related issues in one session:
```
Session 1: All database-related issues
Session 2: All Flutter/frontend issues
Session 3: All API endpoint issues
```

### **Use Templates for Droid**
Create prompt templates for common issue types:

**Backend API Template:**
```
"Implement issue #X: [Title]

Follow patterns from:
- docs/MIGRATION_TO_NEXTJS_POSTGRES.md (API design)
- docs/CODEX_ITERATION_2_SOLUTIONS.md (production patterns)

Requirements:
1. [List from issue]
2. [...]

Create:
- API endpoint with TypeScript types
- Database queries with proper indexing
- Error handling and logging
- Integration tests
- API documentation

Test:
- Run npm test
- Check TypeScript compilation
- Test with curl/Postman

Create PR that closes #X"
```

**Flutter Feature Template:**
```
"Implement issue #X: [Title]

Follow patterns from existing Flutter code in lib/

Requirements:
1. [List from issue]
2. [...]

Create:
- Service classes with proper architecture
- UI widgets following Material Design
- State management (Provider/Riverpod)
- Error handling and loading states
- Widget tests

Test:
- Run flutter test
- Check flutter analyze
- Test on iOS/Android simulator

Create PR that closes #X"
```

### **Parallel Work**
While Droid works on one issue, you can:
- Review previous PRs
- Plan next session
- Update project documentation
- Communicate with stakeholders

---

## Progress Tracking

### Daily Log
Keep a simple log:

```markdown
## Week 1 Progress

### Monday 2025-11-19
- ✅ INFRA-101 Complete (PR #1 merged)
- 🚧 INFRA-102 In Progress (50% done)
- Time: 90 minutes

### Tuesday 2025-11-20  
- ✅ INFRA-102 Complete (PR #2 merged)
- ✅ INFRA-103 Complete (PR #3 merged)
- Time: 120 minutes

[...]
```

### Velocity Tracking
After Week 1, you'll know:
- How many issues per session
- Typical time per issue
- Which issue types take longer

Adjust estimates accordingly.

---

## Advantages of This Approach

✅ **No Additional Costs** - Using Factory.ai you already have

✅ **Full Control** - You review every change before merge

✅ **Learn as You Go** - Understand each implementation

✅ **Flexible Schedule** - Work when convenient

✅ **High Quality** - Human oversight prevents mistakes

✅ **Context Retained** - Droid has full project context

---

## Expected Timeline

**With 1 hour/day:**
- Week 1-3: Phase 1 (Infrastructure + Auth) ✅
- Week 4-5: Phase 2 (Dual-write validation) ✅
- Week 6-8: Phase 3 (Feature migration) ✅
- Week 9-10: Phase 4 (Testing and polish) ✅

**Total: ~10 weeks vs 14 weeks autonomous**

**With 2 hours/day:**
- Complete entire migration in ~6-7 weeks

---

## Emergency Fast-Track

If you need faster completion, dedicate 1 full day:

**Saturday Power Session (6-8 hours):**
- Morning: Complete all infrastructure issues
- Afternoon: Complete all auth issues
- Evening: Start feature migration

You could complete **Phase 1 in a weekend** this way.

---

## Conclusion

This manual-with-Droid approach gives you:
- **Speed** of AI implementation
- **Control** of human oversight
- **Cost-effectiveness** (no additional APIs)
- **Flexibility** (work on your schedule)

It's the best balance for a solo developer or small team completing a major migration.
