# Bootstrap

## Format du brief

```markdown
# Brief — <BRANCH>

## Objectif
```
⚠️ Ne jamais utiliser `mkdir` sur les chemins `.claude/` — Write tool crée les dossiers parents automatiquement.

## Actions — dans l'ordre

1. Pré-remplir `## Objectif` si l'intention est exprimée dans le trigger ou la conversation.
2. Si `## Objectif` ne peut pas être pré-rempli :
   - Poser la question : "What's the goal of this task?"
   - Reformuler en 2-3 phrases claires, demander validation, itérer.
   - Questions sur les points flous → attendre réponse ; relancer si flou persiste.
   - Écrire `## Objectif` uniquement après validation explicite.
3. Écrire `.claude/branch/<BRANCH>/brief.md`.

## Analyse

Croiser `@.claude/project.md` avec l'objectif. Points flous → clarifier avant de continuer. Si tout clair → enchaîner sur `phases/plan.md`.