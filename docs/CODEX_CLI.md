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

The `codex-nim` launcher automatically configures the `nvidia_nim` provider and launches Codex with:
```bash
codex -c model_provider="nvidia_nim" -c model="nvidia/nemotron-3-ultra-550b-a55b" ...
```
This ensures Codex routes to NVIDIA NIM even if you have an active ChatGPT login in `~/.codex/auth.json`.

If you prefer to configure Codex CLI globally via your configuration file:

1. Add the following to `~/.codex/config.toml` (Mac/Linux) or `%USERPROFILE%\.codex\config.toml` (Windows):

```toml
model = "nvidia/nemotron-3-ultra-550b-a55b"
model_provider = "nvidia_nim"

[model_providers.nvidia_nim]
name = "NVIDIA NIM"
base_url = "https://integrate.api.nvidia.com/v1"
env_key = "NVIDIA_API_KEY"
wire_api = "responses"
```

2. Make sure `NVIDIA_API_KEY` is exported in your environment:
```bash
# Mac / Linux
export NVIDIA_API_KEY="nvapi-your-key-here"

# Windows (PowerShell)
$env:NVIDIA_API_KEY="nvapi-your-key-here"
```

3. You can also run Codex using the dedicated NIM profile:
```bash
codex -p nim
```

