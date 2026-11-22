#!/bin/bash
# Hook forge — réinjecte l'état de la branche dans le contexte de Claude Code.
#   Déclaré sur PreCompact (avant compaction) et SessionStart (matcher compact|resume, après compaction ou reprise)
#   Entrée : JSON du hook sur stdin — hook_event_name et cwd lus, le reste ignoré
#   Sortie : JSON hookSpecificOutput.additionalContext — objectif du brief, plan, dernières entrées LOG
#   Silencieux (exit 0, rien écrit) hors dépôt git, sans plan ou sans node
# Usage : forge-precompact.sh < hook-input.json

readonly LOG_ENTRIES_KEPT=3

input=$(cat)
event=PreCompact
[[ $input =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"([A-Za-z]+)\" ]] && event=${BASH_REMATCH[1]}
[[ $input =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]] && cd "${BASH_REMATCH[1]//\\\\/\\}" 2>/dev/null

branch=$(git branch --show-current 2>/dev/null)
[ -z "$branch" ] && exit 0

dir=".forge/branch/$branch"
[ -f "$dir/plan.md" ] || exit 0

node -e "
const fs = require('fs');
const [event, dir, kept] = process.argv.slice(1);
const read = f => { try { return fs.readFileSync(dir + '/' + f, 'utf8').replace(/\r\n/g, '\n'); } catch (e) { return ''; } };
const objective = (read('brief.md').match(/## Objective\n([\s\S]*?)(\n## |\$)/) || [, ''])[1].trim();
const log = read('log.md').split('\n').filter(l => l.startsWith('- [')).slice(0, Number(kept));
const parts = ['[FORGE STATE]'];
if (objective) parts.push('## Objective\n' + objective);
parts.push(read('plan.md').trim());
if (log.length) parts.push('## Last log entries\n' + log.join('\n'));
process.stdout.write(JSON.stringify({
  hookSpecificOutput: { hookEventName: event, additionalContext: parts.join('\n\n') }
}));
" "$event" "$dir" "$LOG_ENTRIES_KEPT" 2>/dev/null || exit 0
