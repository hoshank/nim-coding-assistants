# ⚡ Pi Coding Agent & NVlabs SoL-Pi with NVIDIA NIM

This guide explains how to run **[Pi](https://github.com/earendil-works/pi)** (`@earendil-works/pi-coding-agent`) and its **[NVlabs SoL-Pi](https://github.com/NVlabs/SoL-Pi)** extension with **NVIDIA NIM** models.

---

## 📌 Overview

**Pi** is a terminal-based AI coding assistant.  
**SoL-Pi** (from NVIDIA Labs) is a standalone extension for Pi that packages four efficiency mechanisms discovered through scaled auto-research loops:

1. **Action Fusion**: Combines file edits/writes with follow-up validation commands in a single turn.
2. **ObservationPack**: Replaces repeated large observations with stable compact handles and exact paged recall.
3. **Evidence-Preserving Reducer (EPR)**: Delegates long diagnostic logs to an efficient reducer model (e.g. `nvidia/nemotron-3-super-120b-a12b`), retaining exact quoted evidence while cutting prompt bloat.
4. **Online Context Compact (OCC)**: Performs economic and window-pressure-aware native compaction at plan step boundaries, automatically resuming the task in a new turn.

---

## ⚡ Quickstart

### Launch with `pi-nim`

Once `nim-coding-assistants` is set up, launch Pi with NVIDIA NIM:

```bash
# Windows
pi-nim

# macOS / Linux
pi-nim
```

To choose a specific NIM model:
```bash
pi-nim -m nvidia/nemotron-3-ultra-550b-a55b
pi-nim -m deepseek-ai/deepseek-v4-pro-0813
```

To interactively choose from the NIM catalog:
```bash
pi-nim --choose
```

---

## ⚙️ Configuration Details

### 1. Pi Authentication (`~/.pi/agent/auth.json`)

Pi natively supports the `nvidia` provider. Authentication is stored in `~/.pi/agent/auth.json`:

```json
{
  "nvidia": {
    "type": "api_key",
    "key": "nvapi-your-key-here"
  }
}
```

Or pass via environment variable:
```bash
export NVIDIA_API_KEY="nvapi-your-key-here"
```

Verify authentication status:
```bash
pi auth check --provider nvidia
```

### 2. SoL-Pi Extension Configuration (`~/.pi/agent/sol-pi.json`)

SoL-Pi reads its settings from `~/.pi/agent/sol-pi.json` (or project-local `.pi/sol-pi.json`). All four mechanisms are configured as follows:

```json
{
  "version": 1,
  "actionFusion": true,
  "observationPack": true,
  "evidencePreservingReducer": true,
  "evidencePreservingReducerProvider": "nvidia",
  "evidencePreservingReducerModel": "nvidia/nemotron-3-super-120b-a12b",
  "onlineContextCompact": true,
  "cacheWriteReadRatio": 12.5
}
```

- **`evidencePreservingReducerProvider`**: Set to `"nvidia"` to route diagnostic log reductions through NVIDIA NIM.
- **`evidencePreservingReducerModel`**: The model ID (e.g. `"nvidia/nemotron-3-super-120b-a12b"` or `"nvidia/nemotron-3-ultra-550b-a55b"`).
- **`cacheWriteReadRatio`**: Default `12.5`. Controls the economic decision threshold for Online Context Compact.

### 3. Agent & Provider Retry Policy (`~/.pi/agent/settings.json`)

By default, Pi retries transient errors (overloaded endpoints, HTTP 429 rate limits, 5xx server issues, stream drops) up to **3** times. You can increase this up to **20** retries in `~/.pi/agent/settings.json`:

```json
{
  "packages": [
    "git:github.com/NVlabs/SoL-Pi"
  ],
  "retry": {
    "enabled": true,
    "maxRetries": 20,
    "baseDelayMs": 2000,
    "provider": {
      "maxRetries": 20,
      "maxRetryDelayMs": 60000
    }
  }
}
```

- **`retry.maxRetries`**: Maximum number of full agent turn auto-retries with exponential backoff (default: `3`, now configured to `20`).
- **`retry.baseDelayMs`**: Initial retry delay in milliseconds before exponential backoff (default: `2000`).
- **`retry.provider.maxRetries`**: Maximum retries at the low-level provider HTTP client layer.
- **`retry.provider.maxRetryDelayMs`**: Upper bound for server-requested `Retry-After` delay (default: `60000` ms).

### 4. Automated Configuration Script

You can run the dedicated setup script anytime to automatically configure all of the above:

- **Windows**:
  ```powershell
  .\scripts\windows\setup-sol-pi.bat
  ```
- **macOS / Linux**:
  ```bash
  ./scripts/mac-linux/setup-sol-pi.sh
  ```

---

## 🤖 Recommended NVIDIA NIM Models for Pi

| Model ID | Context Window | Best For |
|---|:---:|---|
| **`nvidia/nemotron-3-super-120b-a12b`** | 262K / 1M | **Recommended Default** — Fast reasoning, EPR reducer, plan updates |
| **`nvidia/nemotron-3-ultra-550b-a55b`** | 1,048,576 | Flagship heavy reasoning, multi-file architectural refactoring |
| **`deepseek-ai/deepseek-v4-pro-0813`** | 1,048,500 | Code generation & deep surgical debugging |
| **`deepseek-ai/deepseek-v4-flash-0731`** | 1,048,576 | High-speed, low-latency completions |
| **`minimaxai/minimax-m3`** | 1,048,576 | Multimodal UI and diagram interpretation |
| **`moonshotai/kimi-k3`** | 1,048,576 | Long-horizon agentic coding |

---

## 🔍 Preflight Verification

To verify that the SoL-Pi extension configuration satisfies all requirements:

```bash
node <path-to-sol-pi>/scripts/check-sol-pi-config.mjs --config ~/.pi/agent/sol-pi.json --require-all-enabled
```

Expected output:
```json
{
  "ok": true,
  "all_enabled": true,
  "effective_config": {
    "version": 1,
    "actionFusion": true,
    "observationPack": true,
    "evidencePreservingReducer": true,
    "onlineContextCompact": true,
    "cacheWriteReadRatio": 12.5,
    "evidencePreservingReducerModel": "nvidia/nemotron-3-super-120b-a12b",
    "evidencePreservingReducerProvider": "nvidia"
  }
}
```
