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

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

MODEL="${1:-nvidia/nemotron-3-super-120b-a12b}"
API_KEY="${NVIDIA_API_KEY:-}"

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

echo "=========================================================="
echo " Configuring Pi Coding Agent & SoL-Pi for NVIDIA NIM"
echo "=========================================================="

# 1. Update ~/.pi/agent/auth.json
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
echo "[OK] Updated Pi authentication in $AUTH_FILE"

# 2. Update ~/.pi/agent/sol-pi.json
SOL_PI_CONFIG="$PI_AGENT_DIR/sol-pi.json"
cat << EOF > "$SOL_PI_CONFIG"
{
  "version": 1,
  "actionFusion": true,
  "observationPack": true,
  "evidencePreservingReducer": true,
  "evidencePreservingReducerProvider": "nvidia",
  "evidencePreservingReducerModel": "$MODEL",
  "onlineContextCompact": true,
  "cacheWriteReadRatio": 12.5
}
EOF
echo "[OK] Configured SoL-Pi in $SOL_PI_CONFIG"

# 3. Verify SoL-Pi Package & Retry Settings in Pi settings
SETTINGS_FILE="$PI_AGENT_DIR/settings.json"
if command -v python3 &>/dev/null; then
  python3 -c "
import json, os
p = '$SETTINGS_FILE'
data = {}
if os.path.exists(p):
    try:
        with open(p, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        data = {}
data['retry'] = {
    'enabled': True,
    'maxRetries': 20,
    'baseDelayMs': 2000,
    'provider': {
        'maxRetries': 20,
        'maxRetryDelayMs': 60000
    }
}
pkgs = data.get('packages', [])
if 'git:github.com/NVlabs/SoL-Pi' not in pkgs:
    pkgs.append('git:github.com/NVlabs/SoL-Pi')
data['packages'] = pkgs
with open(p, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
"
fi
echo "[OK] Configured Pi retry policy (up to 20 retries) & SoL-Pi package in $SETTINGS_FILE"

# 4. Run preflight check
SOL_PI_CHECKOUT="$PI_AGENT_DIR/git/github.com/NVlabs/SoL-Pi"
if [ -f "$SOL_PI_CHECKOUT/scripts/check-sol-pi-config.mjs" ]; then
  echo "Running SoL-Pi config preflight..."
  node "$SOL_PI_CHECKOUT/scripts/check-sol-pi-config.mjs" --config "$SOL_PI_CONFIG" --require-all-enabled
fi

echo "=========================================================="
echo " Setup Complete! You can now run Pi with NVIDIA NIM:"
echo "   pi-nim"
echo "   pi --provider nvidia --model $MODEL"
echo "=========================================================="
