# 🚀 NIM Coding Assistants (Claude Code, Codex CLI & Zed Editor)

[![macOS](https://img.shields.io/badge/macOS-supported-brightgreen?logo=apple)]()
[![Linux](https://img.shields.io/badge/Linux-supported-brightgreen?logo=linux)]()
[![Windows](https://img.shields.io/badge/Windows-supported-brightgreen?logo=windows)]()
[![NVIDIA NIM](https://img.shields.io/badge/NVIDIA-NIM%20Catalog-76B900?logo=nvidia)]()

A lightweight, cross-platform bridge and launcher toolkit to run **Claude Code**, **Codex CLI**, and **Zed Editor** with **NVIDIA NIM** (NVIDIA Cloud API Catalog and self-hosted NIM microservices).

---

## 📌 Architecture Overview

```mermaid
graph TD
    subgraph Clients["AI Coding Clients"]
        CC["Claude Code CLI (Anthropic Format)"]
        CX["Codex CLI (OpenAI Format)"]
        ZD["Zed Editor (OpenAI Compatible)"]
    end

    subgraph Bridge["Local Bridge (proxy.py)"]
        PRX["FastAPI Streaming Proxy (127.0.0.1:8000)<br/>• Realtime Anthropic ↔ OpenAI Translation<br/>• Parameter Sanitization<br/>• Tool-Calling Bridge<br/>• Model Alias Mapping"]
    end

    subgraph NIM["NVIDIA NIM Backend"]
        CAT["NVIDIA Cloud API (integrate.api.nvidia.com)"]
        SH["Self-Hosted Local/K8s NIM Container"]
    end

    CC -->|Anthropic /v1/messages| PRX
    PRX -->|OpenAI /v1/chat/completions| CAT
    PRX -.->|OpenAI /v1/chat/completions| SH

    CX -->|Direct OpenAI Format| CAT
    CX -.->|Direct OpenAI Format| SH

    ZD -->|Direct OpenAI Format| CAT
    ZD -.->|Direct OpenAI Format| SH
```

---

## 🤖 Active Available Models

| Model ID | Provider | Tool Calling | Vision | Context Window | Best Used For |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **`nvidia/nemotron-3-ultra-550b-a55b`** | NVIDIA | ✅ Yes | ❌ | 1,048,576 | **Recommended Default** — Ultra 550B flagship |
| `nvidia/nemotron-3-super-120b-a12b` | NVIDIA | ✅ Yes | ❌ | 1,048,576 | High-speed reasoning & agentic planning |
| `deepseek-ai/deepseek-v4-pro` | DeepSeek | ✅ Yes | ❌ | 1,048,500 | Advanced coding & refactoring |
| `deepseek-ai/deepseek-v4-flash-0731`| DeepSeek | ✅ Yes | ❌ | 1,048,576 | Low-latency completions |
| `minimaxai/minimax-m3` | MiniMax | ✅ Yes | ✅ Yes | 524,288 | Multimodal vision & UI tasks |
| `z-ai/glm-5.2` | Z-AI | ✅ Yes | ❌ | 1,048,576 | General coding and reasoning |
| `thinkingmachines/inkling` | Thinking Machines | ✅ Yes | ✅ Yes | 131,072 | Interleaved reasoning, vision & tools |

> 💡 *Need to add or modify models later? Check the [Adding Models Guide](docs/ADDING_MODELS.md).*

---

## ⚡ Quickstart

### 🍎 macOS & 🐧 Linux

#### 1. Clone & Install
```bash
git clone https://github.com/hoshank/nim-coding-assistants.git
cd nim-coding-assistants

# Run installer (sets up virtualenv & global CLI commands)
./scripts/mac-linux/install.sh
```

#### 2. Launch
```bash
# Launch Claude Code (uses Nemotron 3 Ultra 550B default)
claude-nim

# Launch Codex CLI
codex-nim

# Configure Zed Editor automatically
./scripts/mac-linux/setup-zed.sh
```

---

### 🪟 Windows (PowerShell or Command Prompt)

#### 1. Clone & Install
Open PowerShell or Command Prompt:

```powershell
git clone https://github.com/hoshank/nim-coding-assistants.git
cd nim-coding-assistants

# Run PowerShell installer
powershell -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
```
*(Or in `cmd.exe`: double-click / run `.\scripts\windows\install.bat`)*

#### 2. Launch
Open a new terminal window:

```powershell
# Launch Claude Code
claude-nim

# Launch Codex CLI
codex-nim

# Configure Zed Editor automatically
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup-zed.ps1
```

---

## ⚡ Already Have Tools Installed? (Quick Configuration)

If you already have **Claude Code**, **Codex CLI**, or **Zed Editor** installed and just want to configure them to point to NVIDIA NIM without re-installing or overwriting custom configurations, check out:

👉 **[Guide: Configuring Existing Installations for NVIDIA NIM](docs/EXISTING_INSTALLATION.md)**

---

## 📖 In-Depth Guides

- ⚙️ **[Configuring Existing Installations](docs/EXISTING_INSTALLATION.md)**: Zero-fuss configuration for tools already installed on your system.
- 🧩 **[Zed Editor Setup Guide](docs/ZED_SETUP.md)**: Full instructions for setting up Zed's Assistant panel, inline edit predictions, and setting your API key via `Cmd+Shift+P`.
- 🤖 **[Claude Code Integration Guide](docs/CLAUDE_CODE.md)**: Details on the Anthropic-to-OpenAI translation layer, parameter stripping (`output_config`, `context_management`), and subagent handling.
- 💻 **[Codex CLI Integration Guide](docs/CODEX_CLI.md)**: How to configure Codex CLI via `codex-nim` or `~/.codex/config.toml`.
- ➕ **[Adding & Updating Models Guide](docs/ADDING_MODELS.md)**: Step-by-step instructions to add newly released NIM models.

---

## ⚙️ CLI Cheat Sheet

### Claude Code (`claude-nim`)

```bash
# Launch with a specific active model
claude-nim --model nvidia/nemotron-3-super-120b-a12b
claude-nim --model deepseek-ai/deepseek-v4-pro
claude-nim --model minimaxai/minimax-m3

# Run a non-interactive one-off prompt
claude-nim -p "Review this PR diff"

# Change local proxy port
claude-nim --port 8080

# Check background proxy status & logs
claude-nim --status
claude-nim --logs

# Stop the background proxy daemon
claude-nim --stop
```

### Codex CLI (`codex-nim`)

```bash
# Launch with a specific model
codex-nim --model nvidia/nemotron-3-ultra-550b-a55b

# Point to custom or self-hosted NIM endpoint
codex-nim --url http://localhost:8000/v1
```

---

## 🌐 Self-Hosted NIM Deployment

If you are running your own local or Kubernetes NIM container (e.g. at `http://192.168.1.100:8000/v1`), configure `.env`:

```bash
NIM_BASE_URL="http://192.168.1.100:8000/v1"
NVIDIA_API_KEY="not-used"
NIM_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
```

---

## ❓ Troubleshooting & FAQs

<details>
<summary><b>1. Port 8000 is already in use</b></summary>

Specify a different port using the `--port` flag:
```bash
claude-nim --port 8088
```
Or update `NIM_PROXY_PORT=8088` in `.env`.
</details>

<details>
<summary><b>2. Claude Code returns 400 Validation Error on unknown parameters</b></summary>

Claude Code sends Anthropic-specific internal parameters (`output_config`, `context_management`). The bridge proxy automatically strips these parameters before forwarding to NVIDIA NIM. Ensure your proxy is running via `claude-nim`.
</details>

<details>
<summary><b>3. Claude Code returns 404 Model Not Found for Haiku or Sonnet</b></summary>

Claude Code internally queries aliases (`haiku`, `sonnet`, `opus`) for background tasks. The `claude-nim` launcher maps all alias variables (`ANTHROPIC_DEFAULT_HAIKU_MODEL`, etc.) to your selected NIM model to prevent 404 errors.
</details>

<details>
<summary><b>4. Windows: PowerShell script execution disabled</b></summary>

If PowerShell displays an execution policy error, run with `-ExecutionPolicy Bypass`:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\install.ps1
```
</details>

---

## 🛠️ Prerequisites
- Python 3.10+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) (`npm install -g @anthropic-ai/claude-code`)
- [Codex CLI](https://github.com/openai/codex) (optional)
- [Zed Editor](https://zed.dev/) (optional)
- NVIDIA API Key from [build.nvidia.com](https://build.nvidia.com/)
