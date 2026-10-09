#!/usr/bin/env python3
"""
NVIDIA NIM Model Catalog Sync & Updater
Fetches live models from NVIDIA NIM (https://integrate.api.nvidia.com/v1/models),
audits existing configured models for end-of-life (410 Gone) or deprecation,
discovers new coding and reasoning models, and updates project configuration files:
  - config/models.json
  - proxy.py (MODEL_ALIASES for seamless backward compatibility)
  - config/aider.model.metadata.json & config/aider.model.settings.yml
  - config/zed_settings.example.json
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple, Set

# ANSI colors for terminal formatting
CYAN = "\033[0;36m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

ROOT_DIR = Path(__file__).resolve().parent.parent
CONFIG_DIR = ROOT_DIR / "config"
MODELS_JSON_PATH = CONFIG_DIR / "models.json"
PROXY_PY_PATH = ROOT_DIR / "proxy.py"
AIDER_META_PATH = CONFIG_DIR / "aider.model.metadata.json"
AIDER_YML_PATH = CONFIG_DIR / "aider.model.settings.yml"
ZED_SETTINGS_PATH = CONFIG_DIR / "zed_settings.example.json"
PID_FILE = ROOT_DIR / ".proxy.pid"

# Fallback known replacements for deprecated models
KNOWN_DEPRECATIONS: Dict[str, Tuple[str, str]] = {
    "deepseek-ai/deepseek-v4-flash-0731": (
        "deepseek-ai/deepseek-v4.1-flash",
        "DeepSeek V4.1 Flash (0731 reached EOL 2026-09-21)"
    ),
    "deepseek-ai/deepseek-v4-pro-0813": (
        "deepseek-ai/deepseek-v4.1-flash",
        "DeepSeek V4.1 Flash (0813 reached EOL 2026-09-14)"
    ),
    "deepseek-ai/deepseek-v4-pro": (
        "deepseek-ai/deepseek-v4.1-flash",
        "DeepSeek V4.1 Flash"
    ),
    "deepseek-ai/deepseek-v4-flash": (
        "deepseek-ai/deepseek-v4.1-flash",
        "DeepSeek V4.1 Flash"
    ),
    "thinkingmachines/inkling": (
        "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning",
        "Nemotron 3 Nano Omni (inkling reached EOL 2026-08-25)"
    ),
    "minimaxai/minimax-m3": (
        "meta/llama-3.2-11b-vision-instruct",
        "Llama 3.2 11B Vision (minimax-m3 reached EOL 2026-09-09)"
    ),
}

# Curated metadata dictionary for known NIM models
CURATED_MODEL_METADATA: Dict[str, Dict[str, Any]] = {
    "nvidia/nemotron-3-ultra-550b-a55b": {
        "name": "NVIDIA Nemotron 3 Ultra 550B",
        "provider": "NVIDIA",
        "supports_tools": True,
        "max_tokens": 1048576,
        "max_output_tokens": 32768,
        "recommended_for": "Default - Massive scale reasoning, coding, and architecture"
    },
    "nvidia/nemotron-3-super-120b-a12b": {
        "name": "NVIDIA Nemotron 3 Super 120B",
        "provider": "NVIDIA",
        "supports_tools": True,
        "max_tokens": 1048576,
        "max_output_tokens": 32768,
        "recommended_for": "Fast complex reasoning, agentic tool use, planning"
    },
    "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning": {
        "name": "NVIDIA Nemotron 3 Nano Omni 30B",
        "provider": "NVIDIA",
        "supports_tools": True,
        "supports_images": True,
        "max_tokens": 1048576,
        "max_output_tokens": 32768,
        "recommended_for": "Fast interleaved multimodal reasoning & tool use"
    },
    "nvidia/nemotron-4-340b-instruct": {
        "name": "NVIDIA Nemotron 4 340B Instruct",
        "provider": "NVIDIA",
        "supports_tools": True,
        "max_tokens": 131072,
        "max_output_tokens": 4096,
        "recommended_for": "Enterprise code generation and instruction following"
    },
    "deepseek-ai/deepseek-v4.1-flash": {
        "name": "DeepSeek V4.1 Flash",
        "provider": "DeepSeek",
        "supports_tools": True,
        "max_tokens": 1048576,
        "max_output_tokens": 32768,
        "recommended_for": "Ultra low-latency coding completions & fast edits"
    },
    "deepseek-ai/deepseek-coder-6.7b-instruct": {
        "name": "DeepSeek Coder 6.7B Instruct",
        "provider": "DeepSeek",
        "supports_tools": True,
        "max_tokens": 16384,
        "max_output_tokens": 4096,
        "recommended_for": "Lightweight code completion and refactoring"
    },
    "z-ai/glm-5.3-flash": {
        "name": "GLM 5.3 Flash",
        "provider": "Z-AI",
        "supports_tools": True,
        "max_tokens": 1048576,
        "max_output_tokens": 32768,
        "recommended_for": "General coding and reasoning (Low latency)"
    },
    "z-ai/glm-5.3": {
        "name": "GLM 5.3",
        "provider": "Z-AI",
        "supports_tools": True,
        "max_tokens": 1048576,
        "max_output_tokens": 32768,
        "recommended_for": "High-accuracy multi-lingual coding and reasoning"
    },
    "moonshotai/kimi-k3": {
        "name": "Moonshot AI Kimi K3",
        "provider": "Moonshot AI",
        "supports_tools": True,
        "supports_images": True,
        "max_tokens": 1048576,
        "max_output_tokens": 32768,
        "recommended_for": "Long-horizon reasoning, agentic coding, and multimodal intelligence"
    },
    "moonshotai/kimi-k2.6": {
        "name": "Moonshot AI Kimi K2.6",
        "provider": "Moonshot AI",
        "supports_tools": True,
        "max_tokens": 1048576,
        "max_output_tokens": 32768,
        "recommended_for": "Fast long-context agentic reasoning"
    },
    "mistralai/codestral-22b-instruct-v0.1": {
        "name": "Mistral Codestral 22B",
        "provider": "Mistral AI",
        "supports_tools": True,
        "max_tokens": 32768,
        "max_output_tokens": 8192,
        "recommended_for": "Dedicated code generation and fill-in-the-middle"
    },
    "mistralai/mistral-large-2-instruct": {
        "name": "Mistral Large 2",
        "provider": "Mistral AI",
        "supports_tools": True,
        "max_tokens": 128000,
        "max_output_tokens": 16384,
        "recommended_for": "Complex reasoning, multilingual coding, and mathematical logic"
    },
    "meta/llama-3.2-11b-vision-instruct": {
        "name": "Meta Llama 3.2 11B Vision",
        "provider": "Meta",
        "supports_tools": True,
        "supports_images": True,
        "max_tokens": 131072,
        "max_output_tokens": 8192,
        "recommended_for": "Lightweight multimodal vision, UI screenshot analysis & coding"
    },
    "meta/llama-3.2-90b-vision-instruct": {
        "name": "Meta Llama 3.2 90B Vision",
        "provider": "Meta",
        "supports_tools": True,
        "supports_images": True,
        "max_tokens": 131072,
        "max_output_tokens": 8192,
        "recommended_for": "High-fidelity UI comprehension, visual QA & complex diagrams"
    },
    "openai/gpt-oss-20b": {
        "name": "OpenAI GPT-OSS 20B",
        "provider": "OpenAI",
        "supports_tools": True,
        "max_tokens": 131072,
        "max_output_tokens": 16384,
        "recommended_for": "Open architecture code synthesis & step-by-step logic"
    },
}

def load_api_key(cli_key: Optional[str] = None) -> Optional[str]:
    """Retrieve the NVIDIA API key from CLI, env vars, or .env file."""
    if cli_key and cli_key.strip():
        return cli_key.strip()

    if os.environ.get("NVIDIA_API_KEY"):
        return os.environ["NVIDIA_API_KEY"].strip()

    potential_paths = [
        ROOT_DIR / ".env",
        Path.home() / ".claude" / "nim" / ".env",
        Path.home() / ".nim-coding-assistants" / ".env",
    ]
    for p in potential_paths:
        if p.exists():
            try:
                with open(p, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and line.startswith("NVIDIA_API_KEY="):
                            _, val = line.split("=", 1)
                            key = val.strip().strip('"').strip("'")
                            if key and key != "nvapi-your-key-here":
                                return key
            except Exception:
                pass
    return None

def fetch_live_catalog(api_key: str, base_url: str = "https://integrate.api.nvidia.com/v1") -> List[Dict[str, Any]]:
    """Fetch all available models directly from NVIDIA NIM /v1/models."""
    url = f"{base_url.rstrip('/')}/models"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {api_key}",
            "User-Agent": "NIM-Coding-Assistants-Updater/1.0"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("data", [])
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP Error {e.code} fetching models from {url}: {error_body}")
    except Exception as e:
        raise RuntimeError(f"Failed to connect to {url}: {e}")

def test_model_ping(api_key: str, model_id: str, base_url: str = "https://integrate.api.nvidia.com/v1") -> Tuple[bool, str]:
    """Send a lightweight 1-token test prompt to verify that a model responds."""
    url = f"{base_url.rstrip('/')}/chat/completions"
    payload = json.dumps({
        "model": model_id,
        "messages": [{"role": "user", "content": "ping"}],
        "max_tokens": 1
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "User-Agent": "NIM-Coding-Assistants-Updater/1.0"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            if "choices" in data:
                return True, "OK"
            return False, "Unexpected response format"
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        try:
            err_json = json.loads(body)
            detail = err_json.get("detail", err_json.get("error", {}).get("message", body))
            return False, f"HTTP {e.code}: {detail}"
        except Exception:
            return False, f"HTTP {e.code}: {body[:100]}"
    except Exception as e:
        return False, str(e)

def load_current_models_json() -> Dict[str, Any]:
    """Load config/models.json or return default skeleton."""
    if MODELS_JSON_PATH.exists():
        try:
            with open(MODELS_JSON_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"recommended_default": "nvidia/nemotron-3-ultra-550b-a55b", "models": []}

def infer_metadata(model_id: str) -> Dict[str, Any]:
    """Generate default metadata for a newly discovered model."""
    if model_id in CURATED_MODEL_METADATA:
        meta = dict(CURATED_MODEL_METADATA[model_id])
        meta["id"] = model_id
        return meta

    parts = model_id.split("/")
    org = parts[0] if len(parts) > 1 else "NVIDIA"
    name = parts[1] if len(parts) > 1 else parts[0]
    clean_name = name.replace("-", " ").title()

    is_vision = any(x in model_id.lower() for x in ["vision", "vl", "omni", "multimodal"])
    rec = "General coding and reasoning"
    if "code" in model_id.lower():
        rec = "Code generation and refactoring"
    elif "flash" in model_id.lower() or "mini" in model_id.lower():
        rec = "Fast completions and low latency"
    elif "reason" in model_id.lower() or "ultra" in model_id.lower():
        rec = "High-accuracy long-horizon reasoning"

    res = {
        "id": model_id,
        "name": f"{clean_name}",
        "provider": org.capitalize(),
        "supports_tools": True,
        "max_tokens": 131072,
        "max_output_tokens": 8192,
        "recommended_for": rec
    }
    if is_vision:
        res["supports_images"] = True
    return res

def audit_models(current_config: Dict[str, Any], live_models: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Compare currently configured models against the live NIM catalog."""
    live_ids = {m["id"] for m in live_models}
    current_models = current_config.get("models", [])

    active = []
    deprecated = []

    for m in current_models:
        mid = m["id"]
        if mid in live_ids:
            active.append(m)
        else:
            replacement = KNOWN_DEPRECATIONS.get(mid, (None, None))
            deprecated.append({
                "model": m,
                "replacement_id": replacement[0],
                "reason": replacement[1] or "Removed or sunset from NVIDIA NIM catalog"
            })

    # Find recommended coding/reasoning models in live catalog not yet in models.json
    configured_ids = {m["id"] for m in current_models}
    available_new = []
    for mid in sorted(live_ids):
        if mid not in configured_ids:
            # Filter for coding, reasoning, chat, or LLMs (skip pure embedding/parse/guard models)
            skip_patterns = [
                "embed", "guard", "parse", "detector", "safety", "clip", "translate", "reward"
            ]
            if any(p in mid.lower() for p in skip_patterns):
                continue
            available_new.append(infer_metadata(mid))

    return {
        "active": active,
        "deprecated": deprecated,
        "available_new": available_new,
        "total_live_models": len(live_ids),
    }

