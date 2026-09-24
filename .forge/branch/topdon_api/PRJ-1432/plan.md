# Plan — topdon_api/PRJ-1432
**Objective:** Faire générer et tenir à jour par le skill forge, sans question, un script SQL de déploiement unique par branche (`output/AAAAMMJJ-deployment-script.sql`), construit à partir des étapes SQL de la section `## Deployment` du plan.
**Date:** 2026-09-24
**Origin:** D:\www\topdon\topdon_api · topdon_api/PRJ-1432 · T13

## Tasks

### T1 — Phases p4 et p5 : numéros de tâches dans `## Deployment` et section « Script de déploiement SQL » ← parent T13
**Effort:** S
**Files:** `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`
**Description:**
- `p4-plan.md`, format du plan : la ligne d'étape de `## Deployment` gagne `· [T1, T3]`, les tâches d'origine.
- `p5-resume.md`, « Règles de mise à jour du plan » : la règle silencieuse du script diffusé à part exige les numéros des tâches d'origine et renvoie vers la nouvelle section « Script de déploiement SQL ».
- `p5-resume.md`, nouvelle section `## Script de déploiement SQL`, juste après « Règles de mise à jour du plan » : déclencheur (étape SQL gagnée ou modifiée dans `## Deployment`), réaction sans question (écrire ou réécrire sur place `output/AAAAMMJJ-deployment-script.sql`, un seul fichier par branche daté de sa création, entrée LOG), format (en-tête avec tableau des étapes ; une section `-- STEP [n] — [base visée] — [moment] · T7, T9` par étape SQL ; script versionné en commentaire seul ; requête autonome exécutable suivie de sa requête de contrôle ; valeur datée calculée dans la requête ; section `USE` en dernier ; étape sans SQL absente).
[x] Section ajoutée après « Règles de mise à jour du plan », réécriture complète du script à chaque déclencheur.

### T2 — Documentation : README EN/FR et CHANGELOG ← parent T13
**Effort:** XS
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:**
- `README.md` et `README.fr.md` : une ligne chacun, sous la puce « Deployment steps in the plan » / « Étapes de mise en production dans le plan ».
- `CHANGELOG.md`, sous `[Unreleased]` : une entrée `### Added` (script SQL de déploiement généré automatiquement) et une entrée `### Changed` (étapes de `## Deployment` numérotées par tâche d'origine).
[x] Puce ajoutée dans chaque README, entrées Added/Changed sous [Unreleased].

## Risks
- Aucune migration n'est livrée avec le skill (règle depuis 0.10.0) : un plan existant sans numéros de tâches dans `## Deployment` se met à jour à la main.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Phases p4/p5 : numéros de tâches et section « Script de déploiement SQL » | S | [x] |
| T2 — Documentation README EN/FR et CHANGELOG | XS | [x] |
| **Total** | **S (~1h30)** | |
