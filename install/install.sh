#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "► Skill..."
SKILL_DIR="$CLAUDE_DIR/skills/forge"
mkdir -p "$SKILL_DIR"
rm -rf "$SKILL_DIR"
cp -r "$ROOT/skill/" "$SKILL_DIR"

echo "► Hooks..."
mkdir -p "$CLAUDE_DIR/hooks"
cp "$ROOT/hooks/"* "$CLAUDE_DIR/hooks/"
chmod +x "$CLAUDE_DIR/hooks/forge-precompact.sh"

echo "► Settings..."
node -e "
const fs = require('fs'), path = require('path');
const H = process.env.HOME;
const sp = path.join(H, '.claude', 'settings.json');

let s = {};
try { s = JSON.parse(fs.readFileSync(sp, 'utf8')); } catch(e) {}

s.permissions = s.permissions || {};
s.permissions.allow = s.permissions.allow || [];

const rule = 'Read(' + H + '/.claude/skills/forge)';
s.permissions.allow = s.permissions.allow.filter(r => r !== rule).concat(rule);

s.hooks = s.hooks || {};
s.hooks.PreCompact = s.hooks.PreCompact || [];

for (const { cmd, shell } of [
  { cmd: 'bash ~/.claude/hooks/forge-precompact.sh', shell: 'bash' },
  { cmd: 'powershell -File ~/.claude/hooks/forge-precompact.ps1', shell: 'powershell' }
]) {
  s.hooks.PreCompact = s.hooks.PreCompact.filter(g => !g.hooks || !g.hooks.some(h => h.command === cmd));
  s.hooks.PreCompact.push({ hooks: [{ type: 'command', command: cmd, shell }] });
}

fs.writeFileSync(sp, JSON.stringify(s, null, 2));
console.log('Settings OK.');
"

echo "Done."
