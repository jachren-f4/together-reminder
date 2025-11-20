#!/bin/bash

# Python Environment Setup for AI Automation
# Run this to set up the required Python environment

echo "🐍 Setting up Python environment for AI automation..."

# Check Python version
python3 --version
if [ $? -ne 0 ]; then
    echo "❌ Python 3 is required. Please install Python 3.8+"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "ai_venv" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv ai_venv
fi

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source ai_venv/bin/activate

# Upgrade pip
echo "⬆️ Upgrading pip..."
pip install --upgrade pip

# Install required packages
echo "📦 Installing required Python packages..."

# Core dependencies
pip install PyGithub==2.3.0
pip install asyncio
pip install python-dotenv
pip install requests
pip install anthropic
pip install openai

# Optional packages for enhanced functionality
pip install pandas  # For performance analytics
pip install matplotlib  # For generating charts
pip install rich  # For pretty console output
pip install pyyaml  # For configuration files

echo "✅ Python environment setup complete!"

# Create environment template
if [ ! -f ".env.example" ]; then
    cat > .env.example << 'EOF'
# GitHub Configuration
GITHUB_TOKEN=your_github_token_here

# AI Agent API Keys
ANTHROPIC_API_KEY=your_claude_api_key_here
OPENAI_API_KEY=your_codex_api_key_here  
SONNET_API_KEY=your_sonnet_api_key_here

# Optional: Additional Configuration
LOG_LEVEL=INFO
MAX_CONCURRENT_TASKS=3
WORK_INTERVAL_SECONDS=300
EOF
    echo "📝 Created .env.example file"
    echo "📋 Copy .env.example to .env and add your actual API keys"
fi

echo ""
echo "🚀 Python environment is ready!"
echo ""
echo "📋 Next steps:"
echo "1. cp .env.example .env"
echo "2. Edit .env and add your actual API keys"
echo "3. source ai_venv/bin/activate"  
echo "4. python ai_agents/start_automation.py"
echo ""
echo "🤖 Your AI agents will start processing GitHub issues autonomously!"
