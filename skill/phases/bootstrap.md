# Bootstrap

## Actions — dans l'ordre

1. Créer `.claude/branch/<BRANCH>/brief.md` depuis `templates/brief-template.md` avec le Write tool.
   ⚠️ Ne jamais utiliser `mkdir` sur les chemins `.claude/` — utiliser Write tool directement, il crée les dossiers parents automatiquement.
3. Pré-remplir `## Objectif` si l'intention est exprimée dans le trigger ou la conversation.
4. Si `## Objectif` ne peut pas être pré-rempli :
   - Poser la question : "Quel est l'objectif de ce chantier ?"
   - Reformuler en 2-3 phrases claires, demander validation, itérer.
   - Écrire `## Objectif` uniquement après validation explicite.
   - Écrire `.claude/branch/<BRANCH>/brief.md`.

## Analyse

Croiser `@.claude/project.md` avec l'objectif. Points flous → clarifier avant de continuer. Si tout clair → enchaîner sur `phases/plan.md`.
