# Claude_forge

**Version:** 1.1

**Claude_forge** is a Claude Code system made of the **forge** skill (invoked via `/forge`) and a `PreCompact` hook. Together, they enforce a structured, branch-by-branch development workflow.

Where Claude Code jumps straight into code as soon as you describe a problem, the forge skill inserts three mandatory steps before a single line is written:

1. **Brief** — clarify the goal, constraints, and scope
2. **Plan** — break down into estimated tasks, wait for explicit validation
3. **Active** — execute with real-time progress tracking

The result: fewer surprises, implementations that stay within the defined scope, and a per-branch history that survives context compaction.

### What Claude_forge brings concretely

- **Zero code without validation** — the absolute rule: silence ≠ agreement. The skill waits for an explicit "ok" before writing anything.
- **Persistent per-branch context** — `brief.md` and `plan.md` are stored in `.forge/branch/<BRANCH>/` (gitignored) and re-read on every `/forge`.
- **Living brief** — decisions, constraints, and user choices are logged silently under `## Decisions & Constraints` in the brief, without interrupting the workflow.
- **Last session summary** — on resume, if `## Decisions & Constraints` has entries, a one-line recap is displayed before the progress table.
- **L/XL task decomposition** — large tasks are broken into micro-steps in `plan.md` before implementation starts.
- **Out-of-scope detection** — requests outside the current plan are flagged; user confirms whether to add them or ignore them.
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
.forge/                  ← gitignored, added automatically on first run
├── project.md
└── branch/<BRANCH>/
    ├── brief.md         ← Objective + Decisions & Constraints (living log)
    ├── plan.md
    ├── rapport.txt      ← generated on task closure
    └── cours-*.md       ← generated when a technical concept is explained
```

A legacy `.claude/project.md` / `.claude/branch/` is migrated to `.forge/` automatically on first run.

---

## State behaviour

### State 0 — Project Init
**Condition:** `.forge/project.md` absent

- Empty project (excluding dotfiles/dotfolders) → `project.md` placeholder created, continues.
- Otherwise → explores stack, structure, conventions, writes `project.md` after validation.

### State 1 — Bootstrap
**Condition:** brief absent

Ensures `/.forge` is in the project's `.gitignore`, creates `.forge/branch/<BRANCH>/brief.md` with `## Objective` and `## Decisions & Constraints` sections, clarifies the goal, continues to plan.

### State 2 — Plan
**Condition:** brief present, plan absent

Generates `plan.md`, waits for validation before any implementation.  
L/XL tasks include a commented decomposition block (`T1.1`, `T1.2`, …) to fill in before starting.

### State 3 — Active
**Condition:** brief + plan present

Reads files silently. If `## Decisions & Constraints` has entries, displays a one-line "**Last session:**" recap first, then the progress table. Waits for instructions.

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
      "Read(/.forge/**)", "Edit(/.forge/**)", "Write(/.forge/**)",
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
      "Read(/.forge/**)", "Edit(/.forge/**)", "Write(/.forge/**)",
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

## Brief updates

The brief is a living document. Changes of scope go through **Out-of-scope detection** (see below).

The following are written silently under `## Decisions & Constraints` (`- [date] [1 line]`):
- User remark or constraint narrowing the scope
- Technical constraint discovered mid-task
- Minor implementation choice made without discussion
- User's choice when Claude presented several options (e.g. "Option B chosen — reason")

---

## Out-of-scope detection

After each user input, forge checks whether the request falls inside the current plan or not.

**Detected when the request:**
- Concerns a feature not in the plan
- Introduces a new use case, module, or behaviour
- Changes an implicitly accepted technical or functional constraint

**Reaction:**
1. Flag it: `"This request isn't in the current plan. Want me to add it?"`
2. On confirmation → apply a substantial plan update; if scope changes significantly, offer to update the brief too.
3. On refusal → handle the request without touching the plan.

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

<!-- L or XL task: decompose into micro-steps before starting
[ ] T1.1 — ...
[ ] T1.2 — ...
-->

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

**Version :** 1.1

**Claude_forge** est un système pour Claude Code composé du skill **forge** (invoqué via `/forge`) et d'un hook `PreCompact`. Ensemble, ils imposent un workflow de développement structuré, branche par branche.

Là où Claude Code part directement dans le code dès qu'on lui décrit un problème, le skill forge intercale trois étapes obligatoires avant la moindre ligne :

1. **Brief** — clarifier l'objectif, les contraintes, le périmètre
2. **Plan** — décomposer en tâches estimées, attendre une validation explicite
3. **Actif** — exécuter avec suivi d'avancement en temps réel

