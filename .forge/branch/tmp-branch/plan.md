# Plan — tmp-branch
**Objective:** Sur `master`/`main` sans argument, la garde propose de créer une branche temporaire `tmp/<partie-locale-email>-<ddmmyyyy>` sans demander de nom, puis passe directement à l'objectif.
**Date:** 2026-10-27

## Tasks

### T1 — Script `temp-branch.sh` et ses tests
**Effort:** M
**Files:** `skills/forge/scripts/temp-branch.sh`, `tests/temp-branch.test.sh`
**Description:** Le script s'appelle avec `temp-branch.sh [--root <dir>] [--date <ddmmyyyy>]`. `--date` sert à rendre les tests déterministes ; par défaut, il prend `date +%d%m%Y`. En-tête, constantes `readonly` et codes de sortie suivent le modèle d'`engrave.sh`. Sa logique :
- Lire `git config user.email` et prendre la partie avant `@`.
- Retirer le préfixe noreply : `^[0-9]+\+` pour GitHub, `^[0-9]+-` uniquement si le domaine est `users.noreply.gitlab.com`.
- Convertir en slug : accents translittérés (`iconv`), minuscules, caractères hors `[a-z0-9]` remplacés par `-`, tirets multiples fusionnés, tirets de début et de fin retirés.
- Nom de base : `tmp/<slug>-<ddmmyyyy>`. Si ce nom existe déjà, essayer `-2`, `-3`… jusqu'au premier nom libre.
- Lancer `git checkout -b <nom>` depuis le `HEAD` courant.
- Écrire le résultat en JSON sur une ligne : `{"status":"created","branch":"tmp/jeanchristoph-27102026"}`. E-mail vide ou slug vide → `{"status":"no_identity"}` et sortie `1`. Échec git → `{"status":"failed","detail":"..."}` et sortie `2`.

Les tests s'exécutent dans des dépôts jetables. Ils couvrent :
- e-mail classique (`claude.malaval@topdata.fr` → `tmp/claude-malaval-27102026`) ;
- noreply GitHub et noreply GitLab ;
- accents et majuscules ;
- e-mail absent et e-mail réduit à des caractères spéciaux ;
- doublon du jour (`-2`, puis `-3`) ;
- échec de checkout (working tree en conflit).

[x] 16 tests verts ; échec git simulé par une branche `tmp` qui bloque `tmp/…`

### T2 — Garde de sécurité de `SKILL.md`
**Effort:** S
**Files:** `skills/forge/SKILL.md`
**Description:** La garde passe à trois options, dans cet ordre :
- `Temporary branch` → "I create `tmp/<you>-<date>` and switch to it — no name asked." ;
- `Stay on <BRANCH>` ;
- `Create a branch`.

Si l'utilisateur choisit `Temporary branch` :
- appel : `bash <SKILL_DIR>/scripts/temp-branch.sh --root <ROOT>` ;
- `created` → BRANCH = `branch`, une ligne "On branch `<branch>`.", puis la détection d'état continue (État 2 — Brief, question d'objectif immédiate) ;
- `no_identity` → une ligne "No git email configured — branch name required.", puis le parcours `Create a branch` (nom demandé en texte libre) ;
- `failed` → afficher `detail` tel quel, puis STOP.

La rédaction suit `coding-standards.md` : infinitif, `→`, issues explicites.

[x] Option placée en tête, nom calculé par le script uniquement (⚠️ ajouté)

### T3 — Documentation et CHANGELOG
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:**
- **README, deux langues dans le même commit :** sections « Safety guard » / « Garde de sécurité » et puce « main/master guard » du résumé, avec la troisième option, le format du nom, les suffixes `-2`… et le repli sans e-mail.
- **CHANGELOG :** entrée `### Added` sous `[Unreleased]`.
- **`.forge/project.md` :** ajouter `scripts/temp-branch.sh` et `tests/temp-branch.test.sh` dans « Key structure ».

[x]

## Risks
- Le `/` dans `tmp/...` crée des sous-dossiers `.forge/branch/tmp/<slug>-<date>/`. Les hooks precompact concatènent le nom de branche dans le chemin, ce qui reste compatible. À vérifier pendant T2.
- La translittération par `iconv` varie selon la plateforme : `//TRANSLIT` peut produire `?` ou `'` sous Git Bash ou macOS. Le remplacement des caractères hors `[a-z0-9]` absorbe ces écarts, et les tests le vérifient.
- La date est celle de la machine locale : une branche créée vers minuit peut porter la date de la veille ou du lendemain selon le fuseau. Impact négligeable.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Script `temp-branch.sh` et ses tests | M | [x] |
| T2 — Garde de sécurité de `SKILL.md` | S | [x] |
| T3 — Documentation et CHANGELOG | S | [x] |
| **Total** | **M + 2S (~4-6h)** | |
