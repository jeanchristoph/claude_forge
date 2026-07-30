# Project — Claude_forge

**Généré le :** 2026-07-30

## Stack
- Langage : Markdown (instructions du skill) + PowerShell / Bash (installeurs et hook)
- Framework / CMS : aucun — système de skill pour Claude Code
- Runtime / version : Claude Code CLI (skill invoqué via `/forge`), PowerShell 5.1 / bash côté scripts
- DB : aucune
- Serveur / runtime : aucun — fichiers déployés localement dans `~/.claude/skills/forge/` et `~/.claude/hooks/forge/`

## Structure clés
```
forge/
├── skill/                    → copié vers ~/.claude/skills/forge/
│   ├── SKILL.md              (machine à états : migration → garde main/master → détection d'état)
│   └── phases/
│       ├── p0-project.md     (État 0 — Project Init)
│       ├── p1-coding-standards.md (État 1)
│       ├── p2-brief.md       (État 2)
│       ├── p3-plan.md        (État 3)
│       └── p4-resume.md      (État 4 — actif)
├── hooks/
│   ├── bash/forge-precompact.sh   → copié vers ~/.claude/hooks/forge/ (Unix)
│   └── ps1/forge-precompact.ps1   → copié vers ~/.claude/hooks/forge/ (Windows)
├── install/
│   ├── install.sh             (déploiement Unix, idempotent)
│   └── install.ps1            (déploiement Windows, idempotent)
├── README.md                  (doc bilingue EN puis FR)
└── TODO.txt                   (notes de travail en cours)
```

Fichiers générés dans **chaque projet cible** par le skill (pas dans ce dépôt) :
```
.forge/
├── project.md
├── coding_standards.md
└── branch/<BRANCH>/
    ├── brief.md
    ├── plan.md
    ├── rapport.txt
    └── cours-*.md
```

## Points d'entrée
- `skill/SKILL.md` — point d'entrée lu par Claude Code à chaque invocation `/forge` (state machine)
- `install/install.ps1` / `install/install.sh` — déploient skill + hook vers `~/.claude/` et fusionnent `settings.json`
- `hooks/ps1/forge-precompact.ps1` / `hooks/bash/forge-precompact.sh` — hook `PreCompact`, injecte l'état du plan courant dans le contexte compacté

## Conventions détectées
- Nommage : phases numérotées `pN-<nom>.md`, sections `##`/`###` avec mots-clés stricts (« Condition », « Réaction », « STOP »)
- Architecture : machine à états explicite — chaque phase se termine par un renvoi à la détection d'état ou un `STOP` ; jamais de saut direct entre phases
- Gestion d'erreurs : scripts PowerShell en `$ErrorActionPreference = "Stop"` ; hooks silencieux (`exit 0`) si branche/plan absents
- Idempotence : les installeurs retirent systématiquement les anciennes entrées (règles `permissions.allow`, hooks `PreCompact`) avant d'ajouter les nouvelles — jamais de doublon en settings.json
- Documentation : `README.md` bilingue, section EN complète suivie de la section FR complète (pas d'alternance ligne à ligne)
- Règles non négociables du skill lui-même : pas de code sans confirmation explicite, pas de mention/copyright Claude, message de commit ≤150 caractères

## Fichiers critiques
- `skill/SKILL.md` — toute modification du comportement du skill passe par ce fichier (routage d'état)
- `install/install.ps1` et `install/install.sh` — logique de fusion `settings.json` à préserver lors de tout changement de permissions/hooks (idempotence critique)
- `hooks/ps1/forge-precompact.ps1` — contrat de sortie JSON (`hookSpecificOutput.additionalContext`) attendu par Claude Code pour `PreCompact`

## Outils & accès
- MCPs disponibles : claude-in-chrome, datagrip, phpstorm, webstorm (non utilisés par ce dépôt en l'état)
- Documentation externe : aucune référence externe identifiée dans le dépôt
