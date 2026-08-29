# 🚀 NVIDIA NIM Assistant Bridge (Claude Code & Codex CLI)

A lightweight, cross-platform bridge and launcher toolkit to run **Claude Code** and **Codex CLI** with **NVIDIA NIM** (NVIDIA Cloud API Catalog and self-hosted NIM inference microservices).

Supports **macOS**, **Linux**, and **Windows**.

---

## 📌 Why is this needed?

- **Claude Code**: Natively speaks the Anthropic `/v1/messages` protocol. While self-hosted NIM containers provide this endpoint, NVIDIA's Cloud Catalog (`https://integrate.api.nvidia.com/v1`) uses the OpenAI format (`/v1/chat/completions`). The included Python proxy translates Anthropic streaming SSE & tool-calling requests to NVIDIA's OpenAI format in real-time, while stripping Anthropic-specific internal parameters (`output_config`, `context_management`).
- **Codex CLI**: Natively supports OpenAI-compatible endpoints directly. The launcher automates pointing Codex CLI to NVIDIA NIM with your API key and chosen model.

---

## 📁 Repository Structure

```text
nim-assistant-bridge/
├── proxy.py                      # Fast, lightweight FastAPI Anthropic <-> NIM translator
├── requirements.txt              # Python dependencies
├── .env.example                  # Configuration template
├── config/
│   ├── models.json               # Curated coding models on NVIDIA NIM
│   └── codex_config.example.toml # Optional ~/.codex/config.toml template
└── scripts/
    ├── mac-linux/
    │   ├── install.sh            # 1-click installer for macOS / Linux
    │   ├── claude-nim.sh         # Claude Code launcher
    │   └── codex-nim.sh          # Codex CLI launcher
    └── windows/
        ├── install.ps1           # 1-click installer for Windows (PowerShell)
        ├── install.bat           # 1-click installer for Windows (CMD)
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

#### 2. Run
```bash
# Launch Claude Code with NVIDIA NIM
claude-nim

# Launch Codex CLI with NVIDIA NIM
codex-nim
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
*(Or in `cmd.exe`: double-click or run `.\scripts\windows\install.bat`)*

#### 2. Run
Open a new terminal window:

```powershell
# Launch Claude Code with NVIDIA NIM
claude-nim

# Launch Codex CLI with NVIDIA NIM
codex-nim
```

---

## 🤖 Curated Models for Coding & Agents

| Model ID | Provider | Tool Calling | Best Used For |
| :--- | :--- | :---: | :--- |
| `meta/llama-3.3-70b-instruct` | Meta | ✅ Yes | **Recommended Default** for general coding & agents |
| `nvidia/nemotron-3-super-120b-a12b` | NVIDIA | ✅ Yes | Complex multi-step reasoning & architecture |
| `qwen/qwen2.5-coder-32b-instruct` | Qwen | ✅ Yes | Fast code generation & multiple languages |
| `mistralai/mistral-large-2-instruct` | Mistral | ✅ Yes | Multilingual codebases & reasoning |
| `deepseek-ai/deepseek-r1` | DeepSeek | ⚠️ No | Algorithmic logic & pure problem solving |
| `meta/llama-3.1-405b-instruct` | Meta | ✅ Yes | Massive scale reasoning |

---

## ⚙️ Advanced Usage & Flags

### Claude Code (`claude-nim`)

```bash
# Use a specific model
claude-nim --model qwen/qwen2.5-coder-32b-instruct

# Change the local proxy port
claude-nim --port 8080

# Update your NVIDIA API Key
claude-nim --key nvapi-your-new-key

# Check proxy background status or view logs
claude-nim --status
claude-nim --logs

# Stop the proxy daemon
claude-nim --stop

# Pass standard Claude Code flags directly
claude-nim -p "Review this file"
claude-nim --verbose
```

### Codex CLI (`codex-nim`)

```bash
# Use a specific model
codex-nim --model meta/llama-3.3-70b-instruct

# Set a custom endpoint (e.g. self-hosted NIM)
codex-nim --url http://localhost:8000/v1
```

---

## 🌐 Self-Hosted NIM Deployment

If you are running your own local or Kubernetes NIM container (e.g. at `http://192.168.1.100:8000/v1`), configure your `.env`:

```bash
NIM_BASE_URL="http://192.168.1.100:8000/v1"
NVIDIA_API_KEY="not-used" # or your self-hosted auth token
NIM_MODEL="meta/llama-3.3-70b-instruct"
```

---

## 🛠️ Requirements
- Python 3.10+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) (`npm install -g @anthropic-ai/claude-code`)
- [Codex CLI](https://github.com/openai/codex) (optional, if using Codex)
- An NVIDIA API Key from [build.nvidia.com](https://build.nvidia.com/)
