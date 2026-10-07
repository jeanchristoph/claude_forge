# Plan — fix
**Objective:** Écrire en entier dans la réponse tout contenu soumis à `AskUserQuestion`, juste avant la question.
**Date:** 2026-10-06

## Tasks

### T1 — Poser la règle dans la « Règle absolue » de `SKILL.md`
**Effort:** XS
**Files:** `skills/forge/SKILL.md`
**Description:** Ajouter une ligne `⚠️` juste avant la ligne « Validation d'un contenu présenté ». Toute question qui porte sur un contenu (objectif, plan, modification, rapport, ticket, message, tableau récapitulatif, règle proposée) est précédée de ce contenu, écrit en entier dans le texte de la réponse, dans le même tour. Il n'est jamais résumé, jamais réduit à l'intitulé d'une option ou à la question elle-même, et l'annonce « je rédige X » ne remplace pas X. Le mode délégué garde son équivalent : le champ `content`.
[x]

### T2 — Aligner `p5-resume.md:54` sur la règle
**Effort:** XS
**Files:** `skills/forge/phases/p5-resume.md`
**Description:** Remplacer la règle locale (« La modification est décrite en clair avant la question… ») par un renvoi à la règle de `SKILL.md`, et garder la précision sur le mode délégué. Une règle énoncée une seule fois, conformément aux standards.
[x]

### T3 — Entrée CHANGELOG
**Effort:** XS
**Files:** `CHANGELOG.md`
**Description:** Ajouter une puce sous `[Unreleased]` › `### Changed`, en anglais : le contenu soumis à validation est désormais écrit en entier avant la question, et n'est plus seulement annoncé.
[x]

### T4 — `ship` : question annulable 60 s, sans réponse = accord
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `~/.claude/settings.json`
**Description:** `ship` / `livre` affiche le tableau puis pose la question `Ship` (`Run the sequence` / `Cancel`) ; `Run the sequence` ou fermeture sans réponse au délai → la séquence s'exécute ; `Cancel` ou texte libre → STOP. Action refusée par l'outil → arrêt, état affiché, `grave` ou `!` proposé, jamais de nouvelle tentative. Une commande git par appel. Exception unique ajoutée à la « Règle absolue » de `SKILL.md`. `askUserQuestionTimeout: "60s"` dans `~/.claude/settings.json` (effet de bord : toute question se ferme après 60 s, forge s'arrête hors `ship`). README FR/EN, entrée CHANGELOG « Direct shipping » réécrite.
[ ]

## Risks
- Le README ne décrit pas ce détail du fonctionnement, donc je ne le modifie pas.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Règle dans SKILL.md | XS | [x] |
| T2 — Alignement p5-resume.md | XS | [x] |
| T3 — CHANGELOG | XS | [x] |
| T4 — `ship` annulable 60 s | S | [ ] |
| **Total** | **~1h** | |
