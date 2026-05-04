# forge

Workflow de développement par branche pour Claude Code.  
Brief validé → plan structuré → suivi d'avancement.

---

## Installation

```
~/.claude/skills/forge/
```

---

## Usage

```
/forge
```

---

## Comportement par état

### État 0 — Project Init
**Condition :** `.claude/project.md` absent

- Si le projet est vide (hors dotfiles/dotfolders) → crée un `project.md` minimal et enchaîne.
- Sinon → explore stack, structure, conventions, écrit `project.md` après validation.

### État 1 — Bootstrap
**Condition :** brief absent

Crée `.claude/branch/<BRANCH>/brief.md`, clarifie l'objectif avec l'humain, enchaîne sur le plan.

### État 2 — Plan
**Condition :** brief présent, plan absent

Lit `project.md` + `brief.md`, génère `plan.md`, attend validation avant toute implémentation.

### État 3 — Actif
**Condition :** brief + plan présents

Lit les fichiers en silence, affiche le tableau d'avancement, attend les instructions.

---

## Détection de branche

Cross-platform : détecte Unix/bash via `uname`, utilise `2>/dev/null` ou `2>$null` selon l'environnement.  
Sans dépôt git : demande un nom de code utilisé comme `<BRANCH>`.

---

## Garde de sécurité — main / master

Sur `main` ou `master`, propose :
1. Rester sur la branche → fournir un identifiant ticket (ex: `CU-123`)
2. Créer une branche → fournir un nom

---

## Mise à jour du plan

**Silencieuse** (automatique) : cocher `[x]`, note courte, `[!]` si bloqué.  
**Substantielle** (confirmation requise) : ajout/suppression de tâche, ordre, effort, description.

---

## Mise à jour de project.md

Déclencher manuellement si la stack ou la structure a évolué :

```
"range/balaie/nettoie la forge"
```

---

## Structure

```
forge/
├── SKILL.md
├── phases/
│   ├── p0-project.md
│   ├── bootstrap.md
│   ├── plan.md
│   └── resume.md
└── templates/
    └── brief-template.md
```

Fichiers générés dans le projet :

```
.claude/
├── project.md
└── branch/<BRANCH>/
    ├── brief.md
    └── plan.md
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
