# Délégation à un projet lié : le worktree dédié

*2026-10-05*

Quand forge délègue du travail à un projet lié, il ne travaille plus dans le dossier du dépôt lié lui-même : il crée un **worktree git** à côté, nommé `<dossier-lié>-<parent>-<branche>`, et le réutilise s'il existe déjà.

Exemple : dépôt lié `D:/www/topdon_api`, branche liée `forge/CU-123` → worktree `D:/www/topdon_api-forge-CU-123`.

## 1. Pourquoi `/` devient `-`

Le nom de branche `forge/CU-123` contient un `/`, et dans un chemin le `/` est un séparateur de dossiers. En le gardant tel quel, `topdon_api-forge/CU-123` ne désignerait pas un dossier mais deux :

- un dossier `topdon_api-forge`, avec un sous-dossier `CU-123` ;
- une arborescence imbriquée, ambiguë à la lecture (où s'arrête le nom du dépôt, où commence la branche ?) ;
- des collisions : toutes les délégations issues de `forge` s'empileraient sous le même `topdon_api-forge/`.

En remplaçant `/` par `-`, chaque branche liée obtient **un seul dossier, à plat, voisin du dépôt lié**, dont le nom se lit d'un coup d'œil.

## 2. Quand le worktree existe déjà, et pourquoi le réutiliser

Une deuxième délégation vers le même projet lié, depuis la même branche parente, vise la même branche liée `<parent>/<branche>`. Cela arrive par exemple :

- quand d'autres tâches sont déléguées plus tard ;
- à la reprise après une tâche bloquée ;
- quand on relance après une correction.

Le worktree de la première délégation est alors toujours là : seul l'utilisateur le supprime, après la livraison. Forge le réutilise au lieu d'en créer un autre, pour trois raisons :

1. **Git l'impose** : une même branche ne peut pas être extraite dans deux worktrees à la fois (« already checked out »). Un second `git worktree add` échouerait.
2. **Le travail en cours y vit** : les modifications non commitées de la première passe, ainsi que le brief, le log et le plan du projet lié. Un worktree neuf n'en aurait rien.
3. **Pas de prolifération** : un seul dossier par branche liée, pas de doublons à nettoyer.

La détection se fait avec `git -C <LINKED> worktree list --porcelain`, en cherchant la ligne `branch refs/heads/<LINKED_BRANCH>`, et non sur le nom du dossier. C'est plus fiable : l'utilisateur a pu déplacer ou renommer le worktree, git, lui, sait toujours où la branche est extraite.

## 3. Cas particulier : la branche est extraite dans le dossier du dépôt lié

Les anciennes délégations faisaient un `checkout` directement dans le dossier du dépôt lié. Si la branche liée y est encore extraite, `worktree list` la trouve sur le dossier principal lui-même.

Forge ne peut alors ni créer de worktree (la branche est déjà extraite), ni travailler dans ce dossier (c'est précisément ce que le worktree évite). Il **s'arrête et demande** de basculer d'abord ce dossier sur une autre branche ; la délégation reprend ensuite normalement dans un worktree dédié.
