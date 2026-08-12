# Brief

## Structure du brief

`brief.md` contient deux sections, dans cet ordre : `## Objective` (le but de la tâche) puis `## Scope & rules` (règles immuables, contraintes techniques, périmètre et hors périmètre valables pour toute la durée de la branche — vide à la création, jamais historisée). Les décisions ponctuelles vont dans LOG, jamais dans `brief.md`.

⚠️ `## Objective` et `## Scope & rules` sont des libellés fixes, écrits tels quels quelle que soit la langue de l'utilisateur — seul le contenu des sections suit sa langue.

⚠️ Ne jamais utiliser `mkdir` sur les chemins `.forge/` — Write tool crée les dossiers parents automatiquement.

## Actions — dans l'ordre

1. Pré-remplir `## Objective` si l'intention est exprimée dans le trigger ou la conversation.
2. Si `## Objective` ne peut pas être pré-remplie :
   - Poser la question : "What's the goal of this task?"
   - Reformuler en 2-3 phrases claires, demander validation, itérer.
   - Questions sur les points flous → attendre réponse ; relancer si flou persiste.
   - Écrire `## Objective` uniquement après validation explicite.
3. Écrire `.forge/branch/<BRANCH>/brief.md` — `## Objective` remplie, `## Scope & rules` vide.

## Analyse

Lire `.forge/coding-standards.md`.

Croiser `@.forge/project.md` avec l'objectif. Points flous → clarifier avant de continuer. Si tout clair → continuer directement à l'État 3 : lire et exécuter `phases/p3-log.md`.