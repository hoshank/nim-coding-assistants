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

# Locate aider binary
AIDER_BIN=""
if command -v aider &>/dev/null; then
  AIDER_BIN="$(command -v aider)"
elif [ -x "$HOME/.local/bin/aider" ]; then
  AIDER_BIN="$HOME/.local/bin/aider"
elif [ -x "$SCRIPT_DIR/../aider/.venv/bin/aider" ]; then
  AIDER_BIN="$SCRIPT_DIR/../aider/.venv/bin/aider"
elif command -v uvx &>/dev/null; then
  AIDER_BIN="uvx --from aider-chat aider"
fi

DEFAULT_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
DEFAULT_EDITOR_MODEL="nvidia/nemotron-3-super-120b-a12b"
MODEL="${NIM_MODEL:-$DEFAULT_MODEL}"
BASE_URL="${NIM_BASE_URL:-https://integrate.api.nvidia.com/v1}"
DEFAULT_EFFORT="medium"
EFFORT="${NIM_EFFORT:-$DEFAULT_EFFORT}"

show_help() {
  cat << 'EOF'
Aider with NVIDIA NIM (Mac / Linux)

Usage:
  aider-nim [options] [aider options...]

Options:
  --model, -m <name>       Specify the primary model (default: nvidia/nemotron-3-ultra-550b-a55b)
  --choose, -c             Interactively choose model and mode from the NIM catalog
  --architect, -A          Run in Architect mode (Nemotron 3 Ultra plans, Super 120B applies diffs)
  --editor-model <name>    Specify custom editor model for architect mode (default: nemotron-3-super-120b)
  --effort, -e <level>     Specify reasoning effort (low, medium, high - default: medium)
  --edit-format <format>   Specify edit format (diff, whole, udiff, architect - default: diff)
  --no-auto-commits        Disable automatic git commits after each AI edit
  --key <key>              Set or update your NVIDIA API key
  --url <url>              Set NVIDIA Base URL (default: https://integrate.api.nvidia.com/v1)
  --help, -h               Show this help message

All other arguments are forwarded directly to `aider`.

Supported NIM Catalog Models:
  - nvidia/nemotron-3-ultra-550b-a55b (Recommended default)
  - nvidia/nemotron-3-super-120b-a12b (High-efficiency reasoning & editor)
  - deepseek-ai/deepseek-v4-pro-0813  (Advanced coding & refactoring)
  - deepseek-ai/deepseek-v4-flash-0731(Low-latency completions)
  - minimaxai/minimax-m3              (Vision & UI understanding)
  - z-ai/glm-5.2                      (General coding & reasoning)
  - thinkingmachines/inkling          (Interleaved reasoning & vision)
  - moonshotai/kimi-k3                (Long-horizon reasoning & coding)
EOF
}

# Check if interactive selection menu should run (default when typing `aider-nim` in terminal with no flags)
RUN_INTERACTIVE=false
if [ $# -eq 0 ] && [ -t 0 ]; then
  RUN_INTERACTIVE=true
fi

AIDER_ARGS=()
CHOOSE_MODEL=false
USE_ARCHITECT=false
EDITOR_MODEL="$DEFAULT_EDITOR_MODEL"
EDIT_FORMAT=""
AUTO_COMMITS=true

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
    --architect|-A)
      USE_ARCHITECT=true
      shift
      ;;
    --editor-model)
      EDITOR_MODEL="$2"
      shift 2
      ;;
    --effort|-e)
      EFFORT="$2"
      shift 2
      ;;
    --edit-format)
      EDIT_FORMAT="$2"
      shift 2
      ;;
    --no-auto-commits)
      AUTO_COMMITS=false
      shift
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
      AIDER_ARGS+=("$1")
      shift
      ;;
  esac
done

# Run interactive TUI dropdown selection if requested
if [ "$RUN_INTERACTIVE" = true ] || [ "$CHOOSE_MODEL" = true ]; then
  CONFIG_TMP="$(mktemp -t nim_aider_XXXXXX 2>/dev/null || echo "$SCRIPT_DIR/.nim_aider_env")"
  if "$PYTHON_BIN" "$SCRIPT_DIR/scripts/interactive_menu.py" --app aider --output "$CONFIG_TMP"; then
    if [ -f "$CONFIG_TMP" ]; then
      # shellcheck disable=SC1090
      source "$CONFIG_TMP"
      rm -f "$CONFIG_TMP"
      if [ "$AIDER_MODE" = "architect" ]; then
        USE_ARCHITECT=true
      fi
      if [ "$AIDER_AUTO_COMMITS" = "false" ]; then
        AUTO_COMMITS=false
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
fi
chmod 600 "$ENV_FILE" 2>/dev/null || true

