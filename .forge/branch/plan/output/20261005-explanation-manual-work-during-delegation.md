# Travailler à la main pendant qu'un agent forge délégué travaille

## 2026-10-05

**Question :** puis-je continuer à coder à la main pendant qu'un sous-agent forge exécute une délégation ?

**Réponse courte :** oui, mais tout dépend du type de délégation. La délégation de branche (worktree) isole le travail ; la délégation vers un projet lié, non.

### 1. Projet lié (`SCOPE: linked`)

Le parent prépare le dépôt lié avec `git -C <LINKED> checkout <parent>/<branche>` (ou la crée), puis le sous-agent travaille **directement dans le working tree du dépôt lié**. Aucun worktree. À la fin, le parent livre via `git -C <LINKED>` : `git add` de tout le contenu modifié, message de commit généré uniquement à partir des tâches déléguées.

Risques si vous travaillez à la main dans ce même dossier au même moment :

- **Même fichier modifié par les deux.** L'outil Edit de Claude Code refuse d'écrire si le fichier a changé depuis sa dernière lecture : protection partielle seulement, car un Write écrase le fichier sans vérification.
- **Changement de branche sous l'agent : le pire cas.** L'agent continue sans le savoir sur la mauvaise branche ; ses modifications atterrissent au mauvais endroit.
- **Commandes git concurrentes** (`commit`, `stash`, `reset`…) : elles modifient l'index ou le working tree pendant que l'agent s'y appuie.
- **Vos modifications partent dans le commit de livraison.** Le `git add` final embarque tout, sous un message qui ne décrit que les tâches déléguées.

Ce qui reste sûr :

- la lecture seule ;
- l'édition de fichiers clairement hors du mandat, en acceptant qu'ils finissent dans le commit de livraison ;
- attendre le `FORGE_DONE`.

Jamais de `checkout` d'une autre branche dans ce dossier tant que l'agent travaille.

### 2. Branche du même dépôt (`SCOPE: branch`)

Le sous-agent travaille dans un **worktree git séparé**, dossier frère du dépôt : `<dossier-du-dépôt>-<X>`.

- Vous pouvez continuer librement dans le dossier principal, sur votre propre branche : fichiers distincts, index distinct, HEAD distinct.
- Git refuse de faire un `checkout` de `<X>` dans le dossier principal tant qu'elle est extraite dans le worktree : pas de collision possible par erreur.
- Travailler à la main **à l'intérieur du worktree** expose aux mêmes risques que le cas 1.
- Le worktree reste en place après la délégation : `git worktree remove <WORKTREE>` une fois la branche gravée.

### 3. Synthèse

| Situation | Possible ? | Risque | Conseil |
|---|---|---|---|
| Projet lié, même dossier, lecture seule | Oui | Nul | Libre |
| Projet lié, édition de fichiers hors mandat | Oui, avec réserve | Fichiers embarqués dans le commit de livraison | Accepter ou attendre la fin |
| Projet lié, édition des fichiers du mandat | Non | Écrasement, conflit avec l'agent | Attendre `FORGE_DONE` |
| Projet lié, commandes git (`commit`, `stash`, `reset`) | Non | Index et working tree perturbés | Attendre `FORGE_DONE` |
| Projet lié, `checkout` d'une autre branche | Jamais | L'agent continue sur la mauvaise branche | Interdit |
| Branche, dossier principal du dépôt | Oui | Nul | Travailler librement |
| Branche, à l'intérieur du worktree | Non | Mêmes risques que le projet lié | Attendre `FORGE_DONE` |

### Recommandation

Pour travailler en parallèle, privilégier la délégation de branche (worktree) ou rester dans le dépôt principal. Pour un projet lié, attendre la fin de la délégation, ou ne toucher que des fichiers distincts sans aucune commande git.
