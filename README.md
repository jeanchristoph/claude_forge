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
- **Persistent per-branch context** — `brief.md` and `plan.md` are stored in `.forge/branch/<BRANCH>/`, tracked in git, and re-read on every `/forge`.
- **Living brief & log** — constraints go silently into the brief's constraints section (never archived); decisions and user choices are logged silently into `log.md`, without interrupting the workflow.
- **Last session summary** — on resume, if `log.md` has entries, a one-line recap of the last 10 is displayed before the progress table.
- **L/XL task decomposition** — large tasks are broken into micro-steps in `plan.md` before implementation starts.
- **Out-of-scope detection** — requests outside the current plan are flagged; user confirms whether to add them or ignore them.
- **main/master guard** — on protected branches, forge asks for either a ticket ID or a branch name before continuing.
- **Shipping shortcuts** — `"grave master"` / `"engrave master"` (or with `"dev"`) commit, push, and merge in one confirmed step.
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
│   └── phases/
│       ├── p0-project.md          (State 0 — Project Init)
│       ├── p1-coding-standards.md (State 1 — Coding Standards Init)
│       ├── p2-brief.md            (State 2 — Brief)
│       ├── p3-log.md              (State 3 — Log)
│       ├── p4-plan.md             (State 4 — Plan)
│       └── p5-resume.md           (State 5 — Active)
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
.forge/                  ← tracked in git, added automatically on first run
├── project.md
├── coding_standards.md  ← coding conventions (structure, naming, principles), completed over time
└── branch/<BRANCH>/
    ├── brief.md         ← Objective + Constraints (never archived)
    ├── log.md           ← Decisions log (living log, last 10 entries read on resume)
    ├── plan.md
    ├── rapport.txt      ← generated on task closure
    └── cours-*.md       ← generated when a technical concept is explained
```

A legacy `.claude/project.md` / `.claude/branch/` is migrated to `.forge/` automatically on first run — the migration also adds the `.gitignore` block that keeps `.forge/` tracked.

---

## State behaviour

### State 0 — Project Init
**Condition:** `.forge/project.md` absent

- Empty project (excluding dotfiles/dotfolders) → `project.md` placeholder created, continues.
- Otherwise → explores stack, structure, conventions, writes `project.md` after validation.
- `coding_standards.md` is written at the same time (only if it doesn't already exist) — see below.

### State 1 — Coding Standards Init
**Condition:** `.forge/coding_standards.md` absent

Writes `coding_standards.md` in the user's language, then continues to brief.

### State 2 — Brief
**Condition:** brief absent

Reads `coding_standards.md`. Creates `.forge/branch/<BRANCH>/brief.md` with an objective section and an empty constraints section, clarifies the goal, continues to plan.

### State 3 — Log
**Condition:** brief present, `log.md` absent

Silently creates `log.md` if there's nothing to migrate, or moves pre-existing dated entries from `brief.md`'s `## Decisions & Constraints` into it (constraints without a date stay in `brief.md`).

### State 4 — Plan
**Condition:** brief present, `log.md` present, plan absent

Reads `coding_standards.md`, generates `plan.md`, waits for validation before any implementation.  
L/XL tasks include a commented decomposition block (`T1.1`, `T1.2`, …) to fill in before starting.

### State 5 — Active
**Condition:** brief + plan present

Reads `coding_standards.md` and files silently. If `log.md` has entries, displays a one-line "**Last session:**" recap of the last 10 first, then the progress table. Waits for instructions.

---

## coding_standards.md

Created alongside `project.md` (State 0), in the user's language: a title (project name) and a short explanation stating that the file holds the coding conventions (structure, naming, principles) to apply while writing code — an ongoing standard, not a one-off audit — meant to be filled in as the project evolves.

It's read at every phase that touches code (Bootstrap, Plan, Active) so conventions stay applied throughout the workflow.

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

**Constraint** (holds for as long as the branch exists) → written silently into the brief's constraints section, never archived:
- Technical constraint discovered mid-task
- User remark durably narrowing the scope

**One-off decision** (settled and closed at a point in time) → written silently into `log.md` (`- [date] [1 line]`):
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

## Shipping — commit, push, merge

```
"grave <branch(es)>" / "engrave <branch(es)>"
```

One or more existing branches, named in the desired order (e.g. `"grave dev"`, `"grave master"`, `"grave dev master"`). Merges chain in that order: `<BRANCH>` → first branch → second branch → ...

**INVARIANT:** git operates only on the current repo — never on another repo open in parallel.

