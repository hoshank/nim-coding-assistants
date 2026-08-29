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

DEFAULT_MODEL="meta/llama-3.3-70b-instruct"
PORT="${NIM_PROXY_PORT:-8000}"
MODEL="${NIM_MODEL:-$DEFAULT_MODEL}"

show_help() {
  cat << 'EOF'
Claude Code with NVIDIA NIM Bridge (Mac / Linux)

Usage:
  claude-nim [options] [claude options...]

Options:
  --model <name>       Specify the model to use (default: meta/llama-3.3-70b-instruct)
  --port <port>        Specify the local proxy port (default: 8000)
  --key <key>          Set or update your NVIDIA API key
  --status             Check the status of the NIM background proxy
  --stop               Stop the background proxy
  --logs               View recent logs from the proxy
  --list-models        List popular supported NVIDIA NIM models
  --help               Show this help message

All other arguments are passed directly to `claude`.

Supported Tested Models:
  - meta/llama-3.3-70b-instruct (Recommended default)
  - nvidia/nemotron-3-super-120b-a12b
  - qwen/qwen2.5-coder-32b-instruct
  - mistralai/mistral-large-2-instruct
  - deepseek-ai/deepseek-r1
  - meta/llama-3.1-405b-instruct
EOF
}

# Parse custom wrapper flags
CLAUDE_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_help
      exit 0
      ;;
    --model|-m)
      MODEL="$2"
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
        echo "  - meta/llama-3.3-70b-instruct (Recommended)"
        echo "  - nvidia/nemotron-3-super-120b-a12b"
        echo "  - qwen/qwen2.5-coder-32b-instruct"
      fi
      exit 0
      ;;
    *)
      CLAUDE_ARGS+=("$1")
      shift
      ;;
  esac
done

# Ensure API Key is configured
if [ -z "$NVIDIA_API_KEY" ]; then
  echo "=========================================================="
  echo " NVIDIA NIM API Key Required"
  echo " Get your key from: https://build.nvidia.com/"
  echo "=========================================================="
  read -r -p "Enter your NVIDIA API Key (nvapi-...): " NVIDIA_API_KEY
  echo ""
  if [ -z "$NVIDIA_API_KEY" ]; then
    echo "Error: NVIDIA API Key is required."
    exit 1
  fi
fi

# Persist to .env
cat << EOF > "$ENV_FILE"
# NVIDIA NIM Configuration for Claude Code & Codex CLI
NVIDIA_API_KEY="$NVIDIA_API_KEY"
NIM_BASE_URL="${NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"
NIM_MODEL="$MODEL"
NIM_PROXY_PORT="$PORT"
EOF
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
export MODEL_NAME="${MODEL}"
export ANTHROPIC_CUSTOM_MODEL_OPTION="${MODEL}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${MODEL}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${MODEL}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="${MODEL}"
export CLAUDE_CODE_SUBAGENT_MODEL="${MODEL}"

echo "=========================================================="
echo " Launching Claude Code with NVIDIA NIM"
echo " Model:     ${MODEL}"
echo " Endpoint:  ${NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"
echo " Proxy:     http://127.0.0.1:${PORT}"
echo " Docs:      https://docs.nvidia.com/nim/large-language-models/latest/ai-assistant-integrations/claude-code.html"
echo "=========================================================="

exec claude "${CLAUDE_ARGS[@]}"