# Format model name with openai/ prefix if not already prefixed
PREFIXED_MODEL="$MODEL"
if [[ "$PREFIXED_MODEL" != openai/* && "$PREFIXED_MODEL" != nvidia_nim/* ]]; then
  PREFIXED_MODEL="openai/$MODEL"
fi

PREFIXED_EDITOR_MODEL="$EDITOR_MODEL"
if [[ "$PREFIXED_EDITOR_MODEL" != openai/* && "$PREFIXED_EDITOR_MODEL" != nvidia_nim/* ]]; then
  PREFIXED_EDITOR_MODEL="openai/$EDITOR_MODEL"
fi

# Export environment variables for Aider & LiteLLM
export NVIDIA_API_KEY="$NVIDIA_API_KEY"
export NVIDIA_NIM_API_KEY="$NVIDIA_API_KEY"
export OPENAI_API_KEY="$NVIDIA_API_KEY"
export OPENAI_API_BASE="$BASE_URL"
export AIDER_MODEL="$PREFIXED_MODEL"

# Prepare model settings and metadata paths
SETTINGS_FILE="$SCRIPT_DIR/config/aider.model.settings.yml"
METADATA_FILE="$SCRIPT_DIR/config/aider.model.metadata.json"

CONFIG_FLAGS=(
  "--model" "$PREFIXED_MODEL"
  "--openai-api-base" "$BASE_URL"
  "--no-show-model-warnings"
)

if [ -f "$SETTINGS_FILE" ]; then
  CONFIG_FLAGS+=("--model-settings-file" "$SETTINGS_FILE")
fi

if [ -f "$METADATA_FILE" ]; then
  CONFIG_FLAGS+=("--model-metadata-file" "$METADATA_FILE")
fi

if [ -n "$EDIT_FORMAT" ]; then
  CONFIG_FLAGS+=("--edit-format" "$EDIT_FORMAT")
fi

if [ "$USE_ARCHITECT" = true ]; then
  CONFIG_FLAGS+=(
    "--architect"
    "--editor-model" "$PREFIXED_EDITOR_MODEL"
    "--editor-edit-format" "editor-diff"
  )
fi

if [ "$AUTO_COMMITS" = false ]; then
  CONFIG_FLAGS+=("--no-auto-commits")
fi

if [ -n "$EFFORT" ]; then
  if [[ "$PREFIXED_MODEL" == *"kimi-k3"* && "$EFFORT" == "medium" ]]; then
    EFFORT="high"
  fi
  CONFIG_FLAGS+=("--reasoning-effort" "$EFFORT")
fi

# Verify aider is available
if [ -z "$AIDER_BIN" ]; then
  echo "Error: Aider CLI is not installed."
  echo "You can install it quickly using uv:"
  echo "  uv tool install --python 3.12 aider-chat"
  echo "Or run ./setup.sh to configure automatically."
  exit 1
fi

mode_display="Standard Pair Programming (Diff format)"
if [ "$USE_ARCHITECT" = true ]; then
  mode_display="Architect Mode (Architect: ${PREFIXED_MODEL}, Editor: ${PREFIXED_EDITOR_MODEL})"
fi

echo "=========================================================="
echo " Launching Aider with NVIDIA NIM"
echo " Model:       ${PREFIXED_MODEL}"
if [ "$USE_ARCHITECT" = true ]; then
  echo " Editor:      ${PREFIXED_EDITOR_MODEL}"
fi
echo " Mode:        ${mode_display}"
echo " Effort:      ${EFFORT}"
echo " Commits:     $([ "$AUTO_COMMITS" = true ] && echo "Auto-commit enabled" || echo "Manual git commits")"
echo " Endpoint:    ${BASE_URL}"
echo " Docs:        https://aider.chat/docs/llms/other.html"
echo "=========================================================="

# Execute aider
if [[ "$AIDER_BIN" == uvx* ]]; then
  exec uvx --from aider-chat aider "${CONFIG_FLAGS[@]}" "${AIDER_ARGS[@]}"
else
  exec "$AIDER_BIN" "${CONFIG_FLAGS[@]}" "${AIDER_ARGS[@]}"
fi
