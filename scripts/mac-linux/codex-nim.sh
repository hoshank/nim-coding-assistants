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

DEFAULT_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
MODEL="${NIM_MODEL:-$DEFAULT_MODEL}"
BASE_URL="${NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"

show_help() {
  cat << 'EOF'
Codex CLI with NVIDIA NIM (Mac / Linux)

Usage:
  codex-nim [options] [codex options...]

Options:
  --model <name>       Specify the model to use (default: meta/llama-3.3-70b-instruct)
  --key <key>          Set or update your NVIDIA API key
  --url <url>          Set NVIDIA Base URL (default: https://integrate.api.nvidia.com/v1)
  --help               Show this help message

All other arguments are passed directly to `codex`.

Supported Tested Models:
  - meta/llama-3.3-70b-instruct (Recommended default)
  - nvidia/nemotron-3-super-120b-a12b
  - qwen/qwen2.5-coder-32b-instruct
  - mistralai/mistral-large-2-instruct
EOF
}

CODEX_ARGS=()
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
    --key)
      NVIDIA_API_KEY="$2"
      shift 2
      ;;
    --url)
      BASE_URL="$2"
      shift 2
      ;;
    *)
      CODEX_ARGS+=("$1")
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
NIM_BASE_URL="$BASE_URL"
NIM_MODEL="$MODEL"
NIM_PROXY_PORT="${NIM_PROXY_PORT:-8000}"
EOF
chmod 600 "$ENV_FILE" 2>/dev/null || true

export OPENAI_BASE_URL="$BASE_URL"
export OPENAI_API_KEY="$NVIDIA_API_KEY"
export CODEX_MODEL="$MODEL"

echo "=========================================================="
echo " Launching Codex CLI with NVIDIA NIM"
echo " Model:     ${MODEL}"
echo " Endpoint:  ${BASE_URL}"
echo " Docs:      https://docs.nvidia.com/nim/large-language-models/latest/ai-assistant-integrations/codex-cli.html"
echo "=========================================================="

exec codex "${CODEX_ARGS[@]}"
