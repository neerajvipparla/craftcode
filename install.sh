#!/usr/bin/env bash
set -euo pipefail

SKILLS_DIR="$HOME/.claude/skills"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing craftcode skills → $SKILLS_DIR"
echo ""

mkdir -p "$SKILLS_DIR"

SKILLS=(craftcode craftcode-prod grill-me handoff)

for skill in "${SKILLS[@]}"; do
  src="$REPO_DIR/$skill"
  dst="$SKILLS_DIR/$skill"

  if [ ! -d "$src" ]; then
    echo "  [skip] $skill — folder not found"
    continue
  fi

  if [ -d "$dst" ]; then
    echo "  [update] $skill"
  else
    echo "  [install] $skill"
  fi

  cp -r "$src" "$SKILLS_DIR/"
done

echo ""
echo "Done. Restart Claude Code to pick up the new skills."
