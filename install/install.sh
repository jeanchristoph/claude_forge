#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Un dossier sous skills/ = un skill installé, sous son propre nom.
# Ajouter un skill n'exige aucune modification de ce script.
echo "► Skills..."
SKILL_NAMES=()
for src in "$ROOT"/skills/*/; do
  name="$(basename "$src")"
  SKILL_NAMES+=("$name")
  dest="$CLAUDE_DIR/skills/$name"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -r "$src." "$dest/"
  echo "  $name"
done

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
const names = process.argv.slice(1);

let s = {};
try { s = JSON.parse(fs.readFileSync(sp, 'utf8')); } catch(e) {}

s.permissions = s.permissions || {};
s.permissions.allow = s.permissions.allow || [];

// Une règle par skill, plus les formes de chemin abandonnées et les règles héritées,
// purgées de settings.json à chaque installation.
const skillRules = names.map(n => 'Read(~/.claude/skills/' + n + '/**)');
const oldForms   = names.flatMap(n => [
  'Read(' + H + '/.claude/skills/' + n + '/**)',
  'Read(' + H + '/.claude/skills/' + n + ')'
]);
const legacy = ['Read(/.claude/**)', 'Edit(/.claude/**)', 'Write(/.claude/**)', 'Write(/.forge/**)'];
const stale = [...skillRules, ...oldForms, ...legacy];
const projectRules = ['Read(/.forge/**)', 'Edit(/.forge/**)', 'Bash(bash -c \"git branch --show-current*)'];
s.permissions.allow = s.permissions.allow
  .filter(r => !stale.includes(r) && !projectRules.includes(r))
  .concat(...skillRules, ...projectRules);

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
" "${SKILL_NAMES[@]}"

echo "Done."