Le résultat : moins de mauvaises surprises, des implémentations qui restent dans le périmètre défini, et un historique par branche qui survit aux compactions de contexte.

### Ce que Claude_forge apporte concrètement

- **Zéro code sans validation** — la règle absolue : silence ≠ accord. Le skill attend un "ok" explicite avant d'écrire quoi que ce soit.
- **Contexte persistant par branche** — `brief.md` et `plan.md` sont stockés dans `.forge/branch/<BRANCH>/` (gitignoré) et relus à chaque `/forge`.
- **Brief vivant** — les décisions, contraintes et choix utilisateur sont enregistrés silencieusement sous `## Décisions & Contraintes` dans le brief, sans interrompre le flux de travail.
- **Résumé "Last session"** — à la reprise, si `## Décisions & Contraintes` contient des entrées, un récapitulatif en une ligne est affiché avant le tableau d'avancement.
- **Décomposition des tâches L/XL** — les grandes tâches sont découpées en micro-étapes dans `plan.md` avant de démarrer l'implémentation.
- **Détection hors périmètre** — les demandes hors plan sont signalées ; l'utilisateur confirme si elles doivent être ajoutées ou ignorées.
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
.forge/                  ← gitignoré, ajouté automatiquement au premier lancement
├── project.md
└── branch/<BRANCH>/
    ├── brief.md         ← Objectif + Décisions & Contraintes (journal vivant)
    ├── plan.md
    ├── rapport.txt      ← généré à la clôture de tâche
    └── cours-*.md       ← généré lors d'une explication de concept
```

Un `.claude/project.md` / `.claude/branch/` legacy est migré automatiquement vers `.forge/` au premier lancement.

---

## Comportement par état

### État 0 — Project Init
**Condition :** `.forge/project.md` absent

- Projet vide (hors dotfiles/dotfolders) → `project.md` placeholder créé, enchaîne.
- Sinon → explore stack, structure, conventions, écrit `project.md` après validation.

### État 1 — Bootstrap
**Condition :** brief absent

S'assure que `/.forge` figure dans le `.gitignore` du projet, crée `.forge/branch/<BRANCH>/brief.md` avec les sections `## Objectif` et `## Décisions & Contraintes`, clarifie l'objectif, enchaîne sur le plan.

### État 2 — Plan
**Condition :** brief présent, plan absent

Génère `plan.md`, attend validation avant toute implémentation.  
Les tâches L/XL incluent un bloc de décomposition commenté (`T1.1`, `T1.2`, …) à remplir avant de démarrer.

### État 3 — Actif
**Condition :** brief + plan présents

Lit les fichiers en silence. Si `## Décisions & Contraintes` contient des entrées, affiche d'abord un récapitulatif "**Last session :**" en une ligne, puis le tableau d'avancement. Attend les instructions.

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
      "Read(/.forge/**)", "Edit(/.forge/**)", "Write(/.forge/**)",
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
      "Read(/.forge/**)", "Edit(/.forge/**)", "Write(/.forge/**)",
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

## Mise à jour du brief

Le brief est un document vivant. Les changements de scope passent par la **Détection hors périmètre** (voir ci-dessous).

Les éléments suivants sont écrits silencieusement sous `## Décisions & Contraintes` (format : `- [date] [1 ligne]`) :
- Remarque ou contrainte utilisateur précisant le périmètre
- Contrainte technique découverte en cours de tâche
- Choix d'implémentation mineur acté sans discussion
- Choix utilisateur quand Claude a proposé plusieurs options (ex : "Option B retenue — raison")

---

## Détection hors périmètre

Après chaque input utilisateur, forge vérifie si la demande est dans le plan courant ou non.

**Détecté si la demande :**
- Concerne une fonctionnalité absente du plan
- Introduit un nouveau cas d'usage, module ou comportement
- Modifie une contrainte technique ou fonctionnelle implicitement acceptée

**Réaction :**
1. Signaler : `"This request isn't in the current plan. Want me to add it?"`
2. Sur confirmation → appliquer une mise à jour substantielle du plan ; si le scope change significativement, proposer aussi de mettre à jour le brief.
3. Sur refus → traiter la demande sans toucher au plan.

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

<!-- Tâche L ou XL : décomposer en micro-étapes avant de démarrer
[ ] T1.1 — ...
[ ] T1.2 — ...
-->

## Récapitulatif
| Tâche | Effort | Statut |
|---|---|---|
| T1 | S | [ ] |
| **Total** | **2h** | |
```

**Statuts :** `[ ]` à faire · `[x]` terminé · `[!]` bloqué  
**Effort :** XS <30min · S 30min-2h · M 2-4h · L 4h-1j · XL >1j → découper