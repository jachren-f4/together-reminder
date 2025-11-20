"""
Cloud-based AI Agent Runner
Runs AI agents in GitHub Actions environment without requiring local computer
"""

import asyncio
import os
import sys
from pathlib import Path
from datetime import datetime
import json

# Add ai_agents to path
sys.path.append(str(Path(__file__).parent))

from work_queue_manager import AIAgentManager
from sonnet_agent import SonnetAgent
from codex_agent import CodexAgent
from claude_agent import ClaudeAgent

class CloudAIAgentRunner:
    """Run AI agents in cloud environment with limited scope per run"""
    
    def __init__(self):
        self.github_token = os.getenv('GITHUB_TOKEN')
        if not self.github_token:
            raise ValueError("GITHUB_TOKEN environment variable required")
        
        self.work_queue = AIAgentManager(github_token=self.github_token)
        
        # Initialize agents
        self.sonnet = SonnetAgent(self.work_queue)
        self.codex = CodexAgent(self.work_queue)
        self.claude = ClaudeAgent(self.work_queue)
        
        self.agents = {
            'sonnet': self.sonnet,
            'codex': self.codex,
            'claude': self.claude
        }
    
    async def run_cloud_agent(self, agent_name: str) -> dict:
        """Run single agent in cloud environment"""
        
        print(f"🤖 Starting Cloud {agent_name.title()} Agent Run | {datetime.now().isoformat()}")
        
        try:
            agent = self.agents[agent_name]
            
            # Get assigned issues for this agent
            issues = self.work_queue.get_assigned_issues(agent_name)
            
            if not issues:
                print(f"🤖 {agent_name.title()}: No assigned issues in this run")
                return {
                    "success": True,
                    "issues_processed": 0,
                    "message": "No issues assigned",
                    "runtime_seconds": 0
                }
            
            # Process up to 2 issues per cloud run (to stay within limits)
            max_issues_per_run = 2
            processed_count = 0
            results = []
            
            for issue in issues[:max_issues_per_run]:
                if issue.status == "backlog":
                    print(f"🤖 {agent_name.title()}: Processing issue #{issue.number} - {issue.title}")
                    
                    try:
                        # Update status
                        await self.work_queue.update_issue_status(issue.number, "in_progress")
                        
                        # Process based on agent type
                        start_time = datetime.now()
                        
                        if agent_name == "sonnet":
                            result = await agent.process_flutter_issue(issue)
                        elif agent_name == "codex":
                            result = await agent.process_backend_issue(issue)
                        elif agent_name == "claude":
                            result = await agent.process_architecture_issue(issue)
                        
                        end_time = datetime.now()
                        runtime = (end_time - start_time).total_seconds()
                        
                        if result["success"]:
                            await self.work_queue.update_issue_status(issue.number, "completed")
                            
                            # Create comment on GitHub issue
                            await self.create_completion_comment(issue, agent_name, runtime)
                            
                            results.append({
                                "issue_number": issue.number,
                                "title": issue.title,
                                "runtime_seconds": runtime,
                                "status": "completed"
                            })
                            
                            print(f"✅ {agent_name.title()}: Completed issue #{issue.number} in {runtime:.1f}s")
                        else:
                            await self.work_queue.update_issue_status(issue.number, "failed")
                            results.append({
                                "issue_number": issue.number,
                                "title": issue.title,
                                "runtime_seconds": runtime,
                                "status": "failed",
                                "error": result.get("error", "Unknown error")
                            })
                            
                            print(f"❌ {agent_name.title()}: Failed issue #{issue.number} - {result.get('error', 'Unknown error')}")
                        
                        processed_count += 1
                        
                        # Wait between issues to avoid rate limits
                        if processed_count < len(issues[:max_issues_per_run]):
                            await asyncio.sleep(30)  # 30 seconds between issues
                    
                    except Exception as e:
                        print(f"❌ {agent_name.title()}: Error processing issue #{issue.number}: {e}")
                        await self.work_queue.update_issue_status(issue.number, "blocked")
                        await self.create_error_comment(issue, agent_name, str(e))
                        
                        results.append({
                            "issue_number": issue.number,
                            "title": issue.title,
                            "runtime_seconds": 0,
                            "status": "error",
                            "error": str(e)
                        })
            
            total_runtime = sum(r.get("runtime_seconds", 0) for r in results)
            
            print(f"🎉 {agent_name.title()}: Completed {processed_count}/{len(issues[:max_issues_per_run])} issues in {total_runtime:.1f}s")
            
            return {
                "success": True,
                "issues_assigned": len(issues),
                "issues_processed": processed_count,
                "runtime_seconds": total_runtime,
                "results": results,
                "message": f"Processed {processed_count} issues successfully"
            }
            
        except Exception as e:
            print(f"💥 {agent_name.title()}: Fatal error - {e}")
            return {
                "success": False,
                "issues_processed": 0,
                "runtime_seconds": 0,
                "error": str(e),
                "message": "Fatal error occurred"
            }
    
    async def create_completion_comment(self, issue, agent_name: str, runtime_seconds: float):
        """Create completion comment on GitHub issue"""
        
        try:
            await self.work_queue.create_comment(
                issue.number,
                f"✅ **Completed by {agent_name.title()}** 🤖\n\n🏁 **Implementation complete** after {runtime_seconds:.1f} seconds\n\n📋 **Next Steps:**\n- [ ] Review generated pull request\n- [ ] Merge after approval\n- [ ] Monitor deployment\n- [ ] Close this issue\n\n🔗 **Automation Status:** Cloud processing successful"
            )
        except Exception as e:
            print(f"Warning: Could not create completion comment for issue #{issue.number}: {e}")
    
    async def create_error_comment(self, issue, agent_name: str, error: str):
        """Create error comment on GitHub issue"""
        
        try:
            await self.work_queue.create_comment(
                issue.number,
                f"❌ **Error in {agent_name.title()} Processing** 🤖\n\n⚠️ **Error Details:** {error}\n\n📋 **Next Steps:**\n- [ ] Review error details\n- [ ] Manually assign to different agent if needed\n- [ ] Provide additional requirements\n- [ ] Try running automation again\n\n🔗 **Automation Status:** Requires human intervention"
            )
        except Exception as e:
            print(f"Warning: Could not create error comment for issue #{issue.number}: {e}")

# Entry point for cloud automation
async def run_cloud_agent(agent_name: str) -> dict:
    """Main entry point for GitHub Actions"""
    
    try:
        runner = CloudAIAgentRunner()
        result = await runner.run_cloud_agent(agent_name)
        return result
    
    except Exception as e:
        print(f"💥 Cloud agent runner failed: {e}")
        return {
            "success": False,
            "error": str(e),
            "message": "Cloud agent runner initialization failed"
        }
