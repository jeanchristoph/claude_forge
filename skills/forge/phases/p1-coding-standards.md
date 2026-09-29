# Coding Standards Init

## Objectif
Générer `.forge/coding-standards.md` — règles de code à appliquer au moment d'écrire du code, communes à toutes les branches, rangées par nature : `## Architecture`, `## Constraints`, `## Conventions`.

## Garde
Si `.forge/coding-standards.md` existe déjà → passer directement à `phases/p2-brief.md` sans réécrire.

## Génération
Écrire (Write tool) dans la langue de l'utilisateur, au format ci-dessous.

⚠️ Titres de sections écrits tels quels, en anglais, quelle que soit la langue de l'utilisateur — seul le contenu suit sa langue. Structure fixe : aucune section `##`, ni sous-section de `## Architecture`, ajoutée, renommée ou supprimée — seules les sous-sections de `## Constraints` et de `## Conventions` varient, une par sujet.

### Contenu — dans l'ordre
1. Relire `.forge/project.md` — `## Key structure` et `## Detected conventions` fournissent la matière.
2. Lister les dossiers à la racine avec Glob tool (pattern `*/`) si `## Key structure` ne suffit pas.
3. Rédiger chaque section depuis ce qui est observé, adapté à la forme du projet — skill, application, bibliothèque, site, scripts.
   - ⚠️ Jamais « module », « couche » ni aucune architecture présupposée : décrire uniquement ce que le projet contient.
   - Section sans matière observée → `<!-- pending -->` sous son titre, section conservée.
   - Projet vide (`project.md` = `<!-- pending -->`) → toutes les sections en `<!-- pending -->`.
4. Lire `~/.claude/CLAUDE.md` s'il existe, puis retirer du contenu rédigé toute règle qu'il énonce déjà.
   - ⚠️ `coding-standards.md` ne recopie jamais le `CLAUDE.md` global : il ne contient que ce qui est propre au projet — ajout ou dérogation. Une dérogation nomme la règle globale qu'elle remplace.

### Format de sortie

```markdown
# [Nom du projet]

[1-2 lignes : conventions de code (structure, nommage, principes) à appliquer au moment d'écrire du code — norme continue, pas un audit ponctuel, complétée au fil du projet.]

## Architecture

### Directory layout
[dossiers et rôle de chacun — où placer un nouveau fichier]

### Naming
[tous les identifiants : fichiers, dossiers, classes, méthodes, variables, constantes, tables et colonnes de base, booléens]

### Dependencies
[interfaces, injection, qui dépend de quoi]

## Constraints

### [Sujet]
[règles non négociables — réalité technique ou décision immuable dont la violation casse ou fausse un résultat ; une sous-section par sujet]

## Conventions

### [Sujet]
[choix d'équipe pour la cohérence ; une sous-section par sujet selon le projet — `Language`, `Code`, `Errors & logs`, `Tests`, `Comments`, `Git`…]
```

⚠️ Ne jamais utiliser `mkdir` sur les chemins `.forge/` — Write tool crée les dossiers parents automatiquement.

## Après génération
Continuer directement à l'État 2 : lire et exécuter `phases/p2-brief.md`.
