# forge

Workflow de développement par branche pour Claude Code.  
Impose un brief validé, génère un plan structuré, suit l'avancement avec des mises à jour minimales.

---

## Installation

Copier le dossier `forge/` dans le répertoire de skills de Claude Code :

```
~/.claude/skills/forge/
```

---

## Usage

```
/forge
```

Ou via les triggers naturels — voir section [Triggers](#triggers).

---

## Comportement par état

### État 0 — Project Init
**Condition :** `.claude/project.md` absent

1. Explore le projet (stack, structure, conventions, fichiers clés)
2. Présente la fiche projet et attend validation
3. Écrit `.claude/project.md` — commun à toutes les branches
4. S'arrête

---

### État 1 — Bootstrap
**Condition :** `project.md` présent, brief absent

1. Crée `.claude/branch/<BRANCH>/brief.md` depuis le template
2. Pré-remplit les sections disponibles depuis le contexte de la conversation
3. Liste ce qui reste à compléter et s'arrête

**Action requise :** compléter `brief.md` puis relancer `/forge`

---

### État 2 — Plan
**Condition :** brief présent, plan absent

1. Lit `project.md` + `brief.md`
2. Confirme objectif et contraintes projet
3. Génère `.claude/branch/<BRANCH>/plan.md`
4. Présente le plan et attend validation avant toute implémentation

---

### État 3 — Actif
**Condition :** brief + plan présents

1. Lit `project.md` + `brief.md` + `plan.md` en silence
2. Affiche le tableau d'avancement
3. Attend les instructions

---

## Garde de sécurité — main / master

Sur `main` ou `master`, Claude propose deux options :

1. **Rester sur la branche** — fournir un identifiant ticket (ex: `CU-123`) utilisé comme référence pour les chemins
2. **Créer une branche** — fournir un nom, Claude crée la branche et continue

---

## Mise à jour du plan

### Silencieuse — automatique
Sans confirmation :
- Cocher une tâche terminée `[x]`
- Ajouter une note courte sur la ligne (`— note max 1 ligne`)
- Marquer un blocage `[!] motif court`

### Substantielle — confirmation humaine requise
Claude annonce et attend un "ok" :
- Ajouter ou supprimer une tâche
- Modifier l'ordre ou les dépendances
- Changer l'effort estimé
- Réécrire une description

---

## Mise à jour de project.md

Déclencher manuellement quand la stack ou la structure a évolué :

```
"range la forge"
"balaie la forge" / "balaye la forge" / "balai la forge"
"nettoie la forge"
```

Claude lit l'existant et ne modifie que ce qui a changé.

---

## Triggers

### Démarrage / reprise
```
"on forge"
"je veux forger"
"on va forger"
"on reprend la forge"
"retour à la forge"
"on reforge"
```

### Interaction directe
```
"on va voir le forgeron"
"demande au forgeron"
"appelle le forgeron"
"réveille le forgeron"
"forgeron, je ..."
"forgeron, j'ai ..."
```

---

## Structure des fichiers

```
forge/
├── SKILL.md
├── phases/
│   ├── p0-project.md     ← exploration projet + génération project.md
│   ├── bootstrap.md      ← init brief
│   ├── plan.md           ← génération plan
│   └── resume.md         ← reprise + règles MAJ plan
└── templates/
    └── brief-template.md
```

Fichiers générés dans le projet :

```
.claude/
├── project.md                  ← stack, structure, conventions (commun)
└── branch/
    └── <BRANCH>/
        ├── brief.md            ← contexte + objectif (à remplir)
        └── plan.md             ← tâches (généré par Claude)
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
| T1 — ... | S | [ ] |
| **Total estimé** | **2h** | |
```

### Statuts de tâche

| Statut | Signification |
|---|---|
| `[ ]` | À faire |
| `[x]` | Terminé |
| `[!]` | Bloqué |

### Échelle d'effort

| Taille | Durée |
|---|---|
| XS | < 30 min |
| S | 30 min – 2h |
| M | 2h – 4h |
| L | 4h – 1 jour |
| XL | > 1 jour → à découper |
