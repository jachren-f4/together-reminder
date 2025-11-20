#!/bin/bash

# Cloud Automation Setup Script
# Enable AI agents to work 24/7 without your computer

echo "🌐 Setting up Cloud AI Automation..."
echo "This enables your AI agents to work 24/7 without keeping your computer on!"
echo ""

# Check GitHub CLI authentication
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI not authenticated. Please run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"

# Step 1: Commit cloud automation workflows
echo "📝 Committing cloud automation workflows..."
if [ -z "$(git status --porcelain .github/workflows)" ]; then
    echo "   Workflows already committed"
else
    git add .github/workflows/ai-cloud-automation.yml
    git commit -m "Add cloud AI automation workflows 🤖"
    git push
    echo "   ✅ Cloud workflows committed and pushed"
fi

# Step 2: Set up GitHub repository secrets
echo "🔐 Setting up GitHub repository secrets..."

echo "   You'll need to add these secrets to your GitHub repository:"
echo ""
echo "   1. Go to: https://github.com/your-org/togetherremind/settings/secrets/actions"
echo "   2. Add these secrets:"
echo ""

# Create .env file for reference
cat > .env.github-secrets << 'EOF'
# GitHub Repository Secrets to Add:

# 1. GitHub Token (Personal Access Token)
Name: GITHUB_TOKEN
Value: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Scope: repo, issues:write, pull-requests:write

# 2. AI Agent API Keys
Name: ANTHROPIC_API_KEY  
Value: sk-ant-api03-xxxxxxxxxxxxxxxxxxxxxxxxxxxx
Purpose: Claude API access

Name: OPENAI_API_KEY
Value: sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxx
Purpose: Codex API access

Name: SONNET_API_KEY
Value: sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Purpose: Sonnet API access

# Optional: Notification Settings
Name: SLACK_WEBHOOK_URL
Value: https://hooks.slack.com/services/xxxxxxxx/xxxxxxxx/xxxxxxxx
Purpose: Notify when AI agents complete work

# Instructions:
# 1. Go to the GitHub repository settings
# 2. Navigate to Settings → Secrets and variables → Actions
# 3. Click "New repository secret" for each item above
# 4. Paste the actual API key values
# 5. Save each secret
EOF

echo "   📋 Created .env.github-secrets with setup instructions"
echo "   ⚠️  PLEASE ADD these secrets to your GitHub repository!"

# Step 3: Enable the workflow
echo "🔄 Enabling cloud automation workflow..."
echo "   The workflow is already enabled by default in the YAML file"
echo "   ⏰ Schedule: Every 5 min (business hours) / 15 min (off hours)"

# Step 4: Test the automation
echo "🧪 Testing cloud automation setup..."
echo ""
echo "   You can test the automation by running:"
echo "   gh workflow run ai-agent-automation -f main"
echo "   # Or go to GitHub → Actions → 'AI Agent Cloud Automation' → Run workflow"

# Step 5: Create monitoring automation 
echo "📊 Setting up progress monitoring..."

# Create a daily report issue for tracking
cat > /tmp/daily-report-setup.md << 'EOF'
## 🤖 AI Cloud Automation Daily Report

**Repository:** togetherremind  
**Setup Date:** $(date +%Y-%m-%d)  
**Status:** Ready for activation

### Automation Schedule
- **Business Hours:** Every 5 minutes (9am-5pm, Mon-Fri)
- **Off Hours:** Every 15 minutes (Nights & Weekends)
- **Manual Trigger:** Available anytime via GitHub Actions

### Agent Capabilities
- **Sonnet (Flutter):** Flutter/Dart/Mobile development
- **Codex (Backend):** Next.js/PostgreSQL/Infrastructure
- **Claude (Architecture):** Code review & documentation

### Expected Behavior
1. Newly created/labeled issues automatically assigned to appropriate AI agent
2. AI agents process 1-2 issues per 5-minute run
3. Pull requests created and reviewed automatically
4. Issues updated with progress and completion status
5. Daily status reports generated

### Monitoring
- Watch for "🤖 AI Automation Status" issues in repository
- Check GitHub Actions for workflow runs
- Monitor pull requests for AI-generated code
- Review issue comments for AI progress updates

### Human Intervention Points
- **Pull Request Merges:** Always require human approval
- **Blocked Issues:** AI automatically requests help
- **Critical Failures:** Manual troubleshooting required
- **Security Decisions:** Human oversight maintained

### Quick Test Commands
```bash
# Trigger immediate run of all agents
gh workflow run ai-agent-automation -f main

# Run specific agent
gh workflow run ai-agent-automation -f main --field agent_type=sonnet

# Check recent workflow runs
gh run list --workflow=.github/workflows/ai-cloud-automation.yml --limit=10
```

This automation enables your AI agents to work 24/7 without requiring your computer to stay on!
EOF

# Create initial tracking issue
gh issue create \
    --title "🤖 AI Cloud Automation - Daily Report ($(date +%Y-%m-%d))" \
    --body-file /tmp/daily-report-setup.md \
    --label "ai-automation,monitoring,daily-report" \
    --assignee $(git config user.name)

echo "   📝 Created tracking issue for daily monitoring"

rm -f /tmp/daily-report-setup.md

echo ""
echo "🎉 Cloud AI Automation Setup Complete!"
echo ""
echo "🌐 Your AI agents can now work 24/7 - computer NOT required! 🚀"
echo ""
echo "📋 Final Steps:"
echo "   1. Add GitHub secrets (see .env.github-secrets for details)"
echo "   2. Test the workflow: gh workflow run ai-agent-automation -f main"
echo "   3. Monitor GitHub Actions for AI agent progress"
echo "   4. Review pull requests as they're created"
echo ""
echo "⏱️  Next automation run: Within 5 minutes"
echo "📊 Daily reports will appear as GitHub issues"
echo ""
echo "✅ Your migration is now truly autonomous!"
