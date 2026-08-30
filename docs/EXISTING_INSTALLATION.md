# ⚙️ Configuring Existing Installations for NVIDIA NIM

If you already have **Claude Code**, **Codex CLI**, or **Zed Editor** installed and just want to configure them to use **NVIDIA NIM** (without re-installing CLI tools or overwriting your existing dotfiles), follow the instructions below.

---

## Table of Contents
1. [Claude Code (Already Installed)](#1-claude-code-already-installed)
2. [Codex CLI (Already Installed)](#2-codex-cli-already-installed)
3. [Zed Editor (Already Installed)](#3-zed-editor-already-installed)
4. [Toggling Between Native Providers and NVIDIA NIM](#4-toggling-between-native-providers-and-nvidia-nim)

---

## 1. Claude Code (Already Installed)

Because Claude Code strictly requires the Anthropic `/v1/messages` protocol, connecting it to NVIDIA's Cloud API (`https://integrate.api.nvidia.com/v1`) requires running the lightweight translation proxy [`proxy.py`](../proxy.py).

### Step 1: Run the Proxy
You only need Python and a few packages for the translation proxy:

```bash
pip install fastapi uvicorn litellm
# Start the proxy (uses port 8000 by default)
python proxy.py
```

### Step 2: Set Environment Variables
Add these environment variables to your shell profile (`~/.zshrc`, `~/.bashrc`, or Windows System Environment Variables):

#### macOS / Linux (`~/.zshrc` or `~/.bashrc`)
```bash
# NVIDIA NIM API Key (from https://build.nvidia.com/)
export NVIDIA_API_KEY="nvapi-your-key-here"

# Model selection
export MODEL_NAME="nvidia/nemotron-3-ultra-550b-a55b"

# Claude Code NIM routing
export ANTHROPIC_BASE_URL="http://127.0.0.1:8000"
export ANTHROPIC_API_KEY="not-used"
export ANTHROPIC_CUSTOM_MODEL_OPTION="${MODEL_NAME}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${MODEL_NAME}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${MODEL_NAME}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="${MODEL_NAME}"
export CLAUDE_CODE_SUBAGENT_MODEL="${MODEL_NAME}"
```

#### Windows (PowerShell)
```powershell
$env:NVIDIA_API_KEY = "nvapi-your-key-here"
$env:MODEL_NAME = "nvidia/nemotron-3-ultra-550b-a55b"

$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:8000"
$env:ANTHROPIC_API_KEY = "not-used"
$env:ANTHROPIC_CUSTOM_MODEL_OPTION = $env:MODEL_NAME
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $env:MODEL_NAME
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $env:MODEL_NAME
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $env:MODEL_NAME
$env:CLAUDE_CODE_SUBAGENT_MODEL = $env:MODEL_NAME
```

### Step 3: Run Claude
```bash
claude
```

---

## 2. Codex CLI (Already Installed)

Codex CLI connects directly to OpenAI-compatible endpoints with zero proxy needed.

### Option A: Via Environment Variables

#### macOS / Linux
```bash
export OPENAI_BASE_URL="https://integrate.api.nvidia.com/v1"
export OPENAI_API_KEY="nvapi-your-key-here"
export CODEX_MODEL="nvidia/nemotron-3-ultra-550b-a55b"

codex
```

#### Windows (PowerShell)
```powershell
$env:OPENAI_BASE_URL = "https://integrate.api.nvidia.com/v1"
$env:OPENAI_API_KEY = "nvapi-your-key-here"
$env:CODEX_MODEL = "nvidia/nemotron-3-ultra-550b-a55b"

codex
```

### Option B: Via `config.toml`

Edit your existing `config.toml` file:
- **macOS / Linux**: `~/.codex/config.toml`
- **Windows**: `%USERPROFILE%\.codex\config.toml`

Add or update the following sections:

```toml
model = "nvidia/nemotron-3-ultra-550b-a55b"

[openai]
base_url = "https://integrate.api.nvidia.com/v1"
api_key = "nvapi-your-key-here"
```

---

## 3. Zed Editor (Already Installed)

To add NVIDIA NIM to your existing Zed setup without overwriting your custom themes, keymaps, or editor preferences:

### Step 1: Add the `Nvidia` Provider to `settings.json`

Open your Zed settings:
- **macOS / Linux**: `~/.config/zed/settings.json` (or press `Cmd + ,`)
- **Windows**: `%APPDATA%\Zed\settings.json` (or press `Ctrl + ,`)

Merge the `language_models` block and `agent.default_model` into your JSON:

```json
{
  "agent": {
    "default_model": {
      "provider": "Nvidia",
      "model": "nvidia/nemotron-3-ultra-550b-a55b"
    }
  },
  "language_models": {
    "openai_compatible": {
      "Nvidia": {
        "api_url": "https://integrate.api.nvidia.com/v1",
        "available_models": [
          {
            "name": "nvidia/nemotron-3-ultra-550b-a55b",
            "display_name": "NVIDIA Nemotron 3 Ultra 550B",
            "max_tokens": 1048576,
            "max_output_tokens": 32768,
            "max_completion_tokens": 200000,
            "capabilities": {
              "tools": true,
              "images": false,
              "parallel_tool_calls": true,
              "prompt_cache_key": false,
              "chat_completions": true,
              "interleaved_reasoning": true
            }
          },
          {
            "name": "nvidia/nemotron-3-super-120b-a12b",
            "display_name": "NVIDIA Nemotron 3 Super 120B",
            "max_tokens": 1048576,
            "max_output_tokens": 32768,
            "max_completion_tokens": 200000,
            "capabilities": {
              "tools": true,
              "images": false,
              "parallel_tool_calls": true,
              "prompt_cache_key": false,
              "chat_completions": true,
              "interleaved_reasoning": true
            }
          },
          {
            "name": "deepseek-ai/deepseek-v4-pro",
            "display_name": "DeepSeek V4 Pro",
            "max_tokens": 1048500,
            "max_output_tokens": 32768,
            "max_completion_tokens": 200000,
            "capabilities": {
              "tools": true,
              "images": false,
              "parallel_tool_calls": true,
              "prompt_cache_key": false,
              "chat_completions": true
            }
          },
          {
            "name": "deepseek-ai/deepseek-v4-flash-0731",
            "display_name": "DeepSeek V4 Flash (0731)",
            "max_tokens": 1048576,
            "max_output_tokens": 32768,
            "max_completion_tokens": 200000,
            "capabilities": {
              "tools": true,
              "images": false,
              "parallel_tool_calls": true,
              "prompt_cache_key": false,
              "chat_completions": true
            }
          },
          {
            "name": "minimaxai/minimax-m3",
            "display_name": "MiniMax M3 (Vision)",
            "max_tokens": 524288,
            "max_output_tokens": 32768,
            "max_completion_tokens": 200000,
            "capabilities": {
              "tools": true,
              "images": true,
              "parallel_tool_calls": true,
              "prompt_cache_key": false,
              "chat_completions": true
            }
          },
          {
            "name": "z-ai/glm-5.2",
            "display_name": "GLM 5.2",
            "max_tokens": 1048576,
            "max_output_tokens": 32768,
            "max_completion_tokens": 200000,
            "capabilities": {
              "tools": true,
              "images": false,
              "parallel_tool_calls": true,
              "prompt_cache_key": false,
              "chat_completions": true
            }
          },
          {
            "name": "thinkingmachines/inkling",
            "display_name": "Thinking Machines Inkling",
            "max_tokens": 131072,
            "max_output_tokens": 32768,
            "max_completion_tokens": 131072,
            "capabilities": {
              "tools": true,
              "images": true,
              "parallel_tool_calls": true,
              "prompt_cache_key": false,
              "chat_completions": true,
              "interleaved_reasoning": true
            }
          }
        ]
      }
    }
  }
}
```

### Step 2: Set API Key in Zed
1. In Zed, press `Cmd + Shift + P` (macOS) or `Ctrl + Shift + P` (Windows/Linux).
2. Type **`zed: set api key`** and press Enter.
3. Choose provider **`Nvidia`**.
4. Paste your NVIDIA API key (`nvapi-...`).

---

## 4. Toggling Between Native Providers and NVIDIA NIM

If you frequently switch between Anthropic/OpenAI direct subscriptions and NVIDIA NIM:

### Recommended Helper Functions for `~/.zshrc` / `~/.bashrc`:

```bash
# Launch Claude with NVIDIA NIM
claude-nim() {
  local model="${1:-nvidia/nemotron-3-ultra-550b-a55b}"
  local port="${2:-8000}"

  # Start proxy if not running
  if ! curl -s -f -o /dev/null "http://127.0.0.1:${port}/health" 2>/dev/null; then
    echo "Starting NIM background proxy on port ${port}..."
    python path/to/proxy.py --port "${port}" > /tmp/nim_proxy.log 2>&1 &
    sleep 1
  fi

  ANTHROPIC_BASE_URL="http://127.0.0.1:${port}" \
  ANTHROPIC_API_KEY="not-used" \
  MODEL_NAME="${model}" \
  ANTHROPIC_CUSTOM_MODEL_OPTION="${model}" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="${model}" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="${model}" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="${model}" \
  CLAUDE_CODE_SUBAGENT_MODEL="${model}" \
  claude "${@:3}"
}

# Launch Codex with NVIDIA NIM
codex-nim() {
  local model="${1:-nvidia/nemotron-3-ultra-550b-a55b}"
  OPENAI_BASE_URL="https://integrate.api.nvidia.com/v1" \
  OPENAI_API_KEY="${NVIDIA_API_KEY}" \
  CODEX_MODEL="${model}" \
  codex "${@:2}"
}
```

Now running plain `claude` or `codex` will use your normal default subscriptions, while `claude-nim` and `codex-nim` will route to NVIDIA NIM!
