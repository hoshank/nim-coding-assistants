# 🧩 Zed Editor with NVIDIA NIM Setup Guide

This guide walks you through configuring **Zed Editor** to use **NVIDIA NIM** (Cloud API or Self-Hosted) as its AI Assistant backend with full tool calling, edit predictions, and multimodal capabilities.

---

## 🚀 1-Minute Automated Setup

### macOS / Linux
Run the setup script from the root of the repository:
```bash
./scripts/mac-linux/setup-zed.sh
```

### Windows (PowerShell)
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\setup-zed.ps1
```

The script automatically creates a timestamped backup of any existing configuration and installs the optimized NVIDIA NIM settings.

---

## 🛠️ Manual Configuration

If you prefer to edit your Zed configuration manually:

1. Locate your Zed `settings.json` file:
   - **macOS / Linux**: `~/.config/zed/settings.json`
   - **Windows**: `%APPDATA%\Zed\settings.json`

2. Copy the JSON configuration from [`config/zed_settings.example.json`](../config/zed_settings.example.json) into your `settings.json`.

---

## 🔑 Setting Your NVIDIA API Key in Zed

Zed securely stores provider API keys in your operating system's keychain (macOS Keychain, Linux Secret Service, or Windows Credential Manager).

1. Open **Zed Editor**.
2. Open the Command Palette:
   - macOS: `Cmd + Shift + P`
   - Windows / Linux: `Ctrl + Shift + P`
3. Type and select: **`zed: set api key`**
4. Select provider: **`Nvidia`**
5. Enter your NVIDIA API key (starts with `nvapi-...`).

---

## ⚙️ Configuration Breakdown

### 1. Provider & Models Definition (`language_models`)

```json
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
        }
      ]
    }
  }
}
```

### 2. Default Model Selection (`agent.default_model`)

```json
"agent": {
  "default_model": {
    "provider": "Nvidia",
    "model": "nvidia/nemotron-3-ultra-550b-a55b"
  }
}
```

### 3. Agent Tool Permissions (`agent.tool_permissions`)

To allow Zed's AI agent to read/edit files and run terminal commands smoothly:

```json
"agent": {
  "tool_permissions": {
    "default": "allow",
    "tools": {
      "terminal": {
        "always_allow": [
          { "pattern": "^ls\\b" }
        ]
      },
      "create_directory": { "default": "allow" },
      "edit_file": { "default": "allow" }
    }
  }
}
```

---

## 🔄 Switching Models in Zed Assistant

You can switch models on the fly inside the Zed Assistant panel:
1. Open the Assistant panel (`Cmd + ?` / `Ctrl + ?` or click the AI icon in the bottom right).
2. Click the model dropdown picker at the top of the Assistant panel.
3. Select any of your configured NVIDIA NIM models (e.g. *NVIDIA Nemotron 3 Ultra 550B*, *DeepSeek V4 Pro*, *MiniMax M3*).
