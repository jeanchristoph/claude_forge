# Migration décisions → LOG

## Garde
Si LOG existe déjà → ne rien faire, continuer directement à l'État 4 : lire et exécuter `phases/p4-plan.md`.

## Réaction — déléguée, non bloquante

Déléguer à un agent en tâche de fond (`run_in_background: true`), sans attendre son résultat :
1. Si BRIEF ne contient pas de section `## Décisions & Contraintes` (rien à migrer) → créer LOG vide. Informer : "`log.md` créé."
2. Sinon (BRIEF contient `## Décisions & Contraintes`) → migration :
   - Renommer cette section en `## Contraintes`.
   - Chaque entrée datée (`- [date] ...`, action chronologique) est déplacée vers LOG (créé si absent) tel quel — aucune reformulation, aucun retraitement, simple commande de déplacement.
   - Chaque entrée non datée (règle) reste dans `## Contraintes`.
   - Informer : "Décisions migrées vers `log.md`."

## Suite
Continuer immédiatement à l'État 4 sans attendre l'agent : lire et exécuter `phases/p4-plan.md`.
