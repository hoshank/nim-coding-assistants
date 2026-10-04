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

# Load .env file
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

DEFAULT_MODEL="nvidia/nemotron-3-super-120b-a12b"
MODEL="${NIM_MODEL:-$DEFAULT_MODEL}"
BASE_URL="${NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"
API_KEY="${NVIDIA_API_KEY:-}"

show_help() {
  cat << 'EOF'
Pi Coding Agent with NVIDIA NIM & SoL-Pi (macOS / Linux)

Usage:
  pi-nim [options] [pi options...]

Options:
  --model, -m <name>   Specify the model to use (default: nvidia/nemotron-3-super-120b-a12b)
  --key <key>          Set or update your NVIDIA API key
  --url <url>          Set NVIDIA Base URL (default: https://integrate.api.nvidia.com/v1)
  --help, -h           Show this help message

All other arguments are passed directly to `pi`.

Supported NIM Models for Pi:
  - nvidia/nemotron-3-super-120b-a12b (Recommended default)
  - nvidia/nemotron-3-ultra-550b-a55b
  - deepseek-ai/deepseek-v4-pro-0813
  - deepseek-ai/deepseek-v4-flash-0731
  - minimaxai/minimax-m3
  - moonshotai/kimi-k3
EOF
}

PI_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      show_help
      exit 0
      ;;
    --model|-m)
      MODEL="$2"
      shift 2
      ;;
    --key)
      API_KEY="$2"
      shift 2
      ;;
    --url)
      BASE_URL="$2"
      shift 2
      ;;
    *)
      PI_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ -z "$API_KEY" ]; then
  echo "=========================================================="
  echo " NVIDIA NIM API Key Required"
  echo " Get your key from: https://build.nvidia.com/"
  echo "=========================================================="
  read -r -p "Enter your NVIDIA API Key (nvapi-...): " API_KEY
  if [ -z "$API_KEY" ]; then
    echo "Error: NVIDIA API Key is required." >&2
    exit 1
  fi
fi

# Ensure ~/.pi/agent/auth.json has nvidia key
PI_AGENT_DIR="$HOME/.pi/agent"
mkdir -p "$PI_AGENT_DIR"
AUTH_FILE="$PI_AGENT_DIR/auth.json"

if command -v python3 &>/dev/null; then
  python3 -c "
import json, os
p = '$AUTH_FILE'
data = {}
if os.path.exists(p):
    try:
        with open(p, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        data = {}
data['nvidia'] = {'type': 'api_key', 'key': '$API_KEY'}
with open(p, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
"
fi

export NVIDIA_API_KEY="$API_KEY"

echo "=========================================================="
echo " Launching Pi Coding Agent with NVIDIA NIM"
echo " Model:    $MODEL"
echo " Provider: nvidia"
echo " Endpoint: $BASE_URL"
echo "=========================================================="

exec pi --provider nvidia --model "$MODEL" "${PI_ARGS[@]}"
