#!/bin/bash
# Exit silently if on Windows (Git Bash/MSYS)
case "$OSTYPE" in
  msys*|cygwin*|win32*) exit 0 ;;
esac

branch=$(git branch --show-current 2>/dev/null)
[ -z "$branch" ] && exit 0

plan=".claude/branch/$branch/plan.md"
[ ! -f "$plan" ] && exit 0

node -e "
const fs = require('fs');
const content = fs.readFileSync(process.argv[1], 'utf8');
process.stdout.write(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: 'PreCompact',
    additionalContext: '[FORGE STATE]\n' + content
  }
}));
" "$plan" 2>/dev/null || exit 0