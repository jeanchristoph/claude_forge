# Project Init

## Objectif
Générer `.forge/project.md` — connaissance stable du projet, commune à toutes les branches.

## Garde — Projet vide

Lister le contenu du dossier racine avec le Glob tool (pattern `*`) — ignorer tous les résultats dont le nom commence par `.` (dotfiles et dotfolders : `.forge`, `.idea`, `.git`, `.env`, etc.).
⚠️ Ne pas utiliser de commande Bash/PowerShell pour lister — les patterns `Where-Object` avec regex déclenchent un blocage sécurité.

Si le dossier est vide (rien en dehors des éléments ignorés) :
- Écrire `.forge/project.md` avec le contenu : `<!-- pending -->`
- Dire : "Empty project detected. `project.md` initialized. Start with the brief when ready."
- Continuer directement à l'État 1 : lire et exécuter `phases/p1-coding-standards.md`.
- STOP — ne pas continuer l'exploration.

## Exploration — lire dans l'ordre ce qui existe

### Stack
- `package.json` / `composer.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` / `*.csproj` — langage, framework, version runtime
- `docker-compose.yml` / `Dockerfile` — services, DB, versions
- `.nvmrc` / `.tool-versions` / `runtime.txt` — versions imposées

### Structure
- Lister les dossiers à la racine avec Glob tool (pattern `*/`)
- Repérer `src/`, `app/`, `lib/`, `modules/`, `packages/`
- Identifier les points d'entrée (`index.ts`, `main.py`, `Program.cs`, `app.php`…)
- Lire `README.md` en priorité si présent

### Conventions
- `.eslintrc.*` / `.prettierrc.*` / `biome.json` / `pyproject.toml` / `.editorconfig`
- Lire **3 à 5 fichiers représentatifs** du code source pour détecter nommage et patterns

### Vérifications
- Scripts de contrôle du projet : `scripts` de `package.json` / `composer.json`, cibles d'un `Makefile`, configuration de tests (`phpunit.xml`, `vitest.config.*`, `pytest.ini`), suites `tests/*`
- En tirer `**Check pattern:**` : expression régulière étendue qui reconnaît chaque commande de vérification (types, lint, architecture, tests) n'importe où dans la ligne de commande — jamais ancrée par `^` : une vérification arrive souvent après un `cd … &&` ou dans une boucle —, lue par le hook de mesure pour compter le temps de vérification. Aucune commande trouvée → ligne omise.

## Format de sortie

⚠️ Titres de sections et libellés de champs écrits tels quels ci-dessous, en anglais, quelle que soit la langue de l'utilisateur — seul le contenu suit sa langue.

```markdown
# Project — [Nom du projet]
**Generated:** [date]

## Stack
- Language: ...
- Framework / CMS: ...
- Runtime / version: ...
- DB: ...
- Server: ...

## Key structure
[arborescence simplifiée des dossiers principaux et leur rôle]

## Entry points
- ...

## Detected conventions
- Naming: ...
- Architecture: ...
- Error handling: ...

## Critical files
[fichiers non évidents à lire en priorité avant de coder]

## Tools & access
- Available MCPs: ...
- External documentation: ...
**Check pattern:** `(npm run (lint|test|typecheck)|bash tests/)`
```

⚠️ `**Check pattern:**` : une seule ligne, motif entre accents graves, jamais d'accent grave dans le motif.

## Après première génération — `project.md` absent
- Écrire `.forge/project.md` avec le Write tool, sans présentation ni question.
  ⚠️ Ne jamais utiliser `mkdir` sur les chemins `.forge/` — Write tool crée les dossiers parents automatiquement.
- Dire : "`project.md` written — say \"clean the forge\" to adjust it; `/forge help` lists every command."
- Exécuter « Contrôle — hook de mesure » ci-dessous.
- Continuer directement à l'État 1 : lire et exécuter `phases/p1-coding-standards.md`.

## Contrôle — hook de mesure

Chercher `time-hook.sh` dans `~/.claude/settings.json` avec le Grep tool. Absent → afficher une ligne, sans question ni écriture :
> "Time measurement is off: run the forge installer (`install-windows.bat` or `install-unix.sh`) to enable it."

⚠️ Jamais d'écriture dans les réglages de Claude Code : seul l'installeur, lancé par l'utilisateur, les modifie.

---

## Mode mise à jour (project.md déjà existant)
Ne pas réécrire intégralement — modifier uniquement ce qui a changé :
- Lire l'existant `@.forge/project.md`
- Lire `.forge/coding-standards.md`
- Identifier les sections obsolètes ou incomplètes — ligne `**Check pattern:**` absente comprise (section « Vérifications » ci-dessus)
- Proposer les modifications à l'humain avant d'écrire
- Conserver ce qui est toujours valide tel quel
- Écrire `.forge/project.md` après validation explicite.
- Exécuter « Contrôle — hook de mesure » ci-dessus. STOP — ne pas continuer.

