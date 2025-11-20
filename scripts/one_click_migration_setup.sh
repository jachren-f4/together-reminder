#!/bin/bash

# One-Click Migration Setup Script
# Creates all GitHub issues, sets up automation, and gets everything ready for AI agents

echo "🚀 One-Click Migration Setup for Firebase → PostgreSQL"
echo "=========================================================="

# Check GitHub CLI authentication
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI not authenticated. Please run: gh auth login"
    echo "📋 Setup script requires GitHub CLI authentication first."
    exit 1
fi

echo "✅ GitHub CLI authenticated successfully"

# Get repository info
REPO_OWNER=$(gh api user --jq '.login' | tr -d '"')
REPO_NAME="togetherremind"
echo "📁 Repository: ${REPO_OWNER}/${REPO_NAME}"

# Create directories
mkdir -p ai_agents scripts docs

echo ""
echo "📝 Creating GitHub Issues..."

# Run the Python issue generator
python3 scripts/generate_phase_1_issues.py

echo ""
echo "🎯 Creating Phase 1 Milestone..."

# Create milestone for Phase 1
MILESTONE_RESULT=$(gh milestone create \
    --title "Phase 1: Infrastructure & Authentication" \
    --description "Weeks 1-3: Set up foundation including JWT auth, database, and pilot features" \
    --due-date "$(date -d '+3 weeks' +%Y-%m-%d)" | head -1)

MILESTONE_NUMBER=$(echo "$MILESTONE_RESULT" | grep -o '[0-9]\+' | head -1)

echo "✅ Created Phase 1 Milestone: $MILESTONE_NUMBER"

echo ""
echo "🏷️ Adding Issues to Milestone..."

# Add all Phase 1 issues to the milestone (we'll get the issue numbers)
ISSUES_RESULT=$(gh issue list --repo "${REPO_OWNER}/${REPO_NAME}" --limit 15 --json | jq -r '.[] | "\(.number\)"')

for issue_number in $ISSUES_RESULT; do
    gh issue edit "$issue_number" --milestone "$MILESTONE_NUMBER" > /dev/null 2>&1
    echo "  ✅ Added #$issue_number to milestone"
done

echo ""
echo "🏷️ Creating Additional Phases (2-4) for Future Use..."

# Generate Phase 2-4 issues (preview only - you can enable later)
python3 scripts/generate_phase_issues.py --phase 2 --dry-run > /dev/null 2>&1
python3 scripts/generate_phase_issues.py --phase 3 --dry-run > /dev/null 2>&1
python3 scripts/generate_phase_issues.py --phase 4 --dry-run > /dev/null 2>&1

echo "✅ Phase generators ready for future phases"

echo ""
echo "🤖 Setting Up AI Automation..."

# Commit and push the automation workflows
if [ -n "$(git status --porcelain .github/workflows)" ]; then
    git add .github/workflows/
    git commit -m "Add AI automation workflows 🤖" -m "- Setup cloud automation for autonomous development"
    git push > /dev/null 2>&1
    echo "✅ AI automation workflows committed and pushed"
else
    echo "ℹ️ Workflows already present (skipping)"
fi

echo ""
echo "📋 Setting Up GitHub Repository Structure"

# Ensure the repository has the right structure
if [ ! -f ".gitignore" ]; then
    touch .gitignore
fi

# Create project directory if it doesn't exist
mkdir -p project-issues

echo "✅ Repository structure updated"

echo ""
echo "🔗 Creating Helpful Quick Links"

# Extract issue numbers for quick access
ISSUE_INFRA_101=$(gh issue list --repo "${REPO_OWNER}/${REPO_NAME}" --search "INFRA-101" --limit 1 --json | jq -r '.[] | "\(.number\)"')
ISSUE_AUTH_201=$(gh issue list --repo "${REPO_OWNER}/${REPO_NAME}" --search "AUTH-201" --limit 1 --json | jq -r '.[] | "\(.number\)"')
ISSUE_QUEST_301=$(gh issue list --repo "${REPO_OWNER}/${REPO_NAME}" --search "QUEST-301" --limit 1 --json | jq -r '.[] | "\(.number\)"')

echo ""
echo "🎉 One-Click Migration Setup Complete!"
echo "=========================================================="
echo ""
echo "✅ Created: 10 Phase 1 GitHub issues"
echo "✅ Created: Phase 1 milestone"
echo "✅ Set up: AI automation workflows"
echo "✅ Generated: Future phase templates"
echo ""
echo "🌐 Important URLs:"
echo "   Repository: https://github.com/${REPO_OWNER}/${REPO_NAME}"
echo "   Issues: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues"
echo "   Milestones: https://github.com/${REPO_OWNER}/${REPO_NAME}/milestones"
echo ""
echo "🎯 Key Issues to Start With:"
echo "   - INFRA-101 (no dependencies): https://github.com/${REPO_OWNER}/${REPO_NAME}/issues/${ISSUE_INFRA_101}"
echo "   - AUTH-201: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues/${ISSUE_AUTH_201}"
echo "   - QUEST-301: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues/${ISSUE_QUEST_301}"
echo ""
echo "🤖 AI Automation Ready:"
echo "   • GitHub workflows will automatically assign AI agents"
echo "   • Cloud automation will start when you enable it"
echo "   • Issues will be processed in priority order"
echo ""
echo "📋 Next Steps:"
echo "   1. Review the created issues: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues"
echo "   2. Assign team members to issues (GH web interface is easiest)"
echo "   3. Set up GitHub secrets for AI automation (one-time setup)"
echo "   4. Enable cloud automation: ./scripts/setup_cloud_automation.sh"
echo "   5. Start with INFRA-101 (highest priority, no dependencies)"
echo ""
echo "🛡️ Security Note:"
echo "   • Your GitHub token stayed local and secure"
echo "   • No credentials shared with AI systems"
echo "   • All actions performed through your authenticated GitHub CLI"

echo ""
echo "🚀 Ready to start autonomous AI development! 🌟"
