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

# Version installée et dépôt d'origine, lus par skills/forge/scripts/update.sh.
# Installation hors git → version et dépôt nuls : la mise à jour sera proposée au premier contrôle.
echo "► Install record..."
node -e "
const [file, version, repository] = process.argv.slice(1);
const record = {
  version: version || null,
  repository: repository || null,
  last_check: version ? Math.floor(Date.now() / 1000) : 0,
  latest: version || null
};
require('fs').writeFileSync(file, JSON.stringify(record) + '\n');
" "$CLAUDE_DIR/skills/forge/install.json" \
  "$(git -C "$ROOT" describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null)" \
  "$(git -C "$ROOT" remote get-url origin 2>/dev/null)"

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
// BOM retiré : les anciennes versions de install.ps1 en écrivaient un, que JSON.parse refuse.
try { s = JSON.parse(fs.readFileSync(sp, 'utf8').replace(/^﻿/, '')); } catch(e) {}

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
