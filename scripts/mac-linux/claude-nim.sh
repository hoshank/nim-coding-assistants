#!/usr/bin/env bash
set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")/../.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
PID_FILE="$SCRIPT_DIR/.proxy.pid"
LOG_FILE="$SCRIPT_DIR/.proxy.log"
VENV_DIR="$SCRIPT_DIR/.venv"

# Use venv python if available, otherwise system python
if [ -f "$VENV_DIR/bin/python" ]; then
  PYTHON_BIN="$VENV_DIR/bin/python"
elif command -v python3 &>/dev/null; then
  PYTHON_BIN="python3"
else
  echo "Error: Python 3 not found. Run ./scripts/mac-linux/install.sh first."
  exit 1
fi

# Load .env file
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

DEFAULT_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
PORT="${NIM_PROXY_PORT:-8000}"
MODEL="${NIM_MODEL:-$DEFAULT_MODEL}"
DEFAULT_EFFORT="medium"
EFFORT="${NIM_EFFORT:-$DEFAULT_EFFORT}"

show_help() {
  cat << 'EOF'
Claude Code with NVIDIA NIM Bridge (Mac / Linux)

Usage:
  claude-nim [options] [claude options...]

Options:
  --model, -m <name>   Specify the model to use (default: nvidia/nemotron-3-ultra-550b-a55b)
  --choose, -c         Interactively choose a model from the supported NIM catalog
  --profile, -P <name> Specify profile name (e.g. vanilla, dev - default: default ~/.claude)
  --effort, -e <level> Specify reasoning effort (low, medium, high - default: medium)
  --safe               Run with standard permission checks (disables automatic skip-permissions)
  --port <port>        Specify the local proxy port (default: 8000)
  --key <key>          Set or update your NVIDIA API key
  --status             Check the status of the NIM background proxy
  --stop               Stop the background proxy
  --logs               View recent logs from the proxy
  --list-models        List popular supported NVIDIA NIM models
  --help, -h           Show this help message

Permission Behavior:
  By default, `claude-nim` automatically includes `--dangerously-skip-permissions`
  for frictionless pair programming. Use `--safe` to require manual approvals.

All other arguments are passed directly to `claude`.

Supported Tested Models:
  - nvidia/nemotron-3-ultra-550b-a55b (Recommended default)
  - nvidia/nemotron-3-super-120b-a12b
  - deepseek-ai/deepseek-v4-pro
  - minimaxai/minimax-m3
  - thinkingmachines/inkling
EOF
}

# Check if interactive selection menu should run (default when typing `claude-nim` in terminal with no flags)
RUN_INTERACTIVE=false
if [ $# -eq 0 ] && [ -t 0 ]; then
  RUN_INTERACTIVE=true
fi

# Parse custom wrapper flags
CLAUDE_ARGS=()
PROFILE="${NIM_PROFILE:-}"
SKIP_PERMISSIONS=true
CHOOSE_MODEL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_help
      exit 0
      ;;
    --interactive|-i)
      RUN_INTERACTIVE=true
      shift
      ;;
    --yes|-y|--quick)
      RUN_INTERACTIVE=false
      shift
      ;;
    --profile|-P)
      PROFILE="$2"
      shift 2
      ;;
    --model|-m)
      MODEL="$2"
      shift 2
      ;;
    --choose|-c)
      CHOOSE_MODEL=true
      shift
      ;;
    --effort|-e)
      EFFORT="$2"
      shift 2
      ;;
    --safe|--no-danger)
      SKIP_PERMISSIONS=false
      shift
      ;;
    --dangerously-skip-permissions)
      SKIP_PERMISSIONS=true
      shift
      ;;
    --permission-mode)
      SKIP_PERMISSIONS=false
      CLAUDE_ARGS+=("$1" "$2")
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --key)
      NVIDIA_API_KEY="$2"
      shift 2
      ;;
    --status)
      if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "NIM Proxy is RUNNING (PID: $(cat "$PID_FILE"), Port: $PORT)"
      else
        echo "NIM Proxy is STOPPED"
      fi
      exit 0
      ;;
    --stop)
      if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
          kill "$PID"
          echo "Stopped NIM Proxy (PID: $PID)"
        else
          echo "Process $PID not running."
        fi
        rm -f "$PID_FILE"
      else
        echo "No PID file found."
      fi
      exit 0
      ;;
    --logs)
      if [ -f "$LOG_FILE" ]; then
        tail -n 50 "$LOG_FILE"
      else
        echo "No log file found at $LOG_FILE"
      fi
      exit 0
      ;;
    --list-models)
      if [ -f "$SCRIPT_DIR/config/models.json" ]; then
        "$PYTHON_BIN" -c '
import json
with open("'$SCRIPT_DIR'/config/models.json") as f:
    data = json.load(f)
for m in data.get("models", []):
    print(f"  • {m[\"id\"]} ({m[\"name\"]}) - {m[\"recommended_for\"]}")
'
      else
        echo "  - nvidia/nemotron-3-ultra-550b-a55b (Recommended)"
        echo "  - nvidia/nemotron-3-super-120b-a12b"
        echo "  - deepseek-ai/deepseek-v4-pro"
      fi
      exit 0
      ;;
    *)
      CLAUDE_ARGS+=("$1")
      shift
      ;;
  esac
done

# Run interactive TUI dropdown selection if requested (or when user simply typed claude-nim)
if [ "$RUN_INTERACTIVE" = true ] || [ "$CHOOSE_MODEL" = true ]; then
  CONFIG_TMP="$(mktemp -t nim_claude_XXXXXX 2>/dev/null || echo "$SCRIPT_DIR/.nim_claude_env")"
  if "$PYTHON_BIN" "$SCRIPT_DIR/scripts/interactive_menu.py" --app claude --output "$CONFIG_TMP"; then
    if [ -f "$CONFIG_TMP" ]; then
      # shellcheck disable=SC1090
      source "$CONFIG_TMP"
      rm -f "$CONFIG_TMP"
    fi
  else
    rm -f "$CONFIG_TMP"
    exit 130
  fi
