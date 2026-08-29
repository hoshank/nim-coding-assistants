# 💻 Codex CLI with NVIDIA NIM Setup Guide

This guide explains how to use **Codex CLI** with **NVIDIA NIM** models.

---

## ⚡ Direct OpenAI-Compatible Connection

Unlike Claude Code, **Codex CLI** natively supports OpenAI-compatible endpoints directly without needing a local translation proxy.

---

## 🚀 Quickstart

### macOS & Linux
```bash
# Launch with the default model (Nemotron 3 Ultra 550B)
codex-nim

# Launch with a specific model
codex-nim --model deepseek-ai/deepseek-v4-pro
```

### Windows
```powershell
codex-nim
codex-nim --model deepseek-ai/deepseek-v4-pro
```

---

## ⚙️ Configuration Files vs Environment Variables

The `codex-nim` launcher automatically sets:
```bash
export OPENAI_BASE_URL="https://integrate.api.nvidia.com/v1"
export OPENAI_API_KEY="nvapi-your-key-here"
export CODEX_MODEL="nvidia/nemotron-3-ultra-550b-a55b"
```

If you prefer to configure Codex CLI globally via its configuration file:

1. Create `~/.codex/config.toml` (Mac/Linux) or `%USERPROFILE%\.codex\config.toml` (Windows):

```toml
model = "nvidia/nemotron-3-ultra-550b-a55b"

[openai]
base_url = "https://integrate.api.nvidia.com/v1"
api_key = "nvapi-your-key-here"
```

2. You can then run `codex` directly without extra environment variables.
