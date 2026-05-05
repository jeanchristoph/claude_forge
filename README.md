# Claude_forge

**Claude_forge** is a Claude Code system made of the **forge** skill (invoked via `/forge`) and a `PreCompact` hook. Together, they enforce a structured, branch-by-branch development workflow.

Where Claude Code jumps straight into code as soon as you describe a problem, the forge skill inserts three mandatory steps before a single line is written:

1. **Brief** — clarify the goal, constraints, and scope
2. **Plan** — break down into estimated tasks, wait for explicit validation
3. **Active** — execute with real-time progress tracking

The result: fewer surprises, implementations that stay within the defined scope, and a per-branch history that survives context compaction.

### What Claude_forge brings concretely

- **Zero code without validation** — the absolute rule: silence ≠ agreement. The skill waits for an explicit "ok" before writing anything.
- **Persistent per-branch context** — `brief.md` and `plan.md` are stored in `.claude/branch/<BRANCH>/` and re-read on every `/forge`.
- **main/master guard** — on protected branches, forge asks for either a ticket ID or a branch name before continuing.
- **Compaction survival** — the `PreCompact` hook injects the forge state (branch, goal, task statuses) into the compacted context summary.
- **Cross-platform** — automatic Unix/Windows detection, separate installers.

---

## Installation

**Windows (PowerShell):**
```powershell
powershell -File install/install.ps1
```

**Unix (bash):**
```bash
bash install/install.sh
```

Scripts are idempotent — re-running after an update overwrites cleanly without duplicates.

---

## Usage

```
/forge
```

---

## Repo structure

```
forge/
├── skill/                    → copied to ~/.claude/skills/forge/
│   ├── SKILL.md
│   ├── phases/
│   │   ├── p0-project.md
│   │   ├── bootstrap.md
│   │   ├── plan.md
│   │   └── resume.md
│   └── templates/
│       └── brief-template.md
├── hooks/
│   ├── bash/                 → copied to ~/.claude/hooks/forge/ by install.sh (Unix)
│   │   └── forge-precompact.sh
│   └── ps1/                  → copied to ~/.claude/hooks/forge/ by install.ps1 (Windows)
│       └── forge-precompact.ps1
├── install/
│   ├── install.sh
│   └── install.ps1
└── .gitignore
```

Files generated in each project:

```
.claude/
├── project.md
└── branch/<BRANCH>/
    ├── brief.md
    └── plan.md
```

---

## State behaviour

### State 0 — Project Init
**Condition:** `.claude/project.md` absent

- Empty project (excluding dotfiles/dotfolders) → `project.md` placeholder created, continues.
- Otherwise → explores stack, structure, conventions, writes `project.md` after validation.

### State 1 — Bootstrap
**Condition:** brief absent

Creates `.claude/branch/<BRANCH>/brief.md`, clarifies the goal, continues to plan.

### State 2 — Plan
**Condition:** brief present, plan absent

Generates `plan.md`, waits for validation before any implementation.

### State 3 — Active
**Condition:** brief + plan present

Reads files silently, displays the progress table, waits for instructions.

---

## Branch detection

Via `bash -c "git branch --show-current 2>/dev/null"` — works on both Unix and Windows.  
Error or empty result (no git repo): asks for a code name used as `<BRANCH>`. No answer → STOP.

---

## Safety guard — main / master

On `main` or `master`, offers:
1. Stay on the branch → provide a ticket ID (e.g. `CU-123`)
2. Create a branch → provide a name

---

## Keys added to settings.json

**Unix (`install.sh`):**
```json
{
  "permissions": {
    "allow": [
      "Read(~/.claude/skills/forge/**)",
      "Read(/.claude/**)", "Edit(/.claude/**)", "Write(/.claude/**)",
      "Bash(git branch --show-current*)"
    ]
  },
  "hooks": {
    "PreCompact": [{
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/forge/forge-precompact.sh", "shell": "bash" }]
    }]
  }
}
```