def print_audit_report(audit_result: Dict[str, Any]):
    """Print a clean, structured diagnostic report of models."""
    print(f"\n{BOLD}{CYAN}══════════════════════════════════════════════════════════════{RESET}")
    print(f"{BOLD}{CYAN}           NVIDIA NIM Catalog Status & Audit Report           {RESET}")
    print(f"{BOLD}{CYAN}══════════════════════════════════════════════════════════════{RESET}\n")

    print(f"Total models live on NVIDIA NIM: {BOLD}{audit_result['total_live_models']}{RESET}\n")

    # 1. Configured Active Models
    print(f"{BOLD}Configured & Active Models ({len(audit_result['active'])}):{RESET}")
    for m in audit_result["active"]:
        print(f"  {GREEN}✔ [ACTIVE]{RESET} {BOLD}{m['id']}{RESET} ({m.get('name', '')})")
        print(f"    └─ {DIM}{m.get('recommended_for', '')}{RESET}")
    print()

    # 2. Deprecated / Sunset Models
    if audit_result["deprecated"]:
        print(f"{BOLD}{RED}Deprecated / Sunset Models Detected ({len(audit_result['deprecated'])}):{RESET}")
        for item in audit_result["deprecated"]:
            m = item["model"]
            print(f"  {RED}✘ [GONE/EOL]{RESET} {BOLD}{m['id']}{RESET}")
            print(f"    └─ {YELLOW}Issue:{RESET} {item['reason']}")
            if item["replacement_id"]:
                print(f"    └─ {GREEN}Suggested Replacement:{RESET} {BOLD}{item['replacement_id']}{RESET}")
        print()
    else:
        print(f"  {GREEN}✔ No deprecated models in config/models.json!{RESET}\n")

    # 3. Notable live models available
    curated_unadded = [m for m in audit_result["available_new"] if m["id"] in CURATED_MODEL_METADATA]
    if curated_unadded:
        print(f"{BOLD}{CYAN}Notable Live Coding & Reasoning Models Available ({len(curated_unadded)}):{RESET}")
        for m in curated_unadded:
            print(f"  {CYAN}+ [AVAILABLE]{RESET} {BOLD}{m['id']}{RESET} ({m.get('name', '')})")
            print(f"    └─ {DIM}{m.get('recommended_for', '')}{RESET}")
        print()

