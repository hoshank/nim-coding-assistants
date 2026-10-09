#!/usr/bin/env bash
set -e

# ==============================================================================
# Update NVIDIA NIM Models & Audit Deprecations
# ==============================================================================

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")/../.." && pwd)"
cd "$SCRIPT_DIR"

VENV_DIR="$SCRIPT_DIR/.venv"

# Use virtualenv python if available
if [ -f "$VENV_DIR/bin/python" ]; then
  PYTHON_BIN="$VENV_DIR/bin/python"
elif command -v python3 &>/dev/null; then
  PYTHON_BIN="python3"
else
  echo "Error: Python 3 not found."
  exit 1
fi

"$PYTHON_BIN" "$SCRIPT_DIR/scripts/update_models.py" "$@"
