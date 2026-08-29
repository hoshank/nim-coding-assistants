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

mkdir -p "$ZED_CONFIG_DIR"

echo "=========================================================="
echo " Configuring Zed Editor for NVIDIA NIM (macOS / Linux)"
echo " Target: $ZED_SETTINGS_FILE"
echo "=========================================================="

if [ -f "$ZED_SETTINGS_FILE" ]; then
  BACKUP_FILE="${ZED_SETTINGS_FILE}.backup.$(date +%s)"
  cp "$ZED_SETTINGS_FILE" "$BACKUP_FILE"
  echo "Created backup of existing settings at: $BACKUP_FILE"
fi

cp "$EXAMPLE_FILE" "$ZED_SETTINGS_FILE"

echo ""
echo "Successfully wrote NVIDIA NIM settings to $ZED_SETTINGS_FILE!"
echo ""
echo "----------------------------------------------------------"
echo " Important: Set your NVIDIA API Key in Zed"
echo "----------------------------------------------------------"
echo "1. Open Zed Editor."
echo "2. Open the Command Palette (Cmd+Shift+P / Ctrl+Shift+P)."
echo "3. Type and select: 'zed: set api key'."
echo "4. Choose provider 'Nvidia' (or enter it when prompted in the assistant panel)."
echo "5. Paste your NVIDIA API Key (nvapi-...)."
echo "=========================================================="
