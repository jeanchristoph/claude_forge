# Project Init

## Objectif
Générer `.claude/project.md` — connaissance stable du projet, commune à toutes les branches.

## Garde — Projet vide

Lister le contenu du dossier racine avec le Glob tool (pattern `*`) — ignorer tous les résultats dont le nom commence par `.` (dotfiles et dotfolders : `.claude`, `.idea`, `.git`, `.env`, etc.).
⚠️ Ne pas utiliser de commande Bash/PowerShell pour lister — les patterns `Where-Object` avec regex déclenchent un blocage sécurité.

Si le dossier est vide (rien en dehors des éléments ignorés) :
- Écrire `.claude/project.md` avec ce contenu minimal :
  ```markdown
  # Project — [à compléter]
  **Généré le :** [date]
  ```
- Dire : "Projet vide détecté. `project.md` initialisé. Enchaîne avec le brief quand tu es prêt."
- Enchaîner automatiquement sur `phases/bootstrap.md`.
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

```markdown
# Project — [Nom du projet]
**Généré le :** [date]

## Stack
- Langage : ...
- Framework / CMS : ...
- Runtime / version : ...
- DB : ...
- Serveur / runtime : ...

## Structure clés
[arborescence simplifiée des dossiers principaux et leur rôle]

## Points d'entrée
- ...

## Conventions détectées
- Nommage : ...
- Architecture : ...
- Gestion d'erreurs : ...

## Fichiers critiques
[fichiers non évidents à lire en priorité avant de coder]

## Outils & accès
- MCPs disponibles : ...
- Documentation externe : ...
```

## Après génération ou mise à jour
- Présenter le fichier à l'humain.
- Demander : "Ce `project.md` te semble correct ? Des éléments à corriger ?"
- Itérer si corrections demandées.
- Écrire `.claude/project.md` avec le Write tool uniquement après validation explicite.
  ⚠️ Ne jamais utiliser `mkdir` sur les chemins `.claude/` — Write tool crée les dossiers parents automatiquement.
- Enchaîner automatiquement sur `phases/bootstrap.md`.

---

## Mode mise à jour (project.md déjà existant)
Ne pas réécrire intégralement — modifier uniquement ce qui a changé :
- Lire l'existant `@.claude/project.md`
- Identifier les sections obsolètes ou incomplètes
- Proposer les modifications à l'humain avant d'écrire
- Conserver ce qui est toujours valide tel quel
