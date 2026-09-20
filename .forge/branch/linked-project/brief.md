# Brief — linked-project

## Objective

Permettre à forge de déléguer une ou plusieurs tâches du plan courant vers un **projet lié** : un dossier extérieur au projet de la session, déjà forgé (`.forge/` présent — sinon refus, jamais d'initialisation silencieuse). Le projet lié reçoit la même branche git que le parent (`<BRANCH>`, créée depuis sa branche par défaut à jour si absente), une copie du brief parent enrichie d'un bloc `## Origin` portant le chemin du parent, la branche, et le **mandat** : les tâches déléguées recopiées intégralement. Son plan est rédigé exclusivement à partir de ce mandat, chaque tâche enfant tracée vers sa tâche parente (`← parent T<n>`) ; aucune tâche hors mandat n'est créée, un besoin hors périmètre remonte au parent.

L'exécution dans le projet lié se fait dans un **contexte forge isolé et imperméable** : un sous-agent qui ne reçoit que le chemin du projet lié, `<BRANCH>` et l'ordre d'exécuter le skill forge en mode délégué. Aucun `project.md`, standard, plan ni log ne traverse la cloison. La frappe est retirée du skill (peu utilisée, relève des préférences de codage dans CLAUDE.md) ; en mode délégué, toute question bloquante remonte à l'agent principal sous forme structurée (`FORGE_QUESTION`) — relayée à l'utilisateur via `AskUserQuestion`, réponse renvoyée par `SendMessage`. Le rapport final (`FORGE_DONE`) est la seule sortie : tâches vertes, tâches bloquées avec raison, besoins hors périmètre.

Côté parent, chaque tâche déléguée est annotée à l'envoi (`delegated to <dossier> @ <BRANCH>`) et cochée `[x]` ou marquée `[!] blocked` uniquement au retour du rapport, avec une entrée log par tâche. Le parent ne coche jamais une tâche déléguée de lui-même. Au « grave » du parent, la livraison du projet lié est proposée — quels projets liés, sur quelles branches — et exécutée par le parent dans la même séquence, sous une confirmation unique.

## Scope & rules

- La délégation vise deux cibles : un projet lié (dossier hors ROOT, mandat, `SCOPE: linked`) ou une branche du dépôt courant (worktree frère `<dépôt>-<X>`, sans mandat, `SCOPE: branch`). Dans les deux cas le sous-agent est étanche et toute question bloquante remonte par `FORGE_QUESTION`, qui porte le contenu entier à trancher ; en `SCOPE: branch`, aucun raccourci — chaque choix est relayé à l'utilisateur.
- La branche d'un projet lié est toujours `<parent>/<BRANCH>` — jamais le nom nu de la branche parente : le préfixe dit d'où vient la délégation, la partie droite reste identique pour la correspondance.
