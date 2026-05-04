# Bootstrap

## Actions — dans l'ordre

1. Créer le dossier `.claude/branch/<BRANCH>/` s'il n'existe pas.
2. Créer `.claude/branch/<BRANCH>/brief.md` depuis le template `templates/brief-template.md`.
3. Pré-remplir `## Objectif` si l'intention est exprimée dans le trigger ou la conversation.
4. Si `## Objectif` ne peut pas être pré-rempli :
   - Poser la question : "Quel est l'objectif de ce chantier ?"
   - Reformuler la réponse de l'humain en 2-3 phrases claires et précises
   - Demander : "C'est bien ça ? On peut affiner ensemble."
   - Itérer autant de fois que nécessaire jusqu'à validation explicite de l'humain
   - Écrire `## Objectif` dans le brief uniquement après validation

## Après validation de l'objectif
- Écrire `.claude/branch/<BRANCH>/brief.md`

## Analyse avant plan
- Croiser `@.claude/project.md` avec l'objectif du brief
- Identifier les points flous, manquants ou potentiellement contradictoires avec la stack ou la structure existante
- Si des points nécessitent clarification : les lister et attendre les réponses avant de continuer
- Si tout est clair : annoncer "Brief analysé, aucun point flou. Je génère le plan." et enchaîner sur `phases/plan.md`
