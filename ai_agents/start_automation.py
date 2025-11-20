#!/usr/bin/env python3
"""
AI Development Automation Starter
Run this to start the autonomous AI development system
"""

import asyncio
import os
import sys
from pathlib import Path

# Add ai_agents to Python path
sys.path.append(str(Path(__file__).parent))

try:
    from work_queue_manager import AIAgentManager
    from sonnet_agent import SonnetAgent  
    from codex_agent import CodexAgent
    from claude_agent import ClaudeAgent
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Make sure you're running from the project root directory")
    sys.exit(1)

def check_environment():
    """Verify all required environment variables are set"""
    
    required_vars = [
        "GITHUB_TOKEN",
        "ANTHROPIC_API_KEY", 
        "OPENAI_API_KEY",
        "SONNET_API_KEY"
    ]
    
    missing_vars = []
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)
    
    if missing_vars:
        print(f"❌ Missing environment variables:")
        for var in missing_vars:
            print(f"   - {var}")
        print("\n📋 Set these environment variables:")
        print("   export GITHUB_TOKEN=your_github_token")
        print("   export ANTHROPIC_API_KEY=your_claude_key")
        print("   export OPENAI_API_KEY=your_codex_key")
        print("   export SONNET_API_KEY=your_sonnet_key")
        return False
    
    print("✅ All environment variables configured")
    return True

async def start_ai_development():
    """Start the AI development automation system"""
    
    print("🚀 Starting AI Development Automation System...")
    print("=" * 60)
    
    # Initialize work queue manager
    work_queue = AIAgentManager(github_token=os.getenv("GITHUB_TOKEN"))
    
    # Initialize AI agents with their specializations
    print("🤖 Initializing AI Agents...")
    
    sonnet = SonnetAgent(work_queue)
    print("   ✅ Sonnet (Flutter/Agent)")
    
    codex = CodexAgent(work_queue)
    print("   ✅ Codex (Backend/Agent)")
    
    claude = ClaudeAgent(work_queue)
    print("   ✅ Claude (Architecture/Reviewer)")
    
    ai_agents = {
        "sonnet": sonnet,
        "codex": codex, 
        "claude": claude
    }
    
    print(f"📋 AI Agents ready: {', '.join(ai_agents.keys())}")
    print("=" * 60)
    
    # Main processing loop
    iteration_count = 0
    while True:
        iteration_count += 1
        print(f"\n🔄 Iteration {iteration_count} - {len(ai_agents)} agents active")
        
        # Create tasks for all agents to run in parallel
        tasks = []
        for agent_name, agent in ai_agents.items():
            task = asyncio.create_task(
                process_agent_work(agent_name, agent, work_queue),
                name=f"{agent_name}"
            )
            tasks.append(task)
        
        # Wait for all agents to complete this iteration
        try:
            await asyncio.gather(*tasks, return_exceptions=True)
        except Exception as e:
            print(f"❌ Error in agent iteration: {e}")
        
        # Display current status
        await display_system_status(work_queue, ai_agents)
        
        # Interval between work cycles (5 minutes)
        print("⏳ Waiting 5 minutes before next cycle...")
        await asyncio.sleep(300)

async def process_agent_work(agent_name: str, agent, work_queue):
    """Process work for a single AI agent"""
    
    try:
        # Check if agent has assigned issues
        issues = work_queue.get_assigned_issues(agent_name)
        if not issues:
            print(f"🤖 {agent_name}: No assigned issues")
            return
        
        # Find next backlog issue
        next_issue = None
        for issue in issues:
            if issue.status == "backlog":
                next_issue = issue
                break
        
        if not next_issue:
            print(f"🤖 {agent_name}: All issues in progress or completed")
            return
        
        print(f"🤖 {agent_name}: Processing issue #{next_issue.number} - {next_issue.title}")
        
        # Update issue status to in progress
        await work_queue.update_issue_status(next_issue.number, "in_progress")
        
        # Process the issue based on agent type
        if agent_name == "sonnet":
            result = await agent.process_flutter_issue(next_issue)
        elif agent_name == "codex":
            result = await agent.process_backend_issue(next_issue)
        elif agent_name == "claude":
            result = await agent.process_architecture_issue(next_issue)
        
        if result["success"]:
            await work_queue.update_issue_status(next_issue.number, "completed")
            print(f"✅ {agent_name}: Completed issue #{next_issue.number}")
        else:
            await work_queue.update_issue_status(next_issue.number, "blocked")
            print(f"❌ {agent_name}: Failed issue #{next_issue.number} - {result.get('error', 'Unknown error')}")
            
    except Exception as e:
        print(f"❌ {agent_name} error: {e}")

async def display_system_status(work_queue, ai_agents):
    """Display current system status"""
    
    print("\n📊 System Status:")
    
    # Overall metrics
    all_issues = work_queue.get_all_issues()
    status_counts = {"backlog": 0, "in_progress": 0, "completed": 0, "blocked": 0}
    
    for issue in all_issues:
        status_counts[issue.status] = status_counts.get(issue.status, 0) + 1
    
    print(f"   Issues: {status_counts['backlog']} backlog, {status_counts['in_progress']} in progress, {status_counts['completed']} completed, {status_counts['blocked']} blocked")
    
    # Agent-specific metrics
    for agent_name in ai_agents.keys():
        agent_issues = work_queue.get_assigned_issues(agent_name)
        completed = sum(1 for issue in agent_issues if issue.status == "completed")
        in_progress = sum(1 for issue in agent_issues if issue.status == "in_progress")
        
        print(f"   {agent_name.title()}: {completed} completed, {in_progress} in progress, {len(agent_issues)} total")

def main():
    """Main entry point"""
    
    print("🤖 AI Development Automation")
    print("Enabling Sonnet, Codex, and Claude to autonomously implement GitHub issues")
    print("=" * 60)
    
    # Check environment
    if not check_environment():
        return
    
    print("🚀 Starting autonomous development...")
    print("Press Ctrl+C to stop")
    
    try:
        asyncio.run(start_ai_development())
    except KeyboardInterrupt:
        print("\n\n🛑 AI Development Automation stopped by user")
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
