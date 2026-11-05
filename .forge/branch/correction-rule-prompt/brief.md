# Brief — correction-rule-prompt

## Objective

Ajouter au skill forge un mécanisme déclenché quand l'utilisateur demande une correction syntaxique, de structure ou de convention de code : forge applique la correction, puis rédige de lui-même une règle (prompt) à ajouter dans `CLAUDE.md`, pour agir d'emblée comme demandé la prochaine fois qu'il rencontre le même cas.

## Scope & rules

- Toujours demander à l'utilisateur avant de modifier son `CLAUDE.md` global ou le `CLAUDE.md` du projet.
- Cette branche construit le mécanisme : aucune règle écrite dans un `CLAUDE.md`.
