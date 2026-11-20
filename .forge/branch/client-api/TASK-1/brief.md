## Origin
**Parent:** client-api
**Branch:** TASK-1
**Tasks:** T13

### Delegated tasks

#### T13 — Skill forge : script de déploiement SQL généré automatiquement
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/phases/p4-plan.md`, `README.md`, `README.fr.md`, `CHANGELOG.md` (dans le dépôt forge)
**Description:**
- Déclencheur : la section `## Deployment` du plan gagne ou modifie une étape qui exécute du SQL (migration, script de reconstruction, requête d'exploitation).
- Réaction, sans question : écrire ou réécrire sur place `output/AAAAMMJJ-deployment-script.sql`. C'est un seul fichier par branche, daté de sa création. Une ligne est ajoutée au log.
- Format :
  - en-tête : branche, date, tableau des étapes (numéro, base visée, moment, forme `comment` / `query`, tâches d'origine) ;
  - une section `-- STEP [n] — [base visée] — [moment] · T7, T9` par étape SQL, dans l'ordre de `## Deployment` ;
  - un script versionné dans le dépôt apparaît en commentaire seul (chemin, prérequis, précautions, variantes production et développement), jamais recopié ;
  - une requête autonome (`EXEC`, job, `UPDATE` d'exploitation) apparaît telle quelle, exécutable, suivie de sa requête de contrôle ;
  - une valeur qui dépend de la date est calculée dans la requête, jamais laissée à saisir ;
  - une section contenant un `USE` est placée en dernier ;
  - une étape sans SQL n'apparaît pas dans le script.
- Numéros de tâches : le format d'une étape de `## Deployment` (p4-plan) gagne `· T1, T3` ; la règle de mise à jour silencieuse de p5 exige ces numéros et renvoie vers la nouvelle section « Script de déploiement SQL ».
- Documentation : une ligne dans chaque README ; dans le CHANGELOG, sous `[Unreleased]`, une entrée `### Added` et une entrée `### Changed`.

## Objective

Brief du projet parent (projet client), retiré du dépôt : seule la tâche déléguée T13 ci-dessus concerne forge.
