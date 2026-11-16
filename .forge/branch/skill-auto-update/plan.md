# Plan — skill-auto-update
**Objective:** Détecter chaque jour, sans ralentir `/forge`, un tag `vX.Y.Z` publié plus récent que la version installée, le proposer et l'installer sur accord, avec un déclencheur manuel « mettre à jour la forge ».
**Date:** 2026-11-09

## Tasks

### T1 — `update.sh check` : contrôle de version
**Effort:** M
**Files:** `skills/forge/scripts/update.sh`, `tests/update.test.sh`
**Description:** Format `install.json` à plat : `{"version":"v0.11.0","repository":"<url>","last_check":<epoch>,"latest":"v0.12.0"}`. Lecture sans sous-processus (`read -d ''`, `[[ =~ ]]`, `printf '%(%s)T'`) ; option `--install-dir` (défaut : dossier parent du script) pour les tests. Contrôle échu (`last_check` > 24 heures, ou fichier absent / illisible) → interrogation détachée en arrière-plan (`</dev/null >/dev/null 2>&1 &`), sans attente. `--force` → même interrogation au premier plan. Interrogation : `git ls-remote --tags` avec `GIT_TERMINAL_PROMPT=0` et délai court, URL `git@host:path` convertie en `https://host/path`, URL par défaut sans `install.json` ; plus grand tag `vX.Y.Z` par comparaison numérique ; réécriture simple de `last_check` et `latest`. Sortie JSON une ligne : `installed`, `latest`, `update_available`, `check` (`skipped` / `started` / `done` / `failed`). Version installée inconnue + `latest` connu → `update_available: true`. Tests (bac à sable, dépôt nu local avec tags, `install.json` jetable) : contrôle récent (aucune écriture, aucun git), échu, fichier absent / abîmé, `--force`, réseau en échec, comparaison `v0.9.10` > `v0.9.2`, tags non conformes ignorés.
[x] 20 tests verts ; chemin rapide ~80 ms ; processus détaché vérifié : survit à la fin de l'appel Bash

### T2 — `update.sh run` : application de la mise à jour
**Effort:** S
**Files:** `skills/forge/scripts/update.sh`, `tests/update.test.sh`
**Description:** Nettoyer un dossier temporaire fixe (`${TMPDIR:-/tmp}/forge-update`), `git clone --depth 1 --branch <latest>`, lancer l'installeur de la plateforme (`$OSTYPE` msys/cygwin → `powershell.exe -NoProfile -ExecutionPolicy Bypass -File install/install.ps1`, portée processus ; sinon `bash install/install.sh`), supprimer le dossier temporaire (best-effort). JSON : `from`, `to`, statut, raison d'échec. Tests avec un dépôt distant factice dont `install/install.sh` écrit un témoin : succès, tag introuvable, installeur en échec.
[x] Vérifié sous Windows : Remove-Item du dossier du script en cours réussit, le JSON est rendu

### T3 — Installeurs : écriture de `install.json`
**Effort:** S
**Files:** `install/install.sh`, `install/install.ps1`
**Description:** Après la copie des skills, écrire `~/.claude/skills/forge/install.json` : `version` = `git describe --tags --abbrev=0` du dossier source (absente hors git), `repository` = `git remote get-url origin` brut (conversion https dans `update.sh`, DRY), `last_check` = maintenant, `latest` = `version`. `install.sh` via le `node` déjà utilisé, `install.ps1` via `ConvertTo-Json`. Vérification manuelle sur les deux plateformes.
[x] last_check à 0 hors git (contrôle immédiat) ; JSON sans BOM côté PowerShell ; vérifié dans un HOME jetable

### T4 — Skill : proposition au démarrage et déclencheur manuel
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `skills/forge/commands/update.md`
**Description:** « Détection d'état » étape 1 : `status.sh` et `update.sh check` dans le même appel Bash, hors mode délégué. `update_available` → après la ligne d'état, lire `commands/update.md` : `AskUserQuestion` (`header` : `Update`, `Update now` / `Later`, versions affichées) ; accord → `update.sh run`, compte rendu mis en page, réplique « Relaunch `/forge` to use <version>. », STOP ; `Later` → reprise normale. Nouvelle section SKILL.md « Mise à jour du skill » : déclencheur « mettre à jour la forge » / « update the forge » → `update.sh check --force`, même enchaînement, et signale aussi « aucune nouvelle version » et l'échec réseau. Formulation conforme à `coding-standards.md`.
[x] SKILL.md : appel combiné et section « Mise à jour du skill » ; commands/update.md

### T5 — Documentation
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** Section mise à jour automatique en anglais et en français, même plan ; entrée `## [Unreleased]` du `CHANGELOG.md` ; `project.md` : `update.sh`, `update.test.sh`, `commands/update.md`, `install.json` dans la structure et les points d'entrée.
[x] README EN/FR, CHANGELOG (Added + Changed « grave »), project.md

