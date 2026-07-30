# Brief

## Structure du brief

`brief.md` contient deux sections, titrées dans la langue de l'utilisateur : une section objectif (le but de la tâche) et une section contraintes (règles immuables et contraintes techniques valables pour toute la durée de la branche — vide à la création, jamais historisée). Les décisions ponctuelles vont dans LOG, jamais dans `brief.md`.

⚠️ Ne jamais utiliser `mkdir` sur les chemins `.forge/` — Write tool crée les dossiers parents automatiquement.

## Actions — dans l'ordre

1. Pré-remplir la section objectif si l'intention est exprimée dans le trigger ou la conversation.
2. Si la section objectif ne peut pas être pré-remplie :
   - Poser la question : "What's the goal of this task?"
   - Reformuler en 2-3 phrases claires, demander validation, itérer.
   - Questions sur les points flous → attendre réponse ; relancer si flou persiste.
   - Écrire la section objectif uniquement après validation explicite.
3. Écrire `.forge/branch/<BRANCH>/brief.md` — section objectif remplie, section contraintes vide.

## Analyse

Lire `.forge/coding_standards.md`.

Croiser `@.forge/project.md` avec l'objectif. Points flous → clarifier avant de continuer. Si tout clair → continuer directement à l'État 3 : lire et exécuter `phases/p3-log.md`.