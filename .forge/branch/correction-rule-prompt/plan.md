# Plan — correction-rule-prompt
**Objective:** Après une correction de syntaxe, de structure ou de convention demandée par l'utilisateur, proposer une règle à ajouter dans `CLAUDE.md` pour agir ainsi d'emblée la prochaine fois.
**Date:** 2026-11-04

## Tasks

### T1 — Étendre la section de propagation
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`
**Description:**
- Renommer la section en « Correction ou choix d'infrastructure → propagation vers CLAUDE.md ».
- Ajouter le déclencheur : correction de syntaxe, de structure ou de convention de code (nommage, format, organisation) demandée sur un contenu produit par Claude. Un bug fonctionnel ou un changement de besoin ne déclenche rien.
- Réaction sur correction : appliquer d'abord la correction, puis logger, puis rédiger la règle.
- Format de la règle : généralisée, au format « quand [cas] → [conduite] », sans nom de fichier ni de ticket, affichée en entier avant la question.
- Question obligatoire avant toute écriture, `header` : `Rule`, trois options :
  - `Add to global CLAUDE.md` → écrit dans `~/.claude/CLAUDE.md`.
  - `Add to project CLAUDE.md` → écrit dans `CLAUDE.md` à la racine du projet, créé s'il est absent.
  - `Keep it local` → n'écrit rien et ne repropose jamais cette règle.
- Sans réponse : aucune écriture.
- Les décisions d'infrastructure passent par cette même question, puisque la section est partagée.
- Aucune proposition si le cas est propre à une seule occurrence (une coquille isolée) ou si le `CLAUDE.md` global ou celui du projet le couvre déjà.
- Garde en mode délégué : aucune proposition, car le sous-agent n'a pas accès à `AskUserQuestion` et n'écrit jamais hors de ROOT.

[x] Section étendue, garde mode délégué et question `Rule` à trois options.

### T2 — Documenter le comportement
**Effort:** XS
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:**
- Ajouter le comportement dans les deux README, à la même place.
- Ajouter une entrée `Added` sous `[Unreleased]` dans le CHANGELOG.

[x] Section ajoutée aux deux README, entrée `Added` au CHANGELOG.

## Risks
- Proposition trop fréquente : une question après chaque retouche serait lourde. Les filtres d'occurrence unique et de doublon servent à la limiter.
- Pas de test automatique : le mécanisme est du Markdown d'instructions. La vérification se fera par relecture et en usage réel.
- `CLAUDE.md` non modifié : cette branche construit le mécanisme et n'écrit aucune règle dans le fichier.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Étendre la section de propagation | S | [x] |
| T2 — Documenter le comportement | XS | [x] |
| **Total** | **S** | |