### T6 — Mémoriser le refus d'une version
**Effort:** S
**Files:** `skills/forge/scripts/update.sh`, `tests/update.test.sh`, `skills/forge/commands/update.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Mode `update.sh dismiss` : écrit `"dismissed":"<latest>"` dans `install.json`. `check` : `latest` égal à `dismissed` → `update_available` faux ; tag plus récent → reproposé. `check --force` ignore `dismissed`. `save_install_file` conserve `dismissed` ; une réinstallation l'efface. `commands/update.md` : `Later` → `update.sh dismiss`. Tests : refus non reproposé, tag plus récent reproposé, `--force` repropose, `dismissed` conservé par l'interrogation en arrière-plan.
[x] Mode dismiss, --force repropose ; 6 tests

### T7 — Tests automatiques des installeurs
**Effort:** M
**Files:** `tests/install.test.sh`, `README.md`, `README.fr.md`, `.forge/project.md`
**Description:** `install.sh` dans un `HOME` jetable : skills et hook copiés, `settings.json` fusionné ; deux installations sans doublon (`permissions.allow`, `PreCompact`) ; `install.json` : version du tag depuis un dépôt git tagué, `null` et `last_check` à `0` hors git. Mêmes cas pour `install.ps1` avec un `USERPROFILE` jetable si `powershell.exe` est présent, sinon ignoré et signalé. `install.sh` testé seulement si `node` est présent.
[x] tests/install.test.sh : 15 tests (sh + ps1), HOME jetable — écrit par un agent délégué, relu et relancé

### T8 — Fin de la sortie de l'installeur en cas d'échec
**Effort:** S
**Files:** `skills/forge/scripts/update.sh`, `tests/update.test.sh`, `skills/forge/commands/update.md`
**Description:** `update.sh run` capture la sortie de `git clone` et de l'installeur (stdout et stderr) ; en cas d'échec, les 5 dernières lignes vont dans un champ JSON `detail` (`null` en cas de succès). `commands/update.md` : sortie `2` → `detail` en bloc de code sous « Update failed ». Tests : `detail` contient la sortie de l'installeur en échec, `null` en cas de succès, tronqué à 5 lignes.
[x] Champ detail (5 dernières lignes, clone ou installeur) ; 2 tests

### T9 — settings.json sans BOM entre installeurs
**Effort:** XS
**Files:** `install/install.sh`, `install/install.ps1`, `tests/install.test.sh`
**Description:** `install.ps1` écrit `settings.json` sans BOM (`[IO.File]::WriteAllText`) ; `install.sh` retire un BOM avant `JSON.parse`, sinon un `settings.json` écrit par une ancienne version de `install.ps1` était remplacé par un objet vide. Tests : écriture sans BOM, réglages étrangers gardés depuis un fichier avec BOM.
[x] Défaut confirmé par le test avant correction (réglages perdus côté install.sh) ; 19 tests verts

### T10 — `.forge/input/` : référence sans déclencheur
**Effort:** XS
**Files:** `skills/forge/SKILL.md`, `CHANGELOG.md`
**Description:** Chemin INPUT conservé dans « Chemins ». Section « Données de référence » réduite à une mention : INPUT contient les données réelles qui servent à construire le projet (exports, dumps SQL, structures de base de données, jeux de données), un sous-dossier par source ; aucun déclencheur, forge y puise quand le brief ou le plan de la branche en a besoin. Aucune proposition de déplacement à l'export. Entrée `Added` du CHANGELOG mise à jour, README inchangés.
[x] Section réduite à une mention, CHANGELOG mis à jour

### T11 — Question au lieu d'un objectif : réponse sans écriture
**Effort:** XS
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p2-brief.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Section SKILL.md « Question au lieu d'un objectif », sur toute branche : objectif reçu (argument, réponse à « What's the goal of this task? » dans la garde ou l'État 2) qui est une question sur le projet et n'appelle aucune action → réponse en lecture seule, aucune écriture, aucune branche, aucun brief, STOP. Renvois depuis « Avec argument » étape 1, la garde étape 2 et `p2-brief.md`, seuls à nommer les endroits. Surveillance de `p5-resume.md` : question en cours de branche → réponse en lecture seule, ni tâche, ni question `Plan`, ni ligne dans LOG. Mode professeur : aucun fichier écrit sur `main` / `master`. README EN/FR (fonctionnalités, mode professeur), CHANGELOG.
[x] Section dédiée et trois renvois, mode professeur, README EN/FR et CHANGELOG

### T12 — `.forge/branch/<BRANCH>/input/` : fichiers apportés à la branche
**Effort:** XS
**Files:** `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Chemin BRANCH_INPUT `.forge/branch/<BRANCH>/input/` dans « Chemins » : fichiers apportés pour la tâche de la branche (exports CSV/XLSX d'une base inaccessible à Claude, données transmises sous forme de fichier), créé par l'utilisateur, suivi en git. Section « Fichiers de référence » : BRANCH_INPUT consulté d'abord, puis INPUT, quand le brief ou le plan en a besoin ; un fichier de BRANCH_INPUT tient lieu de base (colonnes et lignes lues plutôt qu'un accès demandé). Aucun déclencheur, aucune proposition de déplacement. README EN/FR (arborescence), CHANGELOG (Added, Unreleased).
[x] Chemin BRANCH_INPUT, section « Fichiers de référence », README EN/FR, CHANGELOG