**Windows (`install.ps1`):**
```json
{
  "permissions": {
    "allow": [
      "Read(//c/Users/{USER}/.claude/skills/forge/**)",
      "Read(/.claude/**)", "Edit(/.claude/**)", "Write(/.claude/**)",
      "Bash(git branch --show-current*)"
    ]
  },
  "hooks": {
    "PreCompact": [{
      "hooks": [{ "type": "command", "command": "powershell -File C:\\Users\\{USER}\\.claude\\hooks\\forge\\forge-precompact.ps1", "shell": "powershell" }]
    }]
  }
}
```

---

## PreCompact hook

Injects the forge state into context compaction to preserve branch, goal, and task statuses.

- `install.sh` → deploys `forge-precompact.sh` to `~/.claude/hooks/forge/`, adds only the bash entry to `settings.json`
- `install.ps1` → deploys `forge-precompact.ps1` to `~/.claude/hooks/forge/`, adds only the powershell entry to `settings.json`

Each installer removes all existing forge entries before adding its own — no duplicates even on reinstall.

---

## Plan updates

**Silent** (automatic): check `[x]`, short note, `[!]` if blocked.  
**Substantial** (confirmation required): add/remove task, order, effort, description.

---

## Updating project.md

```
"ranger la forge" / "clean the forge"
```

---

## Plan format

```markdown
# Plan — <BRANCH>
**Goal:** ...
**Date:** ...

## Tasks

### T1 — Title
**Effort:** S
**Files:** `src/...`
**Description:** ...
[ ]

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 | S | [ ] |
| **Total** | **2h** | |
```

**Statuses:** `[ ]` to do · `[x]` done · `[!]` blocked  
**Effort:** XS <30min · S 30min-2h · M 2-4h · L 4-8h · XL >1d → split

---

---

# Claude_forge (français)

**Claude_forge** est un système pour Claude Code composé du skill **forge** (invoqué via `/forge`) et d'un hook `PreCompact`. Ensemble, ils imposent un workflow de développement structuré, branche par branche.

Là où Claude Code part directement dans le code dès qu'on lui décrit un problème, le skill forge intercale trois étapes obligatoires avant la moindre ligne :

1. **Brief** — clarifier l'objectif, les contraintes, le périmètre
2. **Plan** — décomposer en tâches estimées, attendre une validation explicite
3. **Actif** — exécuter avec suivi d'avancement en temps réel

Le résultat : moins de mauvaises surprises, des implémentations qui restent dans le périmètre défini, et un historique par branche qui survit aux compactions de contexte.

### Ce que Claude_forge apporte concrètement

- **Zéro code sans validation** — la règle absolue : silence ≠ accord. Le skill attend un "ok" explicite avant d'écrire quoi que ce soit.
- **Contexte persistant par branche** — `brief.md` et `plan.md` sont stockés dans `.claude/branch/<BRANCH>/` et relus à chaque `/forge`.
- **Garde main/master** — sur les branches protégées, forge demande soit un identifiant de ticket, soit un nom de branche avant de continuer.
- **Survie à la compaction** — le hook `PreCompact` injecte l'état forge (branche, objectif, statut des tâches) dans le résumé de contexte compacté.
- **Cross-platform** — détection automatique Unix/Windows, installeurs séparés.

---

## Installation

**Windows (PowerShell) :**
```powershell
powershell -File install/install.ps1
```

**Unix (bash) :**
```bash
bash install/install.sh
```

Les scripts sont idempotents — relancer après une mise à jour écrase proprement sans doublon.

---

## Usage

```
/forge
```

---

## Structure du repo

```
forge/
├── skill/                    → copié dans ~/.claude/skills/forge/
│   ├── SKILL.md
│   ├── phases/
│   │   ├── p0-project.md
│   │   ├── bootstrap.md
│   │   ├── plan.md
│   │   └── resume.md
│   └── templates/
│       └── brief-template.md
├── hooks/
│   ├── bash/                 → copié dans ~/.claude/hooks/forge/ par install.sh (Unix)
│   │   └── forge-precompact.sh
│   └── ps1/                  → copié dans ~/.claude/hooks/forge/ par install.ps1 (Windows)
│       └── forge-precompact.ps1
├── install/
│   ├── install.sh
│   └── install.ps1
└── .gitignore
```