The commit message is generated automatically — no separate confirmation on the message itself. The full add/commit/push/merge sequence still requires explicit confirmation ("ok", "go") before running.

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
- **Contexte persistant par branche** — `brief.md` et `plan.md` sont stockés dans `.forge/branch/<BRANCH>/`, suivis en git, et relus à chaque `/forge`.
- **Brief vivant & log** — les contraintes vont silencieusement dans la section contraintes du brief (jamais archivée) ; les décisions et choix utilisateur sont enregistrés silencieusement dans `log.md`, sans interrompre le flux de travail.
- **Résumé "Last session"** — à la reprise, si `log.md` contient des entrées, un récapitulatif des 10 dernières en une ligne est affiché avant le tableau d'avancement.
- **Décomposition des tâches L/XL** — les grandes tâches sont découpées en micro-étapes dans `plan.md` avant de démarrer l'implémentation.
- **Détection hors périmètre** — les demandes hors plan sont signalées ; l'utilisateur confirme si elles doivent être ajoutées ou ignorées.
- **Garde main/master** — sur les branches protégées, forge demande soit un identifiant de ticket, soit un nom de branche avant de continuer.
- **Raccourcis de livraison** — `"grave master"` / `"engrave master"` (ou avec `"dev"`) commit, push et merge en une étape confirmée.
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
│   └── phases/
│       ├── p0-project.md          (État 0 — Project Init)
│       ├── p1-coding-standards.md (État 1 — Coding Standards Init)
│       ├── p2-brief.md            (État 2 — Brief)
│       ├── p3-log.md              (État 3 — Log)
│       ├── p4-plan.md             (État 4 — Plan)
│       └── p5-resume.md           (État 5 — Actif)
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
.forge/                  ← suivi en git, ajouté automatiquement au premier lancement
├── project.md
├── coding_standards.md  ← conventions de code (structure, nommage, principes), complétées au fil du projet
└── branch/<BRANCH>/
    ├── brief.md         ← Objectif + Contraintes (jamais archivées)
    ├── log.md           ← Journal des décisions (vivant, 10 dernières entrées lues à la reprise)
    ├── plan.md
    ├── rapport.txt      ← généré à la clôture de tâche
    └── cours-*.md       ← généré lors d'une explication de concept
```

Un `.claude/project.md` / `.claude/branch/` legacy est migré automatiquement vers `.forge/` au premier lancement — la migration ajoute aussi le bloc `.gitignore` qui garde `.forge/` suivi en git.

---

## Comportement par état

### État 0 — Project Init
**Condition :** `.forge/project.md` absent

- Projet vide (hors dotfiles/dotfolders) → `project.md` placeholder créé, enchaîne.
- Sinon → explore stack, structure, conventions, écrit `project.md` après validation.
- `coding_standards.md` est écrit au même moment (uniquement s'il n'existe pas déjà) — voir ci-dessous.

### État 1 — Coding Standards Init
**Condition :** `.forge/coding_standards.md` absent

Écrit `coding_standards.md` dans la langue de l'utilisateur, puis enchaîne sur le brief.

### État 2 — Brief
**Condition :** brief absent

Lit `coding_standards.md`. Crée `.forge/branch/<BRANCH>/brief.md` avec une section objectif et une section contraintes vide, clarifie l'objectif, enchaîne sur le plan.

### État 3 — Log
**Condition :** brief présent, `log.md` absent

Crée `log.md` silencieusement s'il n'y a rien à migrer, ou y déplace les entrées datées préexistantes de `## Décisions & Contraintes` dans `brief.md` (les contraintes sans date restent dans `brief.md`).

### État 4 — Plan
**Condition :** brief présent, `log.md` présent, plan absent

Lit `coding_standards.md`, génère `plan.md`, attend validation avant toute implémentation.  
Les tâches L/XL incluent un bloc de décomposition commenté (`T1.1`, `T1.2`, …) à remplir avant de démarrer.

### État 5 — Actif
**Condition :** brief + plan présents

Lit `coding_standards.md` et les fichiers en silence. Si `log.md` contient des entrées, affiche d'abord un récapitulatif "**Last session :**" des 10 dernières en une ligne, puis le tableau d'avancement. Attend les instructions.

---

## coding_standards.md

Créé en même temps que `project.md` (État 0), dans la langue de l'utilisateur : un titre (nom du projet) et une courte explication précisant que le fichier contient les conventions de code (structure, nommage, principes) à appliquer au moment d'écrire du code — une norme continue, pas un audit ponctuel — à compléter au fil du projet.

Il est lu à chaque phase qui touche au code (Bootstrap, Plan, Actif) pour que les conventions restent appliquées tout au long du workflow.

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

## Mise à jour du brief et du log

Le brief est un document vivant. Les changements de scope passent par la **Détection hors périmètre** (voir ci-dessous).

**Contrainte** (valable pour toute la durée de la branche) → écrite silencieusement dans la section contraintes du brief, jamais archivée :
- Contrainte technique découverte en cours de tâche
- Remarque utilisateur précisant durablement le périmètre

**Décision ponctuelle** (choix acté et clos à un instant donné) → écrite silencieusement dans `log.md` (format : `- [date] [1 ligne]`) :
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

## Livraison — commit, push, merge

```
"grave <branche(s)>" / "engrave <branche(s)>"
```

Une ou plusieurs branches existantes, citées dans l'ordre voulu (ex : `"grave dev"`, `"grave master"`, `"grave dev master"`). Les merges s'enchaînent dans cet ordre : `<BRANCH>` → 1ère branche → 2ème branche → ...

**INVARIANT :** git opère uniquement sur le dépôt courant — jamais sur un autre dépôt ouvert en parallèle.

Le message de commit est généré automatiquement — pas de confirmation dédiée sur le message lui-même. La séquence complète add/commit/push/merge reste soumise à confirmation explicite ("ok", "go") avant exécution.

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