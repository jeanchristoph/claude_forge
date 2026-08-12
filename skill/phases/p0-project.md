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
- Lire `.forge/coding-standards.md`
- Identifier les sections obsolètes ou incomplètes
- Proposer les modifications à l'humain avant d'écrire
- Conserver ce qui est toujours valide tel quel
- Déléguer ensuite la normalisation des libellés ci-dessous

---

## Normalisation des libellés — déléguée, non bloquante

**Périmètre :** `.forge/project.md` et les fichiers de `.forge/branch/<BRANCH>/` uniquement. Ne jamais toucher aux autres branches.

**Libellés attendus :**
- `project.md` → section « Format de sortie » ci-dessus
- `brief.md` → `phases/p2-brief.md`
- `plan.md` → `phases/p4-plan.md`

⚠️ Identifier chaque section par son rôle et sa position, jamais par correspondance de texte — un fichier généré par une version antérieure porte des libellés dans n'importe quelle langue.
⚠️ Renommer le libellé seul. Ne jamais reformuler, réordonner, fusionner ni supprimer un contenu, même obsolète.

**Actions — dans l'ordre :** déléguer à un agent en tâche de fond (`run_in_background: true`), sans attendre son résultat.
1. Pour chaque fichier du périmètre existant : comparer ses titres de sections et libellés de champs aux libellés attendus.
2. Tous conformes → ne rien écrire pour ce fichier.
3. Titre non conforme → le remplacer par le libellé attendu, contenu inchangé.
4. Section attendue absente → ne pas la créer.
5. Section présente sans libellé attendu correspondant → la laisser telle quelle.
6. Aucun renommage sur l'ensemble du périmètre → ne rien afficher.
7. Au moins un renommage → informer en une ligne : "Forge file labels normalized."

⚠️ Ne jamais attendre la fin de l'agent — la normalisation ne bloque jamais le travail en cours.
