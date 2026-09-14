#!/usr/bin/env bash
set -e

# ==============================================================================
# NIM Coding Assistants - Master Foolproof Setup & Diagnostics Script
# Platform: macOS & Linux
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/env.example"
DOT_ENV_EXAMPLE="$SCRIPT_DIR/.env.example"
VENV_DIR="$SCRIPT_DIR/.venv"
BIN_DIR="$HOME/.local/bin"

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_banner() {
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║          🚀 NVIDIA NIM Coding Assistants Setup               ║"
  echo "║  Claude Code • Codex CLI • Aider • Zed Editor Integration    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

run_diagnostics() {
  echo -e "\n${CYAN}${BOLD}─── Running NIM Environment Diagnostics (--doctor) ───${NC}\n"
  local errors=0

  # 1. Check Python
  if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version)
    echo -e "  [✔] Python: ${GREEN}$PY_VER${NC}"
  else
    echo -e "  [✘] Python: ${RED}python3 not found! Please install Python 3.10+${NC}"
    errors=$((errors + 1))
  fi

  # 2. Check Virtualenv & Packages
  if [ -f "$VENV_DIR/bin/python" ]; then
    echo -e "  [✔] Virtualenv: ${GREEN}Found at .venv${NC}"
    if "$VENV_DIR/bin/python" -c "import fastapi, uvicorn, litellm" 2>/dev/null; then
      echo -e "  [✔] Python Dependencies: ${GREEN}fastapi, uvicorn, litellm OK${NC}"
    else
      echo -e "  [✘] Python Dependencies: ${YELLOW}Missing or broken. Run ./setup.sh to reinstall.${NC}"
      errors=$((errors + 1))
    fi
  else
    echo -e "  [✘] Virtualenv: ${YELLOW}Not initialized (.venv). Run ./setup.sh to create.${NC}"
    errors=$((errors + 1))
  fi

  # 3. Check Claude Code CLI
  if command -v claude &>/dev/null; then
    CLAUDE_VER=$(claude --version 2>/dev/null || echo "installed")
    echo -e "  [✔] Claude Code CLI: ${GREEN}$CLAUDE_VER${NC}"
  else
    echo -e "  [!] Claude Code CLI: ${YELLOW}Not found in PATH.${NC}"
    echo -e "      Install with: ${CYAN}npm install -g @anthropic-ai/claude-code${NC}"
  fi

  # 4. Check Codex CLI
  if command -v codex &>/dev/null; then
    CODEX_VER=$(codex --version 2>/dev/null || echo "installed")
    echo -e "  [✔] Codex CLI: ${GREEN}$CODEX_VER${NC}"
  else
    echo -e "  [!] Codex CLI: ${YELLOW}Not found in PATH.${NC}"
  fi

  # 5. Check Aider CLI
  if command -v aider &>/dev/null || [ -x "$HOME/.local/bin/aider" ]; then
    AIDER_VER=$(aider --version 2>/dev/null || echo "installed")
    echo -e "  [✔] Aider CLI: ${GREEN}$AIDER_VER${NC}"
  else
    echo -e "  [!] Aider CLI: ${YELLOW}Not found in PATH.${NC}"
    echo -e "      Install with: ${CYAN}uv tool install --python 3.12 aider-chat${NC}"
  fi

  # 6. Check .env and API Key
  if [ -f "$ENV_FILE" ]; then
    echo -e "  [✔] Environment File: ${GREEN}.env exists${NC}"
    # Read key safely
    KEY=$(grep -E '^NVIDIA_API_KEY=' "$ENV_FILE" | cut -d '=' -f2- | tr -d ' "' || true)
    if [ -n "$KEY" ] && [ "$KEY" != "nvapi-your-key-here" ]; then
      KEY_MASKED="${KEY:0:10}...${KEY: -4}"
      echo -e "  [✔] NVIDIA API Key: ${GREEN}Configured ($KEY_MASKED)${NC}"

      # Live check key against NVIDIA endpoint
      echo -n "      Verifying API Key with NVIDIA Cloud API... "
      HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $KEY" https://integrate.api.nvidia.com/v1/models || echo "000")
      if [ "$HTTP_STATUS" = "200" ]; then
        echo -e "${GREEN}Active & Valid (HTTP 200)${NC}"
      elif [ "$HTTP_STATUS" = "401" ]; then
        echo -e "${RED}Invalid or Expired Key (HTTP 401)${NC}"
        errors=$((errors + 1))
      else
        echo -e "${YELLOW}Endpoint returned HTTP $HTTP_STATUS${NC}"
      fi
    else
      echo -e "  [✘] NVIDIA API Key: ${RED}Placeholder or empty in .env${NC}"
      errors=$((errors + 1))
    fi
  else
    echo -e "  [✘] Environment File: ${RED}.env missing! Run ./setup.sh to configure.${NC}"
    errors=$((errors + 1))
  fi

  # 7. Check Symlinks
  if [ -x "$BIN_DIR/claude-nim" ] && [ -x "$BIN_DIR/codex-nim" ] && [ -x "$BIN_DIR/aider-nim" ]; then
    echo -e "  [✔] Global CLI Launchers: ${GREEN}Installed in $BIN_DIR (claude-nim, codex-nim, aider-nim)${NC}"
  else
    echo -e "  [!] Global CLI Launchers: ${YELLOW}Missing or incomplete in $BIN_DIR${NC}"
  fi

  # 8. Check Zed Editor
  ZED_SETTINGS="$HOME/.config/zed/settings.json"
  if command -v zed &>/dev/null || [ -d "/Applications/Zed.app" ] || [ -d "$HOME/.config/zed" ]; then
    if [ -f "$ZED_SETTINGS" ] && grep -q '"Nvidia"' "$ZED_SETTINGS" 2>/dev/null; then
      echo -e "  [✔] Zed Editor: ${GREEN}Detected & configured for NVIDIA NIM ($ZED_SETTINGS)${NC}"
    else
      echo -e "  [!] Zed Editor: ${YELLOW}Detected, but NIM settings not yet configured.${NC}"
      echo -e "      Run: ${CYAN}./scripts/mac-linux/setup-zed.sh${NC}"
    fi
  fi

  # 9. Check Aider Config
  AIDER_CONF="$HOME/.aider.conf.yml"
  if [ -f "$AIDER_CONF" ]; then
    echo -e "  [✔] Aider Global Config: ${GREEN}Found at $AIDER_CONF${NC}"
  else
    echo -e "  [!] Aider Global Config: ${YELLOW}Not configured yet. Run ./scripts/mac-linux/setup-aider.sh${NC}"
  fi

  echo ""
  if [ $errors -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All critical checks passed! You are ready to run claude-nim, codex-nim, and aider-nim.${NC}\n"
  else
    echo -e "${YELLOW}${BOLD}Found $errors item(s) to configure or resolve.${NC}\n"
  fi
}

if [[ "$1" == "--doctor" || "$1" == "-d" ]]; then
  print_banner
  run_diagnostics
  exit 0
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage:"
  echo "  ./setup.sh          Run the interactive setup wizard"
  echo "  ./setup.sh --doctor Run diagnostic checks on your environment"
  echo "  ./setup.sh --help   Show this help message"
  exit 0
fi

print_banner

# ------------------------------------------------------------------------------
# 1. Check Python 3
# ------------------------------------------------------------------------------
echo -e "${CYAN}▶ Step 1: Checking Python 3...${NC}"
if ! command -v python3 &>/dev/null; then
  echo -e "${RED}Error: python3 is required. Please install Python 3.10+ first.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ Python 3 found: $(python3 --version)${NC}\n"

# ------------------------------------------------------------------------------
# 2. Setup Virtual Environment & Dependencies
# ------------------------------------------------------------------------------
echo -e "${CYAN}▶ Step 2: Setting up Python virtual environment...${NC}"
if [ ! -d "$VENV_DIR" ]; then
  echo "  Creating virtual environment in .venv..."
  python3 -m venv "$VENV_DIR"
fi

echo "  Installing required Python packages (fastapi, uvicorn, litellm)..."
if command -v uv &>/dev/null; then
  uv pip install -r requirements.txt --python "$VENV_DIR/bin/python" -q
else
  "$VENV_DIR/bin/pip" install --upgrade pip -q
  "$VENV_DIR/bin/pip" install -r requirements.txt -q
fi
echo -e "${GREEN}✔ Python virtual environment and dependencies ready.${NC}\n"

# ------------------------------------------------------------------------------
# 3. Configure .env & Safe API Key Prompt
# ------------------------------------------------------------------------------
echo -e "${CYAN}▶ Step 3: Configuring Environment & API Key...${NC}"

# Ensure we have a template to copy from
if [ ! -f "$ENV_EXAMPLE" ] && [ -f "$DOT_ENV_EXAMPLE" ]; then
  cp "$DOT_ENV_EXAMPLE" "$ENV_EXAMPLE"
fi

if [ ! -f "$ENV_FILE" ]; then
  if [ -f "$HOME/.claude/nim/.env" ]; then
    echo "  Importing existing settings from ~/.claude/nim/.env..."
    cp "$HOME/.claude/nim/.env" "$ENV_FILE"
  elif [ -f "$ENV_EXAMPLE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
  elif [ -f "$DOT_ENV_EXAMPLE" ]; then
    cp "$DOT_ENV_EXAMPLE" "$ENV_FILE"
  fi
fi

# Check if key needs to be supplied
CURRENT_KEY=""
if [ -f "$ENV_FILE" ]; then
  CURRENT_KEY=$(grep -E '^NVIDIA_API_KEY=' "$ENV_FILE" | cut -d '=' -f2- | tr -d ' "' || true)
fi

if [ -z "$CURRENT_KEY" ] || [ "$CURRENT_KEY" = "nvapi-your-key-here" ]; then
  echo -e "${YELLOW}----------------------------------------------------------------${NC}"
  echo -e "${YELLOW} NVIDIA NIM API Key Required${NC}"
  echo -e " Get your free key at: ${CYAN}https://build.nvidia.com/${NC}"
  echo -e "${YELLOW} (Input is hidden for security; nothing will show as you type)${NC}"
  echo -e "${YELLOW}----------------------------------------------------------------${NC}"
  read -s -p "Paste your NVIDIA API Key (nvapi-...): " USER_KEY
  echo ""

  if [ -n "$USER_KEY" ]; then
    # Safely replace key in .env
    if grep -q "NVIDIA_API_KEY=" "$ENV_FILE" 2>/dev/null; then
      sed -i.bak "s|^NVIDIA_API_KEY=.*|NVIDIA_API_KEY=${USER_KEY}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    else
      echo "NVIDIA_API_KEY=${USER_KEY}" >> "$ENV_FILE"
    fi
    chmod 600 "$ENV_FILE"
    echo -e "${GREEN}✔ NVIDIA API Key saved securely to .env (file mode 600)${NC}"
  else
    echo -e "${YELLOW}⚠ No key entered. You can add it later to .env.${NC}"
  fi
else
  echo -e "${GREEN}✔ NVIDIA API Key is already configured in .env.${NC}"
fi
echo ""

# ------------------------------------------------------------------------------
# 4. Check & Optionally Install Claude Code, Codex, and Aider CLI
# ------------------------------------------------------------------------------
echo -e "${CYAN}▶ Step 4: Checking Coding Assistant CLIs (Claude, Codex, Aider)...${NC}"
if command -v claude &>/dev/null; then
  echo -e "  ${GREEN}✔ Claude Code CLI detected ($(claude --version 2>/dev/null || echo 'installed'))${NC}"
else
  echo -e "  ${YELLOW}! Claude Code CLI ('claude') is not installed yet.${NC}"
  if command -v npm &>/dev/null; then
    read -r -p "  Would you like to install Claude Code globally via npm now? [y/N]: " INSTALL_CLAUDE
    if [[ "$INSTALL_CLAUDE" =~ ^[Yy]$ ]]; then
      echo "  Running: npm install -g @anthropic-ai/claude-code..."
      npm install -g @anthropic-ai/claude-code
      echo -e "  ${GREEN}✔ Claude Code CLI installed successfully.${NC}"
    else
      echo -e "  ${YELLOW}Skipped. You can install it later with: npm install -g @anthropic-ai/claude-code${NC}"
    fi
  else
    echo -e "  ${YELLOW}Node/npm not detected. Install Node.js to use Claude Code.${NC}"
  fi
fi

if command -v codex &>/dev/null; then
  echo -e "  ${GREEN}✔ Codex CLI detected ($(codex --version 2>/dev/null || echo 'installed'))${NC}"
else
  echo -e "  ${YELLOW}! Codex CLI ('codex') is not installed yet.${NC}"
fi

if command -v aider &>/dev/null || [ -x "$HOME/.local/bin/aider" ]; then
  echo -e "  ${GREEN}✔ Aider CLI detected ($(aider --version 2>/dev/null || echo 'installed'))${NC}"
else
  echo -e "  ${YELLOW}! Aider CLI ('aider') is not installed yet.${NC}"
  if command -v uv &>/dev/null; then
    read -r -p "  Would you like to install Aider CLI globally via uv now? [y/N]: " INSTALL_AIDER
    if [[ "$INSTALL_AIDER" =~ ^[Yy]$ ]]; then
      echo "  Running: uv tool install --python 3.12 aider-chat..."
      uv tool install --python 3.12 aider-chat
      echo -e "  ${GREEN}✔ Aider CLI installed successfully.${NC}"
    else
      echo -e "  ${YELLOW}Skipped. You can install it later with: uv tool install --python 3.12 aider-chat${NC}"
    fi
  elif command -v pipx &>/dev/null; then
    read -r -p "  Would you like to install Aider CLI globally via pipx now? [y/N]: " INSTALL_AIDER
    if [[ "$INSTALL_AIDER" =~ ^[Yy]$ ]]; then
      pipx install aider-chat
      echo -e "  ${GREEN}✔ Aider CLI installed successfully.${NC}"
    fi
  else
    echo -e "  ${YELLOW}Install Aider later with: uv tool install --python 3.12 aider-chat${NC}"
  fi
fi
echo ""

# ------------------------------------------------------------------------------
# 5. Create Executables & Symlinks
# ------------------------------------------------------------------------------
echo -e "${CYAN}▶ Step 5: Linking CLI launcher commands...${NC}"
chmod +x "$SCRIPT_DIR/proxy.py"
chmod +x "$SCRIPT_DIR/scripts/mac-linux/claude-nim.sh"
chmod +x "$SCRIPT_DIR/scripts/mac-linux/codex-nim.sh"
chmod +x "$SCRIPT_DIR/scripts/mac-linux/aider-nim.sh"
chmod +x "$SCRIPT_DIR/scripts/mac-linux/install.sh"
chmod +x "$SCRIPT_DIR/scripts/mac-linux/setup-zed.sh"
chmod +x "$SCRIPT_DIR/scripts/mac-linux/setup-aider.sh"
chmod +x "$SCRIPT_DIR/setup.sh"

mkdir -p "$BIN_DIR"
ln -sf "$SCRIPT_DIR/scripts/mac-linux/claude-nim.sh" "$BIN_DIR/claude-nim"
ln -sf "$SCRIPT_DIR/scripts/mac-linux/codex-nim.sh" "$BIN_DIR/codex-nim"
ln -sf "$SCRIPT_DIR/scripts/mac-linux/aider-nim.sh" "$BIN_DIR/aider-nim"

echo -e "  ${GREEN}✔ Created global symlinks in $BIN_DIR:${NC}"
echo "    • claude-nim -> Launch Claude Code through NVIDIA NIM bridge"
echo "    • codex-nim  -> Launch Codex CLI connected directly to NVIDIA NIM"
echo "    • aider-nim  -> Launch Aider with Architect mode & NIM diff editing"

# Check PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  echo -e "${YELLOW}Notice: $BIN_DIR is not in your current PATH.${NC}"
  echo "Add this line to your ~/.zshrc or ~/.bashrc to run commands globally:"
  echo -e "  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
fi
echo ""

# ------------------------------------------------------------------------------
# 6. Check & Configure Zed Editor and Aider
# ------------------------------------------------------------------------------
echo -e "${CYAN}▶ Step 6: Checking Editor & Tool Integrations...${NC}"
if command -v zed &>/dev/null || [ -d "/Applications/Zed.app" ] || [ -d "$HOME/.config/zed" ]; then
  echo -e "  ${GREEN}✔ Zed Editor detected!${NC}"
  read -r -p "  Would you like to configure Zed Editor for NVIDIA NIM now? [Y/n]: " CONFIGURE_ZED
  if [[ ! "$CONFIGURE_ZED" =~ ^[Nn]$ ]]; then
    "$SCRIPT_DIR/scripts/mac-linux/setup-zed.sh"
  else
    echo -e "  ${YELLOW}Skipped. Run ./scripts/mac-linux/setup-zed.sh anytime to configure Zed.${NC}"
  fi
else
  echo -e "  ${YELLOW}Zed Editor not detected. Run ./scripts/mac-linux/setup-zed.sh if you install Zed later.${NC}"
fi

if command -v aider &>/dev/null || [ -x "$HOME/.local/bin/aider" ]; then
  echo -e "  ${GREEN}✔ Aider detected!${NC}"
  read -r -p "  Would you like to configure global ~/.aider.conf.yml for NVIDIA NIM now? [Y/n]: " CONFIGURE_AIDER
  if [[ ! "$CONFIGURE_AIDER" =~ ^[Nn]$ ]]; then
    "$SCRIPT_DIR/scripts/mac-linux/setup-aider.sh"
  else
    echo -e "  ${YELLOW}Skipped. Run ./scripts/mac-linux/setup-aider.sh anytime to configure Aider.${NC}"
  fi
fi

echo ""
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD} 🎉 Setup Complete! Everything is ready to go.${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Try running:"
echo -e "  ${CYAN}./setup.sh --doctor${NC}   Check health of your entire setup"
echo -e "  ${CYAN}claude-nim${NC}            Start Claude Code with NVIDIA NIM"
echo -e "  ${CYAN}codex-nim${NC}             Start Codex CLI with NVIDIA NIM"
echo -e "  ${CYAN}aider-nim${NC}             Start Aider Pair Programmer with NVIDIA NIM"
echo -e "  ${CYAN}zed .${NC}                 Launch Zed Editor with NVIDIA NIM Assistant"
echo ""