fi

# Ensure API Key is configured
if [ -z "$NVIDIA_API_KEY" ] || [ "$NVIDIA_API_KEY" = "nvapi-your-key-here" ]; then
  echo "=========================================================="
  echo " NVIDIA NIM API Key Required"
  echo " Get your key from: https://build.nvidia.com/"
  echo "=========================================================="
  read -s -p "Enter your NVIDIA API Key (nvapi-...): " NVIDIA_API_KEY
  echo ""
  if [ -z "$NVIDIA_API_KEY" ]; then
    echo "Error: NVIDIA API Key is required."
    exit 1
  fi
fi

# Persist to .env safely
if [ ! -f "$ENV_FILE" ]; then
  if [ -f "$SCRIPT_DIR/env.example" ]; then
    cp "$SCRIPT_DIR/env.example" "$ENV_FILE"
  elif [ -f "$SCRIPT_DIR/.env.example" ]; then
    cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
  fi
fi

if [ -f "$ENV_FILE" ] && grep -q "NVIDIA_API_KEY=" "$ENV_FILE"; then
  sed -i.bak "s|^NVIDIA_API_KEY=.*|NVIDIA_API_KEY=\"$NVIDIA_API_KEY\"|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
else
  cat << EOF > "$ENV_FILE"
# NVIDIA NIM Configuration for Claude Code & Codex CLI
NVIDIA_API_KEY="$NVIDIA_API_KEY"
NIM_BASE_URL="${NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"
NIM_MODEL="$MODEL"
NIM_PROXY_PORT="$PORT"
EOF
fi
chmod 600 "$ENV_FILE" 2>/dev/null || true

export NVIDIA_API_KEY
export NIM_MODEL="$MODEL"
export NIM_PROXY_PORT="$PORT"

# Check if proxy is running
is_proxy_running() {
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    return 0
  fi
  if curl -s -f -o /dev/null --connect-timeout 1 "http://127.0.0.1:${PORT}/health" 2>/dev/null; then
    return 0
  fi
  return 1
}

# Start proxy in background if not already active
if ! is_proxy_running; then
  echo "Starting NIM background proxy on port ${PORT}..."
  nohup "$PYTHON_BIN" "$SCRIPT_DIR/proxy.py" --port "$PORT" > "$LOG_FILE" 2>&1 &
  PROXY_PID=$!
  echo "$PROXY_PID" > "$PID_FILE"

  # Wait for readiness
  READY=0
  for _ in {1..25}; do
    if curl -s -f -o /dev/null --connect-timeout 1 "http://127.0.0.1:${PORT}/health" 2>/dev/null; then
      READY=1
      break
    fi
    sleep 0.2
  done

  if [ "$READY" -eq 0 ]; then
    echo "Warning: Proxy starting took longer than expected. Check logs at $LOG_FILE"
  fi
fi

# Export Claude Code environment variables exactly as in NVIDIA documentation
export ANTHROPIC_BASE_URL="http://127.0.0.1:${PORT}"
export ANTHROPIC_API_KEY="not-used"
export ANTHROPIC_MODEL="${MODEL}"
export CLAUDE_MODEL="${MODEL}"
export MODEL_NAME="${MODEL}"
export ANTHROPIC_CUSTOM_MODEL_OPTION="${MODEL}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${MODEL}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${MODEL}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="${MODEL}"
export CLAUDE_CODE_SUBAGENT_MODEL="${MODEL}"
export CLAUDE_REASONING_EFFORT="${EFFORT}"
export NIM_REASONING_EFFORT="${EFFORT}"

# Profile support (isolated config, history, plugins, and MCP servers)
if [ -n "$PROFILE" ]; then
  PROFILE_DIR="$HOME/.claude-profiles/$PROFILE"
  mkdir -p "$PROFILE_DIR"
  export CLAUDE_CONFIG_DIR="$PROFILE_DIR"
fi

# Automatically add --dangerously-skip-permissions unless disabled with --safe
if [ "$SKIP_PERMISSIONS" = true ]; then
  has_danger=false
  for arg in "${CLAUDE_ARGS[@]}"; do
    if [[ "$arg" == "--dangerously-skip-permissions" ]] || [[ "$arg" == "--permission-mode" ]]; then
      has_danger=true
      break
    fi
  done
  if [ "$has_danger" = false ]; then
    CLAUDE_ARGS=("--dangerously-skip-permissions" "${CLAUDE_ARGS[@]}")
  fi
fi

echo "=========================================================="
echo " Launching Claude Code with NVIDIA NIM"
echo " Model:       ${MODEL}"
echo " Effort:      ${EFFORT}"
if [ -n "$PROFILE" ]; then
  echo " Profile:     ${PROFILE} (${PROFILE_DIR})"
else
  echo " Profile:     default (~/.claude)"
fi
if [ "$SKIP_PERMISSIONS" = true ]; then
  echo " Permissions: --dangerously-skip-permissions (auto-approved)"
else
  echo " Permissions: Standard interactive prompts (--safe)"
fi
echo " Endpoint:    ${NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"
echo " Proxy:       http://127.0.0.1:${PORT}"
echo " Docs:        https://docs.nvidia.com/nim/large-language-models/latest/ai-assistant-integrations/claude-code.html"
echo "=========================================================="

exec claude "${CLAUDE_ARGS[@]}"

