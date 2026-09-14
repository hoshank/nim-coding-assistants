#!/usr/bin/env bash
set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")/../.." && pwd)"

ZED_CONFIG_DIR="$HOME/.config/zed"
ZED_SETTINGS_FILE="$ZED_CONFIG_DIR/settings.json"
EXAMPLE_FILE="$SCRIPT_DIR/config/zed_settings.example.json"
ENV_FILE="$SCRIPT_DIR/.env"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$ZED_CONFIG_DIR"

echo "=========================================================="
echo " Configuring Zed Editor for NVIDIA NIM (macOS / Linux)"
echo " Target: $ZED_SETTINGS_FILE"
echo "=========================================================="

# Smart merge or install
if [ -f "$ZED_SETTINGS_FILE" ] && [ -s "$ZED_SETTINGS_FILE" ]; then
  BACKUP_FILE="${ZED_SETTINGS_FILE}.backup.$(date +%s)"
  cp "$ZED_SETTINGS_FILE" "$BACKUP_FILE"
  echo "Created backup of existing settings at: $BACKUP_FILE"

  echo "Merging NVIDIA NIM configuration into existing settings..."
  python3 - << 'PY_EOF' "$EXAMPLE_FILE" "$ZED_SETTINGS_FILE"
import json, sys

example_path = sys.argv[1]
target_path = sys.argv[2]

with open(example_path, "r", encoding="utf-8") as f:
    example = json.load(f)

try:
    with open(target_path, "r", encoding="utf-8") as f:
        existing = json.load(f)
except Exception:
    existing = {}

# Merge language_models.openai_compatible.Nvidia
if "language_models" not in existing:
    existing["language_models"] = {}
if "openai_compatible" not in existing["language_models"]:
    existing["language_models"]["openai_compatible"] = {}

existing["language_models"]["openai_compatible"]["Nvidia"] = example["language_models"]["openai_compatible"]["Nvidia"]

# Set agent defaults if not configured
if "agent" not in existing:
    existing["agent"] = {}
if "default_model" not in existing["agent"]:
    existing["agent"]["default_model"] = example["agent"]["default_model"]
if "tool_permissions" not in existing["agent"]:
    existing["agent"]["tool_permissions"] = example["agent"]["tool_permissions"]
if "show_edit_predictions" not in existing:
    existing["show_edit_predictions"] = True

with open(target_path, "w", encoding="utf-8") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")
PY_EOF
  echo "Merged NVIDIA NIM provider into existing $ZED_SETTINGS_FILE!"
else
  cp "$EXAMPLE_FILE" "$ZED_SETTINGS_FILE"
  echo "Installed fresh NVIDIA NIM settings template to $ZED_SETTINGS_FILE!"
fi

# Optional: Link Zed CLI if installed via /Applications/Zed.app on macOS
if ! command -v zed &>/dev/null && [ -f "/Applications/Zed.app/Contents/MacOS/cli" ]; then
  mkdir -p "$BIN_DIR"
  ln -sf "/Applications/Zed.app/Contents/MacOS/cli" "$BIN_DIR/zed"
  echo "Created 'zed' terminal launcher in $BIN_DIR/zed"
fi

# Check for API Key in .env
API_KEY=""
if [ -f "$ENV_FILE" ]; then
  API_KEY=$(grep -E '^NVIDIA_API_KEY=' "$ENV_FILE" | cut -d '=' -f2- | tr -d ' "' || true)
fi

echo ""
echo "=========================================================="
echo " Zed Editor Integration Ready!"
echo "=========================================================="
if [ -n "$API_KEY" ] && [ "$API_KEY" != "nvapi-your-key-here" ]; then
  MASKED_KEY="${API_KEY:0:10}...${API_KEY: -4}"
  echo "Found configured NVIDIA API Key in .env: $MASKED_KEY"
  echo ""
  echo "To activate in Zed:"
  echo "1. Open Zed Editor (Run 'zed .' or launch Zed.app)."
  echo "2. Open Command Palette (Cmd+Shift+P on Mac, Ctrl+Shift+P on Linux)."
  echo "3. Type: 'zed: set api key' and select 'Nvidia'."
  echo "4. Paste your NVIDIA API Key."
  echo ""
  echo "Tip: Zed also automatically reads the NVIDIA_API_KEY environment"
  echo "variable if launched from a shell where it is exported."
else
  echo "1. Open Zed Editor."
  echo "2. Open Command Palette (Cmd+Shift+P / Ctrl+Shift+P)."
  echo "3. Type: 'zed: set api key' and select 'Nvidia'."
  echo "4. Enter your NVIDIA API Key (starts with nvapi-...)."
fi
echo "=========================================================="