### T13 — Livraison : sort des fichiers de `input/` de la branche
**Effort:** S
**Files:** `skills/forge/commands/engrave.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Étape 1 de la Livraison : `git status --porcelain` sur BRANCH_INPUT ; rien → silencieuse. Fichiers nouveaux ou modifiés → question `Input` : `Keep in git` / `Keep anonymized` / `Out of git`. Exclusion par `.git/info/exclude` (`git rm --cached` si déjà suivi, historique signalé). Anonymisation : colonnes sensibles affichées et validées (`Validate` / `Cancel`, Cancel arrête la livraison), `<nom>-anonymized.<ext>` écrit par script, pseudonymes cohérents, originaux exclus. Ligne LOG avant le `git add`, `engrave.sh` inchangé. Mode délégué `SCOPE: branch` → `FORGE_QUESTION`. README EN/FR, CHANGELOG.
[x] Section « Fichiers apportés à la branche » dans engrave.md, étapes renumérotées ; README EN/FR, CHANGELOG — retiré ensuite : input/ de branche exclu par .gitignore

### T14 — Livraison : question `Input` étendue à `.forge/input/`
**Effort:** XS
**Files:** `skills/forge/commands/engrave.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Déclencheur sur `.forge/input/` et `.forge/branch/<BRANCH>/input/`, section renommée « Fichiers apportés » (renvoi de l'étape 1 compris). Une seule question `Input` listant les fichiers des deux dossiers avec leur chemin, choix appliqué à tous. `Out of git` précise qu'un fichier de `.forge/input/` hors de git manque aux autres branches et clones. README EN/FR, CHANGELOG.
[x] Déclencheur sur les deux dossiers, section renommée, README EN/FR, CHANGELOG — retiré ensuite avec l'anonymisation

### T15 — Script de contrôles asynchrone : `/.forge/branch/*/input/` dans le `.gitignore`
**Effort:** S
**Files:** `skills/forge/scripts/checks.sh`, `tests/checks.test.sh`, `skills/forge/scripts/status.sh`, `tests/status.test.sh`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** Nouveau `checks.sh [--root <dir>]` (futurs contrôles de démarrage) : rien hors git, sans `.forge/`, sur main / master ou HEAD détaché, ni si `git check-ignore` confirme déjà l'exclusion ; sinon ligne insérée avant `###< claude/forge ###` ou bloc ajouté (fichier créé), CRLF respecté ; JSON `gitignore` updated / unchanged / skipped pour les tests. « Détection d'état » étape 1 : lancé détaché hors mode délégué, dans le même appel Bash que status.sh, sans attente, sans affichage, sans LOG. Retrait du champ `branch_input_ignored` de status.sh (et ses tests) et de l'étape 5 de SKILL.md. Tests checks.test.sh. README EN/FR, CHANGELOG, project.md.
[x] checks.sh, 12 tests verts (CRLF lu en bash, le grep de Git Bash ignorant les CR) ; status.sh restauré, 30 tests verts

## Risks
- `update.sh run` tourne depuis `~/.claude/skills/forge/scripts/`, que l'installeur supprime et recopie : sûr sous Unix (descripteur ouvert), `Remove-Item` peut refuser un fichier ouvert sous Windows. À vérifier en T2 ; parade : `run` se recopie dans le dossier temporaire et s'y relance avant l'installeur.
- Processus détaché sous Git Bash : peut être tué à la fermeture du shell de l'outil Bash. À vérifier en T1 ; parade : `nohup` ou `start` côté Windows.
- `Later` reposé à chaque lancement tant que la version publiée n'est pas installée (aucune mémoire du refus) — choix KISS, à revoir si gênant.
- Installation hors git (archive zip) : pas de `version` → mise à jour proposée dès le premier contrôle, voulu.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — `update.sh check` : contrôle de version | M | [x] |
| T2 — `update.sh run` : application de la mise à jour | S | [x] |
| T3 — Installeurs : écriture de `install.json` | S | [x] |
| T4 — Skill : proposition au démarrage et déclencheur manuel | S | [x] |
| T5 — Documentation | S | [x] |
| T6 — Mémoriser le refus d'une version | S | [x] |
| T7 — Tests automatiques des installeurs | M | [x] |
| T8 — Fin de la sortie de l'installeur en cas d'échec | S | [x] |
| T9 — settings.json sans BOM entre installeurs | XS | [x] |
| T10 — `.forge/input/` : référence sans déclencheur | XS | [x] |
| T11 — Question au lieu d'un objectif : réponse sans écriture | XS | [x] |
| T12 — `.forge/branch/<BRANCH>/input/` : fichiers apportés à la branche | XS | [x] |
| T13 — Livraison : sort des fichiers de `input/` de la branche | S | [x] |
| T14 — Livraison : question `Input` étendue à `.forge/input/` | XS | [x] |
| T15 — Script de contrôles asynchrone : `/.forge/branch/*/input/` dans le `.gitignore` | S | [x] |
| **Total** | **2 M + 8 S + 5 XS (~1,5 j)** | |
