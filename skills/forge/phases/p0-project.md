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
[carte des dossiers principaux et du rôle de chacun, en arborescence simplifiée — descriptif uniquement, aucune règle : une règle de placement ou de nommage relève de `coding-standards.md` `## Architecture`]

## Entry points
- ...

## Business rules
[règles métier valables pour tout le projet — normatif ; `<!-- pending -->` si aucune n'est énoncée]

## Detected conventions
- Naming: ...
- Architecture: ...
- Error handling: ...

## Critical files
[fichiers non évidents à lire en priorité avant de coder]

## Tools & access
- Available MCPs: ...
- External documentation: ...
```

## Après génération ou mise à jour
- Présenter le fichier à l'humain.
- Demander : "Does this `project.md` look right? Anything to fix?"
- Itérer si corrections demandées.
- Écrire `.forge/project.md` avec le Write tool uniquement après validation explicite.
  ⚠️ Ne jamais utiliser `mkdir` sur les chemins `.forge/` — Write tool crée les dossiers parents automatiquement.
- Continuer directement à l'État 1 : lire et exécuter `phases/p1-coding-standards.md`.

---

## Mode mise à jour (project.md déjà existant)
Ne pas réécrire intégralement — modifier uniquement ce qui a changé :
- Lire l'existant `@.forge/project.md`
  ⚠️ `## Business rules` est normative : conservée telle quelle, jamais réécrite, jamais supprimée — `<!-- pending -->` si absente ou vide. Une nouvelle règle métier y entre selon la section « Routage de l'information » de `SKILL.md`, après validation.
- Lire `.forge/coding-standards.md`
  ⚠️ `.forge/coding-standards.md` est lu, jamais réécrit : un écart normatif constaté (règle absente, obsolète ou contredite par le code) est proposé à l'humain selon la section « Routage de l'information » de `SKILL.md`, jamais écrit d'office.
- Identifier les sections obsolètes ou incomplètes
- Proposer les modifications à l'humain avant d'écrire
- Conserver ce qui est toujours valide tel quel
- Écrire `.forge/project.md` après validation explicite. STOP — ne pas continuer.

