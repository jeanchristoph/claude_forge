## Objective

Rendre le lancement de forge plus rapide et plus intuitif. Le skill est allégé (découpage de `p5-resume.md` et du mode délégué, une seule lecture par tour, suppression de `p3-log.md`) et un script `status.sh` testé fournit l'état au démarrage. `/forge` et `/forge-clickup` acceptent en argument un code ClickUp complet ou un objectif, à la place des alias de liste, et le lancement perd ses questions superflues (objectif avant branche sur `master`, mode express XS, pas de question `Mode` pour une seule tâche).

## Scope & rules

- Argument ClickUp : code complet (`PRJ-1133`) ou `id` brut uniquement — jamais de numéro nu, pas de clé `task_prefix`.
- Alias de liste supprimés : argument de `/forge-clickup` et clé `aliases` de `clickup.json`.
- `forge-clickup` reste le seul à ouvrir une tâche et créer sa branche : `forge` lui passe la main.
- La règle « pas de code sans confirmation » reste entière : le mode express retire une question, jamais le feu vert.
