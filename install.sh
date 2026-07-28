#!/usr/bin/env bash
# Install this skill (grubgenie-api-test) into detected agent tool skill directories.
# Usage: ./install.sh [--platform claude|cursor|codex] [--all] [--dry-run] [--uninstall]
set -euo pipefail

SKILL_NAME="grubgenie-api-test"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
UNINSTALL=0
PLATFORM=""
ALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --all) ALL=1; shift ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# real_path <path> → resolved absolute path, or empty if it doesn't exist.
real_path() {
  (cd "$1" 2>/dev/null && pwd) || true
}

# git_common_dir <path> → the shared .git directory across ALL worktrees of that repo, or empty
# if <path> isn't in a git repo. Two different worktree checkouts of the same repo have
# DIFFERENT paths but the SAME common-dir — plain path comparison misses this entirely, and this
# is exactly the situation here: this skill may be developed in one worktree
# (e.g. a feature-branch checkout) while ~/.claude/skills/grubgenie-api-test is a SEPARATE
# worktree checkout of the SAME repo on `main`. Symlinking over that would replace an independent
# git working tree with a link into a different branch's checkout — not a no-op case, a data-loss
# case, and path equality alone would never catch it.
git_common_dir() {
  local dir="$1" rel
  rel="$(cd "$dir" 2>/dev/null && git rev-parse --git-common-dir 2>/dev/null)" || return 0
  [ -n "$rel" ] || return 0
  (cd "$dir" && cd "$rel" 2>/dev/null && pwd) || true
}

install_to() {
  local label="$1" target_dir="$2"
  local dest="$target_dir/$SKILL_NAME"

  if [ "$UNINSTALL" -eq 1 ]; then
    if [ -e "$dest" ]; then
      echo "[$label] would remove $dest"
      [ "$DRY_RUN" -eq 1 ] || rm -rf "$dest"
    else
      echo "[$label] nothing installed at $dest"
    fi
    return 0
  fi

  if [ "$(real_path "$dest")" = "$SKILL_DIR" ]; then
    echo "[$label] $dest already IS this checkout — no-op"
    return 0
  fi

  if [ -e "$dest" ]; then
    local dest_git this_git
    dest_git="$(git_common_dir "$dest")"
    this_git="$(git_common_dir "$SKILL_DIR")"
    if [ -n "$dest_git" ] && [ "$dest_git" = "$this_git" ]; then
      echo "[$label] $dest is a SEPARATE worktree of this same repo (different branch/checkout) — no-op."
      echo "         Symlinking over it would replace an independent git working tree with a link"
      echo "         into this one. Merge your branch into whatever $dest has checked out instead."
      return 0
    fi
  fi

  mkdir -p "$target_dir"
  echo "[$label] install -> $dest"
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  rm -rf "$dest"
  # Symlink, not copy: keeps the install in sync with this checkout without a separate update step.
  ln -s "$SKILL_DIR" "$dest"
}

detected=0

want() {
  [ "$ALL" -eq 1 ] || [ -z "$PLATFORM" ] || [ "$PLATFORM" = "$1" ]
}

if want claude && [ -d "$HOME/.claude/skills" -o -d "$HOME/.claude" ]; then
  install_to "Claude Code" "$HOME/.claude/skills"
  detected=1
fi

if want cursor && [ -d "$PWD/.cursor" ]; then
  install_to "Cursor (project)" "$PWD/.cursor/skills"
  detected=1
fi

if want codex && [ -d "$HOME/.agents" -o -d "$HOME/.codex" ]; then
  install_to "Universal (~/.agents)" "$HOME/.agents/skills"
  detected=1
fi

if [ "$detected" -eq 0 ]; then
  echo "No known agent tool directories detected."
  echo "Install manually:"
  echo "  ln -s '$SKILL_DIR' ~/.claude/skills/$SKILL_NAME   # Claude Code"
  echo "  ln -s '$SKILL_DIR' ~/.agents/skills/$SKILL_NAME   # universal (Codex, Gemini CLI, etc.)"
  exit 1
fi
