# 🚀 NVIDIA NIM Assistant Bridge (Claude Code, Codex CLI & Zed Editor)

A lightweight, cross-platform bridge and launcher toolkit to run **Claude Code**, **Codex CLI**, and **Zed Editor** with **NVIDIA NIM** (NVIDIA Cloud API Catalog and self-hosted NIM inference microservices).

Supports **macOS**, **Linux**, and **Windows**.

---

## 📌 Features & Architecture

- **Claude Code**: Natively speaks the Anthropic `/v1/messages` protocol. The included Python proxy translates Anthropic streaming SSE & tool-calling requests into NVIDIA NIM OpenAI-compatible format in real-time, while stripping Anthropic-specific internal parameters (`output_config`, `context_management`).
- **Codex CLI**: Connects directly to NVIDIA NIM via OpenAI-compatible endpoints with auto-configured environment variables.
- **Zed Editor**: Ready-to-use `settings.json` configuration for Zed's Assistant panel with custom model profiles, tool calling, and token limits.

---

## 🤖 Active Available Models

| Model ID | Provider | Tool Calling | Vision | Max Tokens | Description |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `nvidia/nemotron-3-ultra-550b-a55b` | NVIDIA | ✅ Yes | ❌ | 1,048,576 | **Recommended Default** — Flagship Ultra 550B model |
| `nvidia/nemotron-3-super-120b-a12b` | NVIDIA | ✅ Yes | ❌ | 1,048,576 | High-speed, complex reasoning & agentic planning |
| `deepseek-ai/deepseek-v4-pro` | DeepSeek | ✅ Yes | ❌ | 1,048,500 | High-performance coding and refactoring |
| `deepseek-ai/deepseek-v4-flash-0731`| DeepSeek | ✅ Yes | ❌ | 1,048,576 | Low-latency completions & code generation |
| `minimaxai/minimax-m3` | MiniMax | ✅ Yes | ✅ Yes | 524,288 | Multimodal vision & UI understanding |
| `z-ai/glm-5.2` | Z-AI | ✅ Yes | ❌ | 1,048,576 | General coding and reasoning |
| `thinkingmachines/inkling` | Thinking Machines | ✅ Yes | ✅ Yes | 131,072 | Interleaved reasoning, vision, and tool calling |

> 💡 *Note: To add or update models later, simply edit `config/models.json` and `config/zed_settings.example.json`.*

---

## 📁 Repository Structure

```text
nim-assistant-bridge/
├── proxy.py                      # Fast FastAPI Anthropic <-> NIM translator
├── requirements.txt              # Python dependencies
├── .env.example                  # Configuration template
├── config/
│   ├── models.json               # Active available models list
│   ├── zed_settings.example.json # Zed Editor configuration template
│   └── codex_config.example.toml # Optional ~/.codex/config.toml template
└── scripts/
    ├── mac-linux/
    │   ├── install.sh            # 1-click installer for macOS / Linux
    │   ├── setup-zed.sh          # Auto-configures ~/.config/zed/settings.json
    │   ├── claude-nim.sh         # Claude Code launcher
    │   └── codex-nim.sh          # Codex CLI launcher
    └── windows/
        ├── install.ps1           # 1-click installer for Windows (PowerShell)
        ├── install.bat           # 1-click installer for Windows (CMD)
        ├── setup-zed.ps1         # Auto-configures %APPDATA%\Zed\settings.json
        ├── claude-nim.ps1        # Claude Code launcher (PowerShell)
        ├── codex-nim.ps1         # Codex CLI launcher (PowerShell)
        ├── claude-nim.bat        # Claude Code wrapper for cmd.exe
        └── codex-nim.bat         # Codex CLI wrapper for cmd.exe
```

---

## ⚡ Quickstart

### 🍎 macOS & 🐧 Linux

#### 1. Clone & Install
```bash
git clone <your-repo-url> nim-assistant-bridge
cd nim-assistant-bridge

# Run installer (sets up virtualenv & global commands)
./scripts/mac-linux/install.sh
```

#### 2. Launch Assistants
```bash
# Launch Claude Code with NVIDIA NIM (default: nemotron-3-ultra-550b-a55b)
claude-nim

# Launch Codex CLI with NVIDIA NIM
codex-nim

# Configure Zed Editor automatically
./scripts/mac-linux/setup-zed.sh
```

---

### 🪟 Windows (PowerShell or Command Prompt)

#### 1. Clone & Install
Open PowerShell or Command Prompt:

```powershell
git clone <your-repo-url> nim-assistant-bridge
cd nim-assistant-bridge

# Run PowerShell installer
powershell -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
```
*(Or in `cmd.exe`: run `.\scripts\windows\install.bat`)*

#### 2. Launch Assistants
Open a new terminal window:

```powershell
# Launch Claude Code with NVIDIA NIM
claude-nim

# Launch Codex CLI with NVIDIA NIM
codex-nim

# Configure Zed Editor automatically
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup-zed.ps1
```

---

## 🧩 Setting Up Zed Editor Manually

If you prefer to configure Zed manually:

1. Open `~/.config/zed/settings.json` (Mac/Linux) or `%APPDATA%\Zed\settings.json` (Windows).
2. Copy the contents of [`config/zed_settings.example.json`](config/zed_settings.example.json) into your settings file.
3. Open Zed, press `Cmd+Shift+P` / `Ctrl+Shift+P`, select **`zed: set api key`**, select provider **`Nvidia`**, and enter your API key (`nvapi-...`).

---

## ⚙️ Advanced CLI Flags

### Claude Code (`claude-nim`)

```bash
# Switch to another active model
claude-nim --model nvidia/nemotron-3-super-120b-a12b
claude-nim --model deepseek-ai/deepseek-v4-pro
claude-nim --model minimaxai/minimax-m3

# Check proxy background status or view logs
claude-nim --status
claude-nim --logs

# Stop the proxy daemon
claude-nim --stop

# Pass standard Claude Code flags directly
claude-nim -p "Review this codebase"
```

### Codex CLI (`codex-nim`)

```bash
# Use a specific model
codex-nim --model nvidia/nemotron-3-ultra-550b-a55b

# Point to a custom or self-hosted NIM endpoint
codex-nim --url http://localhost:8000/v1
```

---

## 🌐 Self-Hosted NIM Deployment

If running your own local or Kubernetes NIM container (e.g. `http://192.168.1.100:8000/v1`), configure `.env`:

```bash
NIM_BASE_URL="http://192.168.1.100:8000/v1"
NVIDIA_API_KEY="not-used"
NIM_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
```

---

## 🛠️ Requirements
- Python 3.10+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) (`npm install -g @anthropic-ai/claude-code`)
- [Codex CLI](https://github.com/openai/codex) (optional)
- [Zed Editor](https://zed.dev/) (optional)
- An NVIDIA API Key from [build.nvidia.com](https://build.nvidia.com/)
