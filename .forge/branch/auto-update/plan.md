# Plan — auto-update
**Objective:** Au premier `/forge` d'une session, détecter une release plus récente du skill et, si l'utilisateur accepte, l'installer depuis un clone temporaire du tag.
**Date:** 2026-10-27

## Tasks

### T1 — Script `update-check.sh` et ses tests
**Effort:** M
**Files:** `skills/forge/scripts/update-check.sh`, `tests/update-check.test.sh`
**Description:** Script sur le modèle d'`engrave.sh` et de `temp-branch.sh` : constantes `readonly`, sortie en JSON sur une ligne, sans `jq`. Il a deux modes, avec `--install-file <chemin>` (par défaut `<dossier du script>/../install.json`).

**`check`**
- Lire `install.json` (`version`, `repository`). Fichier absent ou illisible → `{"status":"skipped","reason":"not installed"}`.
- `git ls-remote --tags --refs <repository>` avec `GIT_TERMINAL_PROMPT=0` et un délai d'expiration de 10 s. Prendre le plus haut tag `vX.Y.Z` (`sort -V`).
- Dépôt injoignable → `{"status":"unreachable"}`. Tag plus récent → `{"status":"available","installed":"0.10.2","latest":"0.11.0"}`. Sinon → `up_to_date`.
- Aucune écriture.

**`apply --version <x.y.z>`**
- Se recopier d'abord dans un dossier temporaire et s'y relancer (`exec`). L'installeur supprime le dossier du skill d'où le script tourne.
- `git clone --depth 1 --branch v<x.y.z>` dans un dossier temporaire.
- Lancer l'installeur de la plateforme : `powershell -NoProfile -ExecutionPolicy Bypass -File install/install.ps1` sous `MINGW`/`MSYS`/`CYGWIN`, sinon `bash install/install.sh`. `--platform windows|unix` force le choix pour les tests.
- Supprimer le clone et rendre compte : `{"status":"updated","version":"0.11.0"}` ou `{"status":"failed","step":"clone|install","detail":"..."}`, sortie `2`.

**Tests**, sur un dépôt nu local avec ses tags et un `install.json` jetable :
- fichier absent ;
- version égale, supérieure ou inférieure au dernier tag ;
- tags non semver ignorés ;
- tri `v0.10.0` > `v0.9.4` ;
- dépôt injoignable ;
- `check` n'écrit rien ;
- `apply` avec un faux `install/install.sh` qui laisse une trace ;
- échec du clone (tag absent) et échec de l'installeur ;
- dossier temporaire supprimé.

[ ]

### T2 — Les installeurs écrivent `install.json`
**Effort:** S
**Files:** `install/install.ps1`, `install/install.sh`
**Description:**
- Après la copie des skills, écrire `~/.claude/skills/forge/install.json` sur une ligne : `{"version":"0.10.2","repository":"https://github.com/jeanchristoph/claude_forge.git"}`.
- `version` est le premier `## [x.y.z]` de `CHANGELOG.md` (la section `[Unreleased]` est ignorée). L'URL est une constante en tête de chaque installeur.
- `ps1` : `ConvertTo-Json -Compress` et UTF-8 sans BOM.
- Vérification manuelle avec un `HOME` jetable : `HOME=<tmp> bash install/install.sh`.
- `install.ps1` ne s'exécute pas sur votre vrai `~/.claude` sans votre accord.

[ ]

### T3 — Contrôle au premier `/forge` de la session dans `SKILL.md`
**Effort:** S
**Files:** `skills/forge/SKILL.md`
**Description:** Nouvelle section « Mise à jour du skill — exécuter EN PREMIER », placée avant « Branche de travail ».
- Elle n'est exécutée qu'au premier chargement du skill dans la conversation. Elle est sautée si le skill a déjà été invoqué dans cette conversation (relance, retour de compactage) et en mode délégué.
- Exécuter `bash <SKILL_DIR>/scripts/update-check.sh check`.
- `available` → `AskUserQuestion`, `header` `Update`, question "Forge `<latest>` is available (installed: `<installed>`). Update now?", options `Update now` / `Later`.
- Sur `Update now` → `update-check.sh apply --version <latest>`.
  - `updated` → "Forge updated to `<version>`.", relire `<SKILL_DIR>/SKILL.md` sur le disque et l'exécuter depuis « Branche de travail ». La section de mise à jour est sautée, le contrôle est déjà fait.
  - `failed` → afficher `step` et `detail` tels quels, puis continuer avec la version en place.
- Sur `Later`, ou si le statut est `skipped`, `unreachable` ou `up_to_date` → continuer sans un mot.
- Ajouter une règle `⚠️` : la réponse `Update now` vaut autorisation pour cette exécution de l'installeur seulement.

[ ]

### T4 — Documentation et CHANGELOG
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:**
- Dans les README, en anglais et en français dans le même commit : section « Mise à jour automatique », avec le principe, le contrôle au premier `/forge` de la session, `install.json` et la mise à jour manuelle toujours possible.
- Ajouter le script et les tests dans l'arborescence.
- CHANGELOG : entrée `### Added` sous `[Unreleased]`.
- `project.md` : mettre à jour « Key structure » et « Entry points ».

[ ]

## Risks
- **Script supprimé pendant son exécution :** l'installeur fait `rm -rf` du dossier du skill. La recopie dans un dossier temporaire puis `exec` (T1) l'évite.
- **Détection du premier chargement :** elle repose sur le contexte de la conversation, où une relance porte la mention de ré-invocation. Après un `/clear`, une nouvelle session recommence le contrôle, et c'est voulu.
- **Mode auteur :** une copie de travail en avance sur le dernier tag annonce la version du dernier `## [x.y.z]` du CHANGELOG. Rien n'est proposé tant que le tag distant n'est pas plus récent.
- **Installations existantes :** sans `install.json`, aucun contrôle jusqu'à la prochaine installation manuelle.
- **Écritures de l'installeur :** il réécrit `~/.claude/settings.json`, exactement comme une installation manuelle. Il ne touche ni au registre ni à la configuration Windows. `-ExecutionPolicy Bypass` ne vaut que pour ce processus.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Script `update-check.sh` et ses tests | M | [ ] |
| T2 — Les installeurs écrivent `install.json` | S | [ ] |
| T3 — Contrôle au premier `/forge` de la session dans `SKILL.md` | S | [ ] |
| T4 — Documentation et CHANGELOG | S | [ ] |
| **Total** | **M + 3S (~5-7h)** | |
