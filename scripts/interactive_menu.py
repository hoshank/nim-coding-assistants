#!/usr/bin/env python3
"""
Interactive TUI Dropdown Selector for claude-nim and codex-nim.
Allows users to select Model, Profile, Effort, and Permissions interactively
using arrow keys or number shortcuts before triggering the assistant.
"""

import os
import sys
import json
import shutil
import argparse
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple

# ANSI color and styling codes
BOLD = "\033[1m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RESET = "\033[0m"
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"

def read_single_key() -> str:
    """Read a single key or escape sequence from terminal (cross-platform)."""
    if sys.platform == "win32":
        import msvcrt
        ch = msvcrt.getch()
        if ch in (b"\x00", b"\xe0"):
            code = msvcrt.getch()
            if code == b"H":
                return "UP"
            elif code == b"P":
                return "DOWN"
            elif code == b"K":
                return "LEFT"
            elif code == b"M":
                return "RIGHT"
        elif ch in (b"\r", b"\n"):
            return "ENTER"
        elif ch == b"\x03":
            return "CTRL_C"
        elif ch == b"\x1b":
            return "ESC"
        else:
            try:
                return ch.decode("utf-8", errors="ignore")
            except Exception:
                return ""
    else:
        import tty
        import termios
        import select
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
            if ch == "\x1b":
                # Check for escape sequence with tiny timeout
                r, _, _ = select.select([sys.stdin], [], [], 0.05)
                if r:
                    seq = sys.stdin.read(1)
                    if seq in ("[", "O"):
                        r2, _, _ = select.select([sys.stdin], [], [], 0.05)
                        if r2:
                            code = sys.stdin.read(1)
                            if code == "A":
                                return "UP"
                            elif code == "B":
                                return "DOWN"
                            elif code == "C":
                                return "RIGHT"
                            elif code == "D":
                                return "LEFT"
                return "ESC"
            elif ch in ("\r", "\n"):
                return "ENTER"
            elif ch == "\x03":
                return "CTRL_C"
            elif ch == "\x04":
                return "CTRL_D"
            elif ch in ("k", "K"):
                return "UP"
            elif ch in ("j", "J"):
                return "DOWN"
            elif ch in ("q", "Q"):
                return "QUIT"
            return ch
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

def format_option(idx: int, label: str, desc: str, is_selected: bool, max_cols: int) -> str:
    """Format a menu option strictly fitting within max_cols to prevent terminal line wrapping."""
    prefix = " ❯ " if is_selected else "   "
    num_str = f"{idx + 1}. "
    base_len = len(prefix) + len(num_str) + len(label)
    
    # Calculate remaining columns for description
    avail_desc = max_cols - base_len - 5  # accounts for ' (' and ')' and margin
    if desc and avail_desc > 10:
        if len(desc) > avail_desc:
            desc_str = f" ({desc[:avail_desc - 3]}...)"
        else:
            desc_str = f" ({desc})"
    else:
        desc_str = ""
    
    if is_selected:
        return f"{GREEN}{BOLD}{prefix}{idx + 1}. {label}{RESET}{DIM}{desc_str}{RESET}"
    else:
        return f"{prefix}{DIM}{idx + 1}.{RESET} {label}{DIM}{desc_str}{RESET}"

def interactive_select(title: str, subtitle: str, options: List[Tuple[str, str]], default_index: int = 0) -> int:
    """Run an interactive arrow-key / number dropdown selection without visual drift or line wrap."""
    if not sys.stdin.isatty():
        # Fallback for non-interactive / pipe
        print(f"\n{title}:")
        for i, (label, desc) in enumerate(options):
            print(f"  {i+1}) {label} ({desc})")
        choice = input(f"Select [1-{len(options)}] (default {default_index+1}): ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(options):
            return int(choice) - 1
        return default_index

    current_index = default_index
    num_options = len(options)
    
    def render_all(is_first: bool):
        cols = shutil.get_terminal_size((80, 24)).columns
        
        # Build exact lines
        lines = [
            f"{CYAN}{BOLD}? {title}{RESET}",
            f"  {DIM}{subtitle}{RESET}"
        ]
        for idx, (label, desc) in enumerate(options):
            is_selected = (idx == current_index)
            lines.append(format_option(idx, label, desc, is_selected, cols))
        
        if not is_first:
            # Move cursor up by exact line count and clear to end of screen
            sys.stdout.write(f"\033[{len(lines)}A\r\033[J")
        
        sys.stdout.write("\n".join(lines) + "\n")
        sys.stdout.flush()

    sys.stdout.write(HIDE_CURSOR)
    sys.stdout.flush()
    try:
        render_all(is_first=True)
        while True:
            key = read_single_key()
            if key == "UP":
                current_index = (current_index - 1) % num_options
                render_all(is_first=False)
            elif key == "DOWN":
                current_index = (current_index + 1) % num_options
                render_all(is_first=False)
            elif key == "ENTER":
                break
            elif key in ("CTRL_C", "QUIT"):
                sys.stdout.write(SHOW_CURSOR + "\n")
                sys.stdout.flush()
                print(f"{YELLOW}Selection cancelled.{RESET}")
                sys.exit(130)
            elif key.isdigit():
                digit = int(key)
                if 1 <= digit <= num_options:
                    current_index = digit - 1
                    render_all(is_first=False)
                    break
    finally:
        sys.stdout.write(SHOW_CURSOR)
        sys.stdout.flush()
    
    selected_label, _ = options[current_index]
    print(f"  {GREEN}✔ Selected:{RESET} {BOLD}{selected_label}{RESET}\n")
    return current_index

def load_models_from_config() -> List[Tuple[str, str]]:
    """Load model list with clean, concise descriptions."""
    return [
        ("nvidia/nemotron-3-ultra-550b-a55b", "Nemotron 3 Ultra 550B • Default Flagship"),
        ("nvidia/nemotron-3-super-120b-a12b", "Nemotron 3 Super 120B • Fast Reasoning & Planning"),
        ("deepseek-ai/deepseek-v4-pro-0813", "DeepSeek V4 Pro (0813) • Coding & Refactoring"),
        ("deepseek-ai/deepseek-v4-flash-0731", "DeepSeek V4 Flash (0731) • Low-Latency Completions"),
        ("minimaxai/minimax-m3", "MiniMax M3 • Vision & UI Understanding"),
        ("z-ai/glm-5.2", "GLM 5.2 • General Coding"),
        ("thinkingmachines/inkling", "Inkling • Interleaved Reasoning & Vision"),
        ("moonshotai/kimi-k3", "Kimi K3 • Long-Horizon Reasoning & Coding"),
        ("[ Enter Custom Model ID ]", "Type any custom NVIDIA NIM model"),
    ]

def prompt_custom_input(prompt_text: str, default_val: str = "") -> str:
    """Prompt user for a custom string input."""
    sys.stdout.write(SHOW_CURSOR)
    sys.stdout.flush()
    val = input(f"  {YELLOW}❯ {prompt_text}{RESET} ").strip()
    return val if val else default_val

def main():
    parser = argparse.ArgumentParser(description="Interactive Launcher Menu for NIM Coding Assistants")
    parser.add_argument("--app", choices=["claude", "codex", "aider"], default="claude", help="Target assistant")
    parser.add_argument("--output", type=str, help="Path to write chosen shell environment variables")
    args = parser.parse_args()

    if args.app == "claude":
        app_name = "Claude Code"
    elif args.app == "codex":
        app_name = "Codex CLI"
    else:
        app_name = "Aider Chat"

    # Header banner
    print(f"{CYAN}{BOLD}")
    print("╔══════════════════════════════════════════════════════════════════════╗")
    print(f"║          🚀 NVIDIA NIM Interactive Setup ({app_name:18})   ║")
    print("║     Use ↑/↓ arrows or number keys to choose, Enter to confirm        ║")
    print("╚══════════════════════════════════════════════════════════════════════╝")
    print(f"{RESET}")

    # 1. Model Selection
    model_options = load_models_from_config()
    model_idx = interactive_select(
        title="Step 1: Select NVIDIA NIM Model",
        subtitle="Choose the model powering your coding session (Enter for default):",
        options=model_options,
        default_index=0
    )
    chosen_model = model_options[model_idx][0]
    if chosen_model == "[ Enter Custom Model ID ]":
        chosen_model = prompt_custom_input("Enter NVIDIA NIM Model ID (e.g. meta/llama-3.3-70b-instruct):", "nvidia/nemotron-3-ultra-550b-a55b")
        print(f"  {GREEN}✔ Custom Model Set:{RESET} {BOLD}{chosen_model}{RESET}\n")

    # 2. Profile / Workflow Selection
    chosen_profile = ""
    chosen_aider_mode = "diff"
    if args.app == "claude":
        profile_options = [
            ("default", "Standard shared profile ~/.claude"),
            ("dev", "Dedicated development profile ~/.claude-profiles/dev"),
            ("vanilla", "Clean, plugin-free environment ~/.claude-profiles/vanilla"),
            ("[ Create Custom Profile ]", "Enter your own custom isolated profile name"),
        ]
        profile_idx = interactive_select(
            title="Step 2: Select Profile",
            subtitle="Isolate settings, history, and MCP plugins per workflow:",
            options=profile_options,
            default_index=0
        )
        chosen_profile = profile_options[profile_idx][0]
        if chosen_profile == "[ Create Custom Profile ]":
            chosen_profile = prompt_custom_input("Enter new profile name (e.g. work, project-a):", "custom")
            print(f"  {GREEN}✔ Custom Profile Created:{RESET} {BOLD}{chosen_profile}{RESET}\n")
        elif chosen_profile == "default":
            chosen_profile = ""
    elif args.app == "codex":
        # Codex profiles
        profile_options = [
            ("danger-full-access", "Full sandbox access & auto-approved commands [Recommended]"),
            ("workspace-write", "Sandbox write access confined to current workspace"),
            ("read-only", "Safe inspection & read-only tools"),
            ("[ Custom Profile ]", "Load custom ~/.codex/<name>.config.toml"),
        ]
        profile_idx = interactive_select(
            title="Step 2: Select Codex Profile / Sandbox Mode",
            subtitle="Configure execution sandboxing and approval policies:",
            options=profile_options,
            default_index=0
        )
        chosen_profile = profile_options[profile_idx][0]
        if chosen_profile == "[ Custom Profile ]":
            chosen_profile = prompt_custom_input("Enter custom profile name from ~/.codex/<name>.config.toml:", "nim")
            print(f"  {GREEN}✔ Profile Set:{RESET} {BOLD}{chosen_profile}{RESET}\n")
    else:
        # Aider Workflow Modes
        aider_modes = [
            ("architect", "Architect Mode (Dual-model: Nemotron 3 Ultra plans, Super 120B edits) [Recommended]"),
            ("diff", "Standard Pair Programming (Diff search/replace format)"),
            ("whole", "Whole File Editing (Rewrites full files)"),
        ]
        mode_idx = interactive_select(
            title="Step 2: Select Aider Workflow Mode",
            subtitle="Choose between architect dual-model reasoning or direct diff editing:",
            options=aider_modes,
            default_index=0
        )
        chosen_aider_mode = aider_modes[mode_idx][0]

    # 3. Reasoning Effort
    effort_options = [
        ("medium", "Balanced reasoning latency and depth (Default)"),
        ("high", "Maximum reasoning effort for deep architecture & math"),
        ("low", "Fast low-latency responses for quick completions"),
    ]
    effort_idx = interactive_select(
        title="Step 3: Select Reasoning Effort",
        subtitle="Control the depth of reasoning tokens allocated to the model:",
        options=effort_options,
        default_index=0
    )
    chosen_effort = effort_options[effort_idx][0]

    # 4. Permission / Approval / Git Handling
    skip_permissions = True
    codex_flags = []
    aider_auto_commits = True

    if args.app == "claude":
        perm_options = [
            ("Auto-approve all permissions (--dangerously-skip-permissions)", "Frictionless pair programming without continuous prompts [Recommended]"),
            ("Standard safe mode (--safe)", "Require manual confirmation for file writes and shell execution"),
        ]
        perm_idx = interactive_select(
            title="Step 4: Permission Mode",
            subtitle="Choose whether Claude Code asks before every command/edit:",
            options=perm_options,
            default_index=0
        )
        skip_permissions = (perm_idx == 0)
    elif args.app == "codex":
        # Codex approval & sandbox policies
        perm_options = [
            ("Bypass all approvals & sandbox (--dangerously-bypass-approvals-and-sandbox)", "Skip all confirmation prompts and execute without sandboxing [Recommended]"),
            ("Never ask approval, keep sandbox active (-a never)", "Never prompt for approval, but enforce workspace sandbox confinement"),
            ("Auto-review commands in workspace (--approve-for-me)", "Auto-review tool execution using workspace-write sandbox"),
            ("Standard manual confirmation prompts", "Prompt for human approval before executing any tool or command"),
        ]
        perm_idx = interactive_select(
            title="Step 4: Permission & Approval Mode",
            subtitle="Control how Codex authorizes tool execution and shell actions:",
            options=perm_options,
            default_index=0
        )
        if perm_idx == 0:
            codex_flags = ["--dangerously-bypass-approvals-and-sandbox"]
        elif perm_idx == 1:
            codex_flags = ["-a", "never"]
        elif perm_idx == 2:
            codex_flags = ["--approve-for-me"]
        else:
            codex_flags = []
    else:
        # Aider Git Commit Handling
        git_options = [
            ("Auto-commit edits", "Automatically commit each successful AI edit with descriptive commit message [Recommended]"),
            ("Manual git commits (--no-auto-commits)", "Leave modified files unstaged for manual review"),
        ]
        git_idx = interactive_select(
            title="Step 4: Git Auto-Commit Behavior",
            subtitle="Choose how Aider interacts with your Git repository:",
            options=git_options,
            default_index=0
        )
        aider_auto_commits = (git_idx == 0)

    print(f"{GREEN}{BOLD}✓ Configuration confirmed. Triggering {app_name}...{RESET}\n")

    # Output to environment file if requested
    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(f'MODEL="{chosen_model}"\n')
            f.write(f'PROFILE="{chosen_profile}"\n')
            f.write(f'EFFORT="{chosen_effort}"\n')
            if args.app == "claude":
                f.write(f'SKIP_PERMISSIONS="{"true" if skip_permissions else "false"}"\n')
            elif args.app == "codex":
                flags_str = " ".join(codex_flags)
                f.write(f'CODEX_PERM_FLAGS="{flags_str}"\n')
            else:
                f.write(f'AIDER_MODE="{chosen_aider_mode}"\n')
                f.write(f'AIDER_AUTO_COMMITS="{"true" if aider_auto_commits else "false"}"\n')

if __name__ == "__main__":
    main()
