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

VENV_DIR="$SCRIPT_DIR/.venv"

# Use venv python if available, otherwise system python
if [ -f "$VENV_DIR/bin/python" ]; then
  PYTHON_BIN="$VENV_DIR/bin/python"
elif command -v python3 &>/dev/null; then
  PYTHON_BIN="python3"
else
  PYTHON_BIN="python"
fi

DEFAULT_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
MODEL="${NIM_MODEL:-$DEFAULT_MODEL}"
BASE_URL="${NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"
DEFAULT_EFFORT="medium"
EFFORT="${NIM_EFFORT:-$DEFAULT_EFFORT}"

show_help() {
  cat << 'EOF'
Codex CLI with NVIDIA NIM (Mac / Linux)

Usage:
  codex-nim [options] [codex options...]

Options:
  --model, -m <name>   Specify the model to use (default: nvidia/nemotron-3-ultra-550b-a55b)
  --choose, -c         Interactively choose a model from the supported NIM catalog
  --profile, -p <name> Specify profile name (built-ins: danger-full-access, workspace-write, read-only)
  --effort, -e <level> Specify reasoning effort (low, medium, high - default: medium)
  --key <key>          Set or update your NVIDIA API key
  --url <url>          Set NVIDIA Base URL (default: https://integrate.api.nvidia.com/v1)
  --help, -h           Show this help message

Permission & Sandbox Shortcuts:
  -p danger-full-access                          Skip sandboxing and permissions via full-access profile
  --dangerously-bypass-approvals-and-sandbox     Bypass all approval prompts and sandboxing
  -a never                                       Never ask for approval before executing commands

All other arguments are passed directly to `codex`.

Supported Tested Models:
  - nvidia/nemotron-3-ultra-550b-a55b (Recommended default)
  - nvidia/nemotron-3-super-120b-a12b
  - deepseek-ai/deepseek-v4-pro-0813
  - deepseek-ai/deepseek-v4-flash-0731
  - minimaxai/minimax-m3
  - thinkingmachines/inkling
  - moonshotai/kimi-k3
EOF
}

# Check if interactive selection menu should run (default when typing `codex-nim` in terminal with no flags)
RUN_INTERACTIVE=false
if [ $# -eq 0 ] && [ -t 0 ]; then
  RUN_INTERACTIVE=true
fi

CODEX_ARGS=()
PROFILE=""
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
    --model|-m)
      MODEL="$2"
      shift 2
      ;;
    --choose|-c)
      CHOOSE_MODEL=true
      shift
      ;;
    --profile|-p)
      PROFILE="$2"
      CODEX_ARGS+=("-p" "$2")
      shift 2
      ;;
    --effort|-e)
      EFFORT="$2"
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

# Run interactive TUI dropdown selection if requested (or when user simply typed codex-nim)
if [ "$RUN_INTERACTIVE" = true ] || [ "$CHOOSE_MODEL" = true ]; then
  CONFIG_TMP="$(mktemp -t nim_codex_XXXXXX 2>/dev/null || echo "$SCRIPT_DIR/.nim_codex_env")"
  if "$PYTHON_BIN" "$SCRIPT_DIR/scripts/interactive_menu.py" --app codex --output "$CONFIG_TMP"; then
    if [ -f "$CONFIG_TMP" ]; then
      # shellcheck disable=SC1090
      source "$CONFIG_TMP"
      rm -f "$CONFIG_TMP"
      if [ -n "$PROFILE" ]; then
        CODEX_ARGS+=("-p" "$PROFILE")
      fi
      if [ -n "$CODEX_PERM_FLAGS" ]; then
        read -r -a PERM_ARRAY <<< "$CODEX_PERM_FLAGS"
        CODEX_ARGS+=("${PERM_ARRAY[@]}")
      fi
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
NIM_BASE_URL="$BASE_URL"
NIM_MODEL="$MODEL"
NIM_PROXY_PORT="${NIM_PROXY_PORT:-8000}"
EOF
fi
chmod 600 "$ENV_FILE" 2>/dev/null || true

export NVIDIA_API_KEY="$NVIDIA_API_KEY"
export OPENAI_BASE_URL="$BASE_URL"
export OPENAI_API_KEY="$NVIDIA_API_KEY"
export CODEX_MODEL="$MODEL"

# Ensure ~/.codex/nim.config.toml is maintained
mkdir -p "$HOME/.codex"
cat << EOF > "$HOME/.codex/nim.config.toml"
model = "$MODEL"
model_provider = "nvidia_nim"

[model_providers.nvidia_nim]
name = "NVIDIA NIM"
base_url = "$BASE_URL"
env_key = "NVIDIA_API_KEY"
wire_api = "responses"
EOF

if [[ "$MODEL" == *"kimi-k3"* && "$EFFORT" == "medium" ]]; then
  EFFORT="high"
fi

NIM_CONFIG_ARGS=(
  -c "model_provider=\"nvidia_nim\""
  -c "model=\"$MODEL\""
  -c "model_reasoning_effort=\"$EFFORT\""
  -c "model_providers.nvidia_nim.name=\"NVIDIA NIM\""
  -c "model_providers.nvidia_nim.base_url=\"$BASE_URL\""
  -c "model_providers.nvidia_nim.env_key=\"NVIDIA_API_KEY\""
  -c "model_providers.nvidia_nim.wire_api=\"responses\""
)

echo "=========================================================="
echo " Launching Codex CLI with NVIDIA NIM"
echo " Model:       ${MODEL}"
echo " Effort:      ${EFFORT}"
if [ -n "$PROFILE" ]; then
  echo " Profile:     ${PROFILE}"
else
  echo " Profile:     default"
fi
perm_display="Standard manual confirmation prompts"
for a in "${CODEX_ARGS[@]}"; do
  if [[ "$a" == *"--dangerously-bypass-approvals-and-sandbox"* ]]; then
    perm_display="--dangerously-bypass-approvals-and-sandbox (full bypass)"
    break
  elif [[ "$a" == *"never"* ]]; then
    perm_display="-a never (auto-approved commands)"
    break
  elif [[ "$a" == *"--approve-for-me"* ]]; then
    perm_display="--approve-for-me (workspace review)"
    break
  fi
done
echo " Permissions: ${perm_display}"
echo " Endpoint:    ${BASE_URL}"
echo " Provider:    nvidia_nim"
echo " Docs:        https://docs.nvidia.com/nim/large-language-models/latest/ai-assistant-integrations/codex-cli.html"
echo "=========================================================="

exec codex "${NIM_CONFIG_ARGS[@]}" "${CODEX_ARGS[@]}"