def sync_configurations(
    active_models: List[Dict[str, Any]],
    deprecated_items: List[Dict[str, Any]],
    new_models_to_add: List[Dict[str, Any]],
    restart_proxy: bool = True
):
    """Save updated catalog and update proxy aliases and tool configurations."""
    # 1. Update config/models.json
    final_models = list(active_models)
    for nm in new_models_to_add:
        if not any(m["id"] == nm["id"] for m in final_models):
            final_models.append(nm)

    recommended_default = "nvidia/nemotron-3-ultra-550b-a55b"
    if not any(m["id"] == recommended_default for m in final_models) and final_models:
        recommended_default = final_models[0]["id"]

    new_config = {
        "recommended_default": recommended_default,
        "models": final_models
    }
    with open(MODELS_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(new_config, f, indent=2)
    print(f"  {GREEN}✔ Updated {MODELS_JSON_PATH.relative_to(ROOT_DIR)} with {len(final_models)} models{RESET}")

    # 2. Update MODEL_ALIASES in proxy.py
    if PROXY_PY_PATH.exists():
        try:
            with open(PROXY_PY_PATH, "r", encoding="utf-8") as f:
                content = f.read()

            aliases_map: Dict[str, str] = dict(KNOWN_DEPRECATIONS)
            # Map each deprecated model to its replacement
            for item in deprecated_items:
                mid = item["model"]["id"]
                rep = item["replacement_id"] or recommended_default
                aliases_map[mid] = rep

            # Render updated MODEL_ALIASES code
            alias_lines = ["MODEL_ALIASES: Dict[str, str] = {"]
            alias_lines.append('    # Automatic model redirects for deprecated or sunset NIM models')
            for src, tgt in sorted(aliases_map.items()):
                target_model = tgt[0] if isinstance(tgt, tuple) else tgt
                alias_lines.append(f'    "{src}": "{target_model}",')
            alias_lines.append("}")
            replacement_block = "\n".join(alias_lines)

            # Locate MODEL_ALIASES: Dict[str, str] = { ... } in proxy.py
            import re
            pattern = r"MODEL_ALIASES:\s*Dict\[str,\s*str\]\s*=\s*\{[^\}]*\}"
            if re.search(pattern, content):
                content = re.sub(pattern, replacement_block, content)
                with open(PROXY_PY_PATH, "w", encoding="utf-8") as f:
                    f.write(content)
                print(f"  {GREEN}✔ Updated MODEL_ALIASES in {PROXY_PY_PATH.relative_to(ROOT_DIR)}{RESET}")
        except Exception as e:
            print(f"  {YELLOW}! Warning updating proxy.py: {e}{RESET}")

    # 3. Update Aider metadata and settings
    if AIDER_META_PATH.exists():
        try:
            with open(AIDER_META_PATH, "r", encoding="utf-8") as f:
                aider_meta = json.load(f)

            for m in final_models:
                mid = m["id"]
                for prefix in [f"openai/{mid}", f"nvidia_nim/{mid}"]:
                    if prefix not in aider_meta:
                        aider_meta[prefix] = {
                            "max_tokens": m.get("max_output_tokens", 32768),
                            "max_input_tokens": m.get("max_tokens", 1048576),
                            "max_output_tokens": m.get("max_output_tokens", 32768),
                            "input_cost_per_token": 0.0,
                            "output_cost_per_token": 0.0,
                            "litellm_provider": prefix.split("/")[0],
                            "mode": "chat"
                        }
            with open(AIDER_META_PATH, "w", encoding="utf-8") as f:
                json.dump(aider_meta, f, indent=2)
            print(f"  {GREEN}✔ Updated Aider model metadata in {AIDER_META_PATH.relative_to(ROOT_DIR)}{RESET}")
        except Exception as e:
            print(f"  {YELLOW}! Warning updating Aider metadata: {e}{RESET}")

    # 4. Update Zed Editor configurations (both template and user settings)
    user_zed_paths = [
        Path.home() / ".config" / "zed" / "settings.json",
        Path.home() / "Library" / "Application Support" / "Zed" / "settings.json",
        ZED_SETTINGS_PATH
    ]
    zed_models = []
    for m in final_models:
        zed_models.append({
            "name": m["id"],
            "display_name": m.get("name", m["id"]),
            "max_tokens": m.get("max_tokens", 1048576),
            "max_output_tokens": m.get("max_output_tokens", 32768),
            "max_completion_tokens": min(m.get("max_tokens", 1048576), 200000),
            "capabilities": {
                "tools": m.get("supports_tools", True),
                "images": m.get("supports_images", False),
                "parallel_tool_calls": True,
                "prompt_cache_key": False,
                "chat_completions": True,
                "interleaved_reasoning": "nemotron" in m["id"] or "reason" in m["id"]
            }
        })

    for zp in user_zed_paths:
        if zp.exists():
            try:
                with open(zp, "r", encoding="utf-8") as f:
                    zdata = json.load(f)
                if "language_models" not in zdata:
                    zdata["language_models"] = {}
                if "openai_compatible" not in zdata["language_models"]:
                    zdata["language_models"]["openai_compatible"] = {}
                if "Nvidia" not in zdata["language_models"]["openai_compatible"]:
                    zdata["language_models"]["openai_compatible"]["Nvidia"] = {
                        "api_url": "https://integrate.api.nvidia.com/v1"
                    }
                zdata["language_models"]["openai_compatible"]["Nvidia"]["available_models"] = zed_models
                with open(zp, "w", encoding="utf-8") as f:
                    json.dump(zdata, f, indent=2)
                try:
                    display_path = zp.relative_to(ROOT_DIR)
                except ValueError:
                    display_path = zp
                print(f"  {GREEN}✔ Updated Zed Editor models in {display_path}{RESET}")
            except Exception as e:
                print(f"  {YELLOW}! Warning updating Zed settings at {zp}: {e}{RESET}")

    # 5. Restart running proxy if active
    if restart_proxy and PID_FILE.exists():
        try:
            pid = int(PID_FILE.read_text().strip())
            import time
            import subprocess
            try:
                os.kill(pid, 0)
                is_alive = True
            except OSError:
                is_alive = False

            if is_alive:
                print(f"  {CYAN}▶ Reloading running NIM proxy daemon (PID {pid})...{RESET}")
                try:
                    os.kill(pid, 15)  # SIGTERM
                except Exception:
                    pass

                # Wait up to 3 seconds for old process to terminate
                for _ in range(15):
                    time.sleep(0.2)
                    try:
                        os.kill(pid, 0)
                    except OSError:
                        break
                else:
                    try:
                        os.kill(pid, 9)  # Force kill if still holding port
                        time.sleep(0.3)
                    except Exception:
                        pass

                # Start fresh proxy with venv python
                py_bin = ROOT_DIR / ".venv" / "bin" / "python"
                if not py_bin.exists():
                    py_bin = Path(sys.executable)

                log_file = open(ROOT_DIR / ".proxy.log", "a")
                proc = subprocess.Popen(
                    [str(py_bin), str(PROXY_PY_PATH), "--port", "8000"],
                    stdout=log_file,
                    stderr=subprocess.STDOUT,
                    cwd=str(ROOT_DIR),
                    start_new_session=True
                )
                PID_FILE.write_text(str(proc.pid))

                # Verify readiness
                ready = False
                for _ in range(15):
                    time.sleep(0.2)
                    try:
                        req = urllib.request.Request("http://127.0.0.1:8000/health")
                        with urllib.request.urlopen(req, timeout=1) as resp:
                            if resp.status == 200:
                                ready = True
                                break
                    except Exception:
                        pass

                if ready:
                    print(f"  {GREEN}✔ NIM Proxy successfully reloaded (New PID: {proc.pid}){RESET}")
                else:
                    print(f"  {YELLOW}! NIM Proxy started (PID: {proc.pid}) - check .proxy.log{RESET}")
        except Exception as e:
            print(f"  {YELLOW}! Warning reloading proxy: {e}{RESET}")

def main():
    parser = argparse.ArgumentParser(
        description="NVIDIA NIM Model Catalog Sync & Updater",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  ./scripts/update_models.py                  # Audit current models & check for deprecations
  ./scripts/update_models.py --sync           # Sync config/models.json & proxy aliases
  ./scripts/update_models.py --test <model>   # Test model completion latency
  ./scripts/update_models.py --add <model>    # Add a specific model to config
  ./scripts/update_models.py --list-all       # Show all 80+ models available on NIM
        """
    )
    parser.add_argument("--key", type=str, help="NVIDIA API Key (defaults to .env)")
    parser.add_argument("--sync", action="store_true", help="Automatically remove deprecated models and add curated active models")
    parser.add_argument("--check", action="store_true", help="Perform health audit only (default)")
    parser.add_argument("--test", type=str, metavar="MODEL_ID", help="Test a specific model with a live completion ping")
    parser.add_argument("--add", type=str, metavar="MODEL_ID", help="Add a specific NIM model to config/models.json")
    parser.add_argument("--remove", type=str, metavar="MODEL_ID", help="Remove a model from config/models.json")
    parser.add_argument("--list-all", action="store_true", help="List all models currently returned by NVIDIA NIM")
    parser.add_argument("--json", action="store_true", help="Output audit results in JSON format")

    args = parser.parse_args()

    api_key = load_api_key(args.key)
    if not api_key:
        print(f"{RED}Error: NVIDIA_API_KEY is required.{RESET}")
        print("Please set NVIDIA_API_KEY in .env or pass --key nvapi-...")
        sys.exit(1)

    try:
        live_models = fetch_live_catalog(api_key)
    except Exception as e:
        print(f"{RED}Error connecting to NVIDIA NIM:{RESET} {e}")
        sys.exit(1)

    if args.list_all:
        print(f"\n{BOLD}{CYAN}=== All {len(live_models)} Models Available on NVIDIA NIM ==={RESET}\n")
        for m in sorted(live_models, key=lambda x: x["id"]):
            print(f"  • {BOLD}{m['id']}{RESET} (owned by {m.get('owned_by', 'NVIDIA')})")
        return

    if args.test:
        model_to_test = args.test.strip()
        print(f"{CYAN}Testing model '{model_to_test}' via NVIDIA NIM...{RESET}")
        ok, msg = test_model_ping(api_key, model_to_test)
        if ok:
            print(f"{GREEN}✔ Success:{RESET} Model '{model_to_test}' is responsive and operational!")
        else:
            print(f"{RED}✘ Failed:{RESET} {msg}")
        return

    current_config = load_current_models_json()
    audit_result = audit_models(current_config, live_models)

    if args.json:
        print(json.dumps(audit_result, indent=2))
        return

    if args.add:
        target = args.add.strip()
        live_ids = {m["id"] for m in live_models}
        if target not in live_ids:
            print(f"{YELLOW}Warning:{RESET} Model '{target}' was not found in NVIDIA NIM's active catalog.")
            confirm = input("Add anyway? [y/N]: ").strip().lower()
            if confirm != "y":
                print("Cancelled.")
                return

        new_meta = infer_metadata(target)
        existing = [m for m in current_config.get("models", []) if m["id"] != target]
        existing.append(new_meta)
        current_config["models"] = existing
        with open(MODELS_JSON_PATH, "w", encoding="utf-8") as f:
            json.dump(current_config, f, indent=2)
        print(f"{GREEN}✔ Added '{target}' to config/models.json{RESET}")
        return

    if args.remove:
        target = args.remove.strip()
        existing = [m for m in current_config.get("models", []) if m["id"] != target]
        current_config["models"] = existing
        with open(MODELS_JSON_PATH, "w", encoding="utf-8") as f:
            json.dump(current_config, f, indent=2)
        print(f"{GREEN}✔ Removed '{target}' from config/models.json{RESET}")
        return

    # Print the audit report
    print_audit_report(audit_result)

    if args.sync:
        print(f"{CYAN}▶ Synchronizing configurations...{RESET}")
        # Add curated models that are active
        curated_to_add = [
            m for m in audit_result["available_new"]
            if m["id"] in CURATED_MODEL_METADATA
        ]
        sync_configurations(
            active_models=audit_result["active"],
            deprecated_items=audit_result["deprecated"],
            new_models_to_add=curated_to_add,
            restart_proxy=True
        )
        print(f"\n{BOLD}{GREEN}✔ Sync complete! Models catalog and proxy aliases are up-to-date.{RESET}\n")
    else:
        if audit_result["deprecated"]:
            print(f"{YELLOW}To automatically replace deprecated models with active ones, run:{RESET}")
            print(f"  {BOLD}./scripts/update_models.py --sync{RESET}\n")

if __name__ == "__main__":
    main()
