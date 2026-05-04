#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "► Skill..."
SKILL_DIR="$CLAUDE_DIR/skills/forge"
mkdir -p "$SKILL_DIR"
rm -rf "$SKILL_DIR"
cp -r "$ROOT/skill/" "$SKILL_DIR"

echo "► Hook..."
HOOK_DIR="$CLAUDE_DIR/hooks/forge"
mkdir -p "$HOOK_DIR"
cp "$ROOT/hooks/bash/forge-precompact.sh" "$HOOK_DIR/"
chmod +x "$HOOK_DIR/forge-precompact.sh"

echo "► Settings..."
node -e "
const fs = require('fs'), path = require('path');
const H = process.env.HOME;
const sp = path.join(H, '.claude', 'settings.json');

let s = {};
try { s = JSON.parse(fs.readFileSync(sp, 'utf8')); } catch(e) {}

s.permissions = s.permissions || {};
s.permissions.allow = s.permissions.allow || [];

const rule    = 'Read(' + H + '/.claude/skills/forge/**)';
const oldRule = 'Read(' + H + '/.claude/skills/forge)';
s.permissions.allow = s.permissions.allow.filter(r => r !== rule && r !== oldRule).concat(rule);

s.hooks = s.hooks || {};
s.hooks.PreCompact = s.hooks.PreCompact || [];

// Retire toutes les entrées forge (bash + ps1), ajoute uniquement bash
s.hooks.PreCompact = s.hooks.PreCompact.filter(g =>
  !g.hooks || !g.hooks.some(h => h.command && h.command.includes('forge-precompact'))
);

const cmd = 'bash ~/.claude/hooks/forge/forge-precompact.sh';
s.hooks.PreCompact.push({ hooks: [{ type: 'command', command: cmd, shell: 'bash' }] });

fs.writeFileSync(sp, JSON.stringify(s, null, 2));
console.log('Settings OK.');
"

echo "Done."
