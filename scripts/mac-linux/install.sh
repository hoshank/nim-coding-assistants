#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================================="
echo " Setting up NVIDIA NIM Bridge for Claude Code & Codex CLI"
echo " Platform: macOS / Linux"
echo "=========================================================="

# 1. Check Python 3
if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required. Please install Python 3.10+ first."
  exit 1
fi

# 2. Setup Virtual Environment
if [ ! -d ".venv" ]; then
  echo "Creating virtual environment in .venv..."
  python3 -m venv .venv
fi

echo "Installing required Python packages..."
if command -v uv &>/dev/null; then
  uv pip install -r requirements.txt --python .venv/bin/python
else
  .venv/bin/pip install --upgrade pip
  .venv/bin/pip install -r requirements.txt
fi

# 3. Configure .env if not exists
if [ ! -f ".env" ]; then
  if [ -f "$HOME/.claude/nim/.env" ]; then
    echo "Importing existing settings from ~/.claude/nim/.env..."
    cp "$HOME/.claude/nim/.env" .env
  else
    if [ -f "env.example" ]; then
      cp env.example .env
    elif [ -f ".env.example" ]; then
      cp .env.example .env
    fi

    echo ""
    echo "----------------------------------------------------------"
    echo " Enter your NVIDIA API Key (from https://build.nvidia.com/)"
    echo "----------------------------------------------------------"
    read -r -p "NVIDIA API Key (nvapi-...): " API_KEY
    if [ -n "$API_KEY" ]; then
      if [ -f ".env" ]; then
        sed -i.bak "s|^NVIDIA_API_KEY=.*|NVIDIA_API_KEY=${API_KEY}|" .env && rm -f .env.bak
      else
        cat << EOF > .env
# NVIDIA NIM Configuration
NVIDIA_API_KEY="${API_KEY}"
NIM_BASE_URL="https://integrate.api.nvidia.com/v1"
NIM_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
NIM_PROXY_PORT="8000"
EOF
      fi
    fi
    chmod 600 .env
  fi
fi

# 4. Make scripts executable
chmod +x proxy.py
chmod +x scripts/mac-linux/claude-nim.sh
chmod +x scripts/mac-linux/codex-nim.sh
chmod +x scripts/mac-linux/aider-nim.sh
chmod +x scripts/mac-linux/install.sh
chmod +x scripts/mac-linux/setup-zed.sh
chmod +x scripts/mac-linux/setup-aider.sh

# 5. Create global symlinks in ~/.local/bin
mkdir -p "$HOME/.local/bin"

ln -sf "$SCRIPT_DIR/scripts/mac-linux/claude-nim.sh" "$HOME/.local/bin/claude-nim"
ln -sf "$SCRIPT_DIR/scripts/mac-linux/codex-nim.sh" "$HOME/.local/bin/codex-nim"
ln -sf "$SCRIPT_DIR/scripts/mac-linux/aider-nim.sh" "$HOME/.local/bin/aider-nim"

echo ""
echo "=========================================================="
echo " Installation Complete!"
echo "=========================================================="
echo "Installed commands in ~/.local/bin:"
echo "  • claude-nim  -> Run Claude Code using NVIDIA NIM"
echo "  • codex-nim   -> Run Codex CLI using NVIDIA NIM"
echo "  • aider-nim   -> Run Aider Pair Programmer using NVIDIA NIM"
echo ""
echo "Make sure ~/.local/bin is in your PATH. If needed, add to ~/.zshrc or ~/.bashrc:"
echo '  export PATH="$HOME/.local/bin:$PATH"'
echo ""
echo "Try running:"
echo "  claude-nim --help"
echo "  codex-nim --help"
echo "  aider-nim --help"
echo "=========================================================="
