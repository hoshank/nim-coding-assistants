# 💻 Codex CLI with NVIDIA NIM Setup Guide

This guide explains how to use **Codex CLI** with **NVIDIA NIM** models.

---

## ⚡ Direct OpenAI-Compatible Connection

Unlike Claude Code, **Codex CLI** natively supports OpenAI-compatible endpoints directly without needing a local translation proxy.

---

## 🖥️ Interactive TUI Workflow

When you type `codex-nim` without flags in an interactive terminal, it presents a 4-step arrow-key dropdown menu:
1. **Step 1: Select Model** — Choose between Nemotron 3 Ultra 550B (default), Super 120B, DeepSeek v4 Pro, DeepSeek v4 Flash, MiniMax M3, GLM-5.2, or Inkling.
2. **Step 2: Select Profile** — Default (`default`), Danger Full Access (`danger-full-access`), Workspace Write (`workspace-write`), or Read-Only (`read-only`).
3. **Step 3: Select Reasoning Effort** — `medium` (default), `high`, or `low`.
4. **Step 4: Permissions & Sandboxing Mode**:
   - `Bypass Approvals & Sandbox (--dangerously-bypass-approvals-and-sandbox)` (Recommended for autonomous sessions)
   - `Never Ask For Approvals (-a never)` (Auto-approve execution)
   - `Auto-Approve with Workspace Review (--approve-for-me)`
   - `Standard Confirmation Prompts`

To bypass the interactive menu and launch immediately with defaults, pass `-y` / `--yes` / `--quick` or supply CLI flags.

---

## 🚀 Quickstart

### macOS & Linux
```bash
# 1. Default launch (interactive dropdown menu; defaults to Nemotron 3 Ultra 550B)
codex-nim

# 2. Quick launch with defaults (skips interactive menu)
codex-nim -y                   # or --yes, --quick

# 3. Interactive model selection only
codex-nim --choose             # or -c

# 4. Model selection
codex-nim --model deepseek-ai/deepseek-v4-pro-0813
codex-nim -m nvidia/nemotron-3-super-120b-a12b

# 5. Profile selection (built-in profiles or ~/.codex/<profile>.config.toml)
codex-nim --profile danger-full-access    # or -p danger-full-access (skips sandbox & approvals)
codex-nim -p workspace-write              # Sandbox writes within workspace only
codex-nim -p read-only                    # Safe read-only inspection

# 6. Combined Profile + Model + Effort
codex-nim -p danger-full-access -m deepseek-ai/deepseek-v4-pro-0813 -e high

# 7. Skip permissions & approvals directly via flags
codex-nim --dangerously-bypass-approvals-and-sandbox
codex-nim -a never
```

### Windows
```powershell
codex-nim
codex-nim -y
codex-nim --choose
codex-nim -m deepseek-ai/deepseek-v4-pro-0813
codex-nim -p danger-full-access
codex-nim --dangerously-bypass-approvals-and-sandbox
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

