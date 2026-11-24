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

# Version installée et dépôt d'origine, lus par skills/forge/scripts/latest-version.sh.
# Installation hors git → version et dépôt nuls : la dernière version sera annoncée au premier /forge.
echo "► Install record..."
node -e "
const [file, version, repository] = process.argv.slice(1);
const record = {
  version: version || null,
  repository: repository || null,
  latest: version || null
};
require('fs').writeFileSync(file, JSON.stringify(record) + '\n');
" "$CLAUDE_DIR/skills/forge/install.json" \
  "$(git -C "$ROOT" describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null)" \
  "$(git -C "$ROOT" remote get-url origin 2>/dev/null)"

# Hooks livrés dans le skill (skills/forge/hooks/), copiés avec lui : l'ancien dossier ~/.claude/hooks/forge/ des
# installations précédentes est retiré — fichiers forge seulement, dossier supprimé s'il reste vide.
echo "► Legacy hook folder..."
LEGACY_HOOK_DIR="$CLAUDE_DIR/hooks/forge"
rm -f "$LEGACY_HOOK_DIR/forge-precompact.sh" "$LEGACY_HOOK_DIR/forge-precompact.ps1"
rmdir "$LEGACY_HOOK_DIR" 2>/dev/null || true

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
const legacy = ['Read(/.claude/**)', 'Edit(/.claude/**)', 'Write(/.claude/**)', 'Write(/.forge/**)',
                'Bash(bash -c \"git branch --show-current*)'];
const stale = [...skillRules, ...oldForms, ...legacy];
// Scripts du skill, sous les deux formes d'appel (chemin cité ou non) que SKILL.md autorise,
// en barres obliques : node rend un HOME Windows en barres inverses sous Git Bash.
const scripts = H.replace(/\\\\/g, '/') + '/.claude/skills/forge/scripts/';
const scriptRules = ['Bash(bash \"' + scripts + '*)', 'Bash(bash ' + scripts + '*)'];
const projectRules = ['Read(/.forge/**)', 'Edit(/.forge/**)', ...scriptRules];
s.permissions.allow = s.permissions.allow
  .filter(r => !stale.includes(r) && !projectRules.includes(r))
  .concat(...skillRules, ...projectRules);

s.hooks = s.hooks || {};

// Hook d'état forge : avant compaction, puis après compaction ou reprise de session.
// Retire toute entrée forge-precompact (bash ou ancienne ps1), puis ajoute l'entrée bash.
const stateHook = { type: 'command', command: 'bash ~/.claude/skills/forge/hooks/forge-precompact.sh', shell: 'bash' };
const stateEvents = { PreCompact: null, SessionStart: 'compact|resume' };
for (const [event, matcher] of Object.entries(stateEvents)) {
  s.hooks[event] = (s.hooks[event] || []).filter(g =>
    !g.hooks || !g.hooks.some(h => h.command && h.command.includes('forge-precompact'))
  );
  s.hooks[event].push(matcher ? { matcher, hooks: [stateHook] } : { hooks: [stateHook] });
}

// Hook de mesure du temps : retire toute entrée time-hook existante, puis l'ajoute à chaque événement écouté.
// Asynchrone : Claude Code ne l'attend pas ; l'heure est prise à son démarrage, l'agrégation trie le journal.
const timeHook = { type: 'command', command: 'bash ~/.claude/skills/forge/hooks/time-hook.sh', shell: 'bash', async: true };
const timeEvents = {
  UserPromptSubmit: null, Stop: null, SubagentStart: null, SubagentStop: null,
  PreToolUse: 'AskUserQuestion', PostToolUse: 'AskUserQuestion|Bash'
};
for (const [event, matcher] of Object.entries(timeEvents)) {
  s.hooks[event] = (s.hooks[event] || []).filter(g =>
    !g.hooks || !g.hooks.some(h => h.command && h.command.includes('time-hook.sh'))
  );
  s.hooks[event].push(matcher ? { matcher, hooks: [timeHook] } : { hooks: [timeHook] });
}

// Hook de coche du plan : retire toute entrée plan-hook existante, puis l'ajoute après chaque écriture de fichier.
// Synchrone : il réécrit plan.md et renvoie au modèle le réel écrit ; hors plan forge, il sort aussitôt.
const planHook = { type: 'command', command: 'bash ~/.claude/skills/forge/hooks/plan-hook.sh', shell: 'bash' };
s.hooks.PostToolUse = (s.hooks.PostToolUse || []).filter(g =>
  !g.hooks || !g.hooks.some(h => h.command && h.command.includes('plan-hook.sh'))
);
s.hooks.PostToolUse.push({ matcher: 'Edit|Write|MultiEdit', hooks: [planHook] });

// Garde d'écriture dans un projet lié : retire toute entrée linked-write-guard existante, puis l'ajoute avant chaque
// écriture de fichier. Synchrone : il refuse l'écriture de la session parente dans un autre projet forgé.
const guardHook = { type: 'command', command: 'bash ~/.claude/skills/forge/hooks/linked-write-guard.sh', shell: 'bash' };
s.hooks.PreToolUse = (s.hooks.PreToolUse || []).filter(g =>
  !g.hooks || !g.hooks.some(h => h.command && h.command.includes('linked-write-guard.sh'))
);
s.hooks.PreToolUse.push({ matcher: 'Edit|Write|MultiEdit|NotebookEdit', hooks: [guardHook] });

// Hook de nouvelle version : retire toute entrée update-notice existante, puis l'ajoute à /forge et /forge-clickup.
// asyncRewake : lancé en arrière-plan, il réveille Claude seulement quand une version plus récente existe.
const noticeHook = { type: 'command', command: 'bash ~/.claude/skills/forge/hooks/update-notice.sh', shell: 'bash', asyncRewake: true, timeout: 30 };
s.hooks.UserPromptExpansion = (s.hooks.UserPromptExpansion || []).filter(g =>
  !g.hooks || !g.hooks.some(h => h.command && h.command.includes('update-notice.sh'))
);
s.hooks.UserPromptExpansion.push({ matcher: 'forge|forge-clickup', hooks: [noticeHook] });

fs.writeFileSync(sp, JSON.stringify(s, null, 2));
console.log('Settings OK.');
" "${SKILL_NAMES[@]}"

echo "Done."
