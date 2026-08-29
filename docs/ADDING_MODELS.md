# ➕ Adding and Updating Models

When NVIDIA publishes new models to the NIM Catalog or when your organization deploys custom NIM containers, updating this repository is quick and straightforward.

---

## 📝 Step 1: Update `config/models.json`

Add the new model entry to [`config/models.json`](../config/models.json):

```json
{
  "id": "new-provider/new-model-name",
  "name": "New Model Display Name",
  "provider": "Provider Name",
  "supports_tools": true,
  "supports_images": false,
  "max_tokens": 1048576,
  "max_output_tokens": 32768,
  "recommended_for": "Fast coding and refactoring"
}
```

The bridge proxy automatically reloads model lists dynamically from `config/models.json`.

---

## 🧩 Step 2: Update Zed Editor (`config/zed_settings.example.json`)

Add the model to the `available_models` list in [`config/zed_settings.example.json`](../config/zed_settings.example.json):

```json
{
  "name": "new-provider/new-model-name",
  "display_name": "New Model Display Name",
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
}
```

Then run `./scripts/mac-linux/setup-zed.sh` (or `.\scripts\windows\setup-zed.ps1` on Windows) to update your Zed configuration.

---

## 🧪 Step 3: Test the New Model

You can test any new model directly with `claude-nim` or `codex-nim`:

```bash
# Test in Claude Code
claude-nim --model new-provider/new-model-name -p "Say 'Model online' in 2 words"

# Test in Codex CLI
codex-nim --model new-provider/new-model-name
```
