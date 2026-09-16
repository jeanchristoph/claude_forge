# Project — Claude_forge

**Generated:** 2026-07-30 · updated 2026-09-16

## Stack
- Langage : Markdown (instructions du skill) + PowerShell / Bash (installeurs et hook)
- Framework / CMS : aucun — système de skill pour Claude Code
- Runtime / version : Claude Code CLI (skill invoqué via `/forge`), PowerShell 5.1 / bash côté scripts
- DB : aucune
- Serveur / runtime : aucun — fichiers déployés localement dans `~/.claude/skills/<skill>/` et `~/.claude/hooks/forge/`

## Key structure
```
forge/
├── skills/                        → chaque dossier copié vers ~/.claude/skills/<nom>/
│   ├── forge/
│   │   ├── SKILL.md               (machine à états : branche → garde main/master → détection d'état ; mode délégué)
│   │   └── phases/
│   │       ├── p0-project.md         (État 0 — Project Init)
│   │       ├── p1-coding-standards.md (État 1)
│   │       ├── p2-brief.md           (État 2 — Brief)
│   │       ├── p3-log.md             (État 3 — Log)
│   │       ├── p4-plan.md            (État 4 — Plan)
│   │       └── p5-resume.md          (État 5 — Actif)
│   └── forge-clickup/
│       └── SKILL.md               (guichet ClickUp : ouvre la tâche, crée la branche, passe la main à forge)
├── hooks/
│   ├── bash/forge-precompact.sh   → copié vers ~/.claude/hooks/forge/ (Unix)
│   └── ps1/forge-precompact.ps1   → copié vers ~/.claude/hooks/forge/ (Windows)
├── install/
│   ├── install.sh             (déploiement Unix, idempotent)
│   └── install.ps1            (déploiement Windows, idempotent)
├── install-unix.sh            (lanceur racine → install/install.sh)
├── install-windows.bat        (lanceur racine → install/install.ps1)
├── CHANGELOG.md               (format Keep a Changelog, une section par version)
├── LICENSE                    (MIT, Jean-Christophe Malaval)
├── docs/
│   ├── demo.sh                (rejoue les sorties du skill pour la démo)
│   ├── demo.tape              (pilote l'enregistrement vhs)
│   ├── demo.gif               (généré — jamais édité à la main)
│   └── README.md              (prérequis de régénération, WSL requis)
├── README.md                  (documentation, anglais)
├── README.fr.md               (même documentation, français)
└── TODO.txt                   (notes de travail en cours)
```

Fichiers générés dans **chaque projet cible** par le skill (pas dans ce dépôt) :
```
.forge/
├── project.md
├── coding-standards.md
├── clickup.json          (écrit par forge-clickup : liste cible, branche de base, code de branche)
└── branch/<BRANCH>/
    ├── brief.md          (## Origin en tête quand la branche est un projet lié : parent, branche, mandat)
    ├── log.md
    ├── plan.md
    ├── report.txt
    └── output/           (tout contenu généré : AAAAMMJJ-<intitulé>.*, dont AAAAMMJJ-explanation-<sujet>.md)
```

## Entry points
- `skills/forge/SKILL.md` — point d'entrée lu par Claude Code à chaque invocation `/forge` (state machine)
- `skills/forge-clickup/SKILL.md` — point d'entrée de `/forge-clickup`, en amont de forge
- `install/install.ps1` / `install/install.sh` — déploient skills + hook vers `~/.claude/` et fusionnent `settings.json`
- `hooks/ps1/forge-precompact.ps1` / `hooks/bash/forge-precompact.sh` — hook `PreCompact`, injecte l'état du plan courant dans le contexte compacté
- `skills/forge/phases/p5-resume.md` — porte les trois commandes de l'état actif : Délégation vers un projet lié, Livraison (`grave` / `engrave`, projets liés compris) et Clôture de tâche

## Detected conventions
- Nommage : phases numérotées `pN-<nom>.md`, sections `##`/`###` avec mots-clés stricts (« Condition », « Réaction », « STOP »)
- Architecture : machine à états explicite — chaque phase se termine par un renvoi à la détection d'état ou un `STOP` ; jamais de saut direct entre phases
- Projet lié / mode délégué : un sous-agent étanche exécute le skill dans un autre dépôt forgé — prompt `FORGE_DELEGATED` (ROOT, BRANCH, LANGUAGE), marqueur `## Origin` dans le brief, questions relayées par `FORGE_QUESTION` / `FORGE_ANSWER`, rapport final `FORGE_DONE` ; le parent n'écrit là-bas que brief et log, et livre en `git -C`
- Questions à choix : toujours dans la langue de l'utilisateur, libellés anglais du skill = références internes ; validation d'un contenu = `Validate` / `Cancel` + texte libre expliqué, jamais d'option « à retravailler »
- Gestion d'erreurs : scripts PowerShell en `$ErrorActionPreference = "Stop"` ; hooks silencieux (`exit 0`) si branche/plan absents
- Idempotence : les installeurs retirent systématiquement les anciennes entrées (règles `permissions.allow`, hooks `PreCompact`) avant d'ajouter les nouvelles — jamais de doublon en settings.json
- Documentation : un fichier par langue — `README.md` (anglais) et `README.fr.md` (français), même plan de section à section. Sélecteur de langue en badges juste sous le titre, langue courante en bleu, l'autre en gris. Toute évolution de l'un est répercutée sur l'autre dans le même commit
- Règles non négociables du skill lui-même : pas de code sans confirmation explicite, pas de mention/copyright Claude, message de commit ≤150 caractères

## Critical files
- `skills/forge/SKILL.md` — toute modification du comportement du skill passe par ce fichier (routage d'état, mode délégué)
- `install/install.ps1` et `install/install.sh` — logique de fusion `settings.json` à préserver lors de tout changement de permissions/hooks (idempotence critique)
- `hooks/ps1/forge-precompact.ps1` — contrat de sortie JSON (`hookSpecificOutput.additionalContext`) attendu par Claude Code pour `PreCompact`

## Tools & access
- MCPs disponibles : claude-in-chrome, datagrip, phpstorm, webstorm (non utilisés par ce dépôt en l'état)
- Documentation externe : aucune référence externe identifiée dans le dépôt
