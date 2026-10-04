#!/usr/bin/env python3
"""
Merge NVIDIA NIM models into Zed Editor settings.json non-destructively,
preserving user theme, keymap, context servers, etc.
"""

import sys
import json
import re
from pathlib import Path

def main():
    if len(sys.argv) < 3:
        print("Usage: merge_zed_settings.py <target_settings.json> <example_settings.json>")
        sys.exit(1)

    target_path = Path(sys.argv[1])
    example_path = Path(sys.argv[2])

    if not example_path.exists():
        print(f"Example file not found: {example_path}")
        sys.exit(1)

    with open(example_path, "r", encoding="utf-8") as f:
        ex_text = re.sub(r"^\s*//.*$", "", f.read(), flags=re.MULTILINE)
        example = json.loads(ex_text)

    target = {}
    if target_path.exists():
        try:
            with open(target_path, "r", encoding="utf-8") as f:
                target_text = f.read()
            cleaned = re.sub(r"^\s*//.*$", "", target_text, flags=re.MULTILINE)
            target = json.loads(cleaned)
        except Exception as e:
            print(f"Warning: could not parse existing {target_path}: {e}")
            target = {}

    if "language_models" not in target:
        target["language_models"] = {}
    if "openai_compatible" not in target["language_models"]:
        target["language_models"]["openai_compatible"] = {}

    # Update Nvidia models catalog
    target["language_models"]["openai_compatible"]["Nvidia"] = (
        example.get("language_models", {}).get("openai_compatible", {}).get("Nvidia", {})
    )

    # Set default model if agent or default_model is not configured
    if "agent" not in target:
        target["agent"] = example.get("agent", {})
    elif "default_model" not in target["agent"]:
        target["agent"]["default_model"] = example.get("agent", {}).get("default_model", {})

    target_path.parent.mkdir(parents=True, exist_ok=True)
    with open(target_path, "w", encoding="utf-8") as f:
        json.dump(target, f, indent=2)

    print(f"Successfully merged NVIDIA NIM models into {target_path}")

if __name__ == "__main__":
    main()