Fichiers générés dans chaque projet :

```
.claude/
├── project.md
└── branch/<BRANCH>/
    ├── brief.md
    └── plan.md
```

---

## Comportement par état

### État 0 — Project Init
**Condition :** `.claude/project.md` absent

- Projet vide (hors dotfiles/dotfolders) → `project.md` placeholder créé, enchaîne.
- Sinon → explore stack, structure, conventions, écrit `project.md` après validation.

### État 1 — Bootstrap
**Condition :** brief absent

Crée `.claude/branch/<BRANCH>/brief.md`, clarifie l'objectif, enchaîne sur le plan.

### État 2 — Plan
**Condition :** brief présent, plan absent

Génère `plan.md`, attend validation avant toute implémentation.

### État 3 — Actif
**Condition :** brief + plan présents

Lit les fichiers en silence, affiche le tableau d'avancement, attend les instructions.

---

## Détection de branche

Via `bash -c "git branch --show-current 2>/dev/null"` — fonctionne sur Unix et Windows.  
Erreur ou résultat vide (pas de dépôt git) : demande un nom de code utilisé comme `<BRANCH>`. Sans réponse : STOP.

---

## Garde de sécurité — main / master

Sur `main` ou `master`, propose :
1. Rester sur la branche → fournir un identifiant ticket (ex: `CU-123`)
2. Créer une branche → fournir un nom

---

## Clés ajoutées à settings.json

**Unix (`install.sh`) :**
```json
{
  "permissions": {
    "allow": [
      "Read(~/.claude/skills/forge/**)",
      "Read(/.claude/**)", "Edit(/.claude/**)", "Write(/.claude/**)",
      "Bash(git branch --show-current*)"
    ]
  },
  "hooks": {
    "PreCompact": [{
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/forge/forge-precompact.sh", "shell": "bash" }]
    }]
  }
}
```

**Windows (`install.ps1`) :**
```json
{
  "permissions": {
    "allow": [
      "Read(//c/Users/{USER}/.claude/skills/forge/**)",
      "Read(/.claude/**)", "Edit(/.claude/**)", "Write(/.claude/**)",
      "Bash(git branch --show-current*)"
    ]
  },
  "hooks": {
    "PreCompact": [{
      "hooks": [{ "type": "command", "command": "powershell -File C:\\Users\\{USER}\\.claude\\hooks\\forge\\forge-precompact.ps1", "shell": "powershell" }]
    }]
  }
}
```

---

## Hook PreCompact

Injecte l'état forge dans la compaction du contexte pour préserver branche, objectif et statut des tâches.

- `install.sh` → déploie `forge-precompact.sh` dans `~/.claude/hooks/forge/`, ajoute uniquement l'entrée bash dans `settings.json`
- `install.ps1` → déploie `forge-precompact.ps1` dans `~/.claude/hooks/forge/`, ajoute uniquement l'entrée powershell dans `settings.json`

Chaque installeur retire toutes les entrées forge existantes avant d'ajouter la sienne — pas de doublon même en cas de réinstall.

---

## Mise à jour du plan

**Silencieuse** (automatique) : cocher `[x]`, note courte, `[!]` si bloqué.  
**Substantielle** (confirmation requise) : ajout/suppression de tâche, ordre, effort, description.

---

## Mise à jour de project.md

```
"ranger la forge" / "clean the forge"
```

---

## Format du plan

```markdown
# Plan — <BRANCH>
**Objectif :** ...
**Date :** ...

## Tâches

### T1 — Titre
**Effort :** S
**Fichiers :** `src/...`
**Description :** ...
[ ]

## Récapitulatif
| Tâche | Effort | Statut |
|---|---|---|
| T1 | S | [ ] |
| **Total** | **2h** | |
```

**Statuts :** `[ ]` à faire · `[x]` terminé · `[!]` bloqué  
**Effort :** XS <30min · S 30min-2h · M 2-4h · L 4h-1j · XL >1j → découper