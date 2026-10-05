# Le vocabulaire pour dire à une IA / un outil : « fais-le sans me poser de question »

## 2026-10-05

### 1. Formulations en langage naturel dans un prompt

Expressions courantes, de la plus directe à la plus nuancée :

- **"just do it"** / **"don't ask, just do it"** : exécuter immédiatement, sans demander de validation.
- **"go ahead"** / **"proceed without asking"** : feu vert explicite pour la suite des étapes.
- **"no questions"** : pas de clarification attendue, faire le choix le plus raisonnable.
- **"use your best judgment"** : déléguer les arbitrages mineurs à l'outil.
- **"act autonomously"** : enchaîner les étapes seul jusqu'au résultat.
- **"fire and forget"** : lancer la tâche et ne plus s'en occuper, pas d'interaction en cours de route.
- **"hands-off"** : l'utilisateur ne veut pas intervenir pendant l'exécution.

### 2. Noms de modes dans les outils d'IA de code

Les noms exacts évoluent vite selon les versions : toujours vérifier la documentation de la version installée.

- **"YOLO mode"** : terme popularisé par Cursor (exécution automatique des commandes), renommé ensuite en *auto-run*.
- **Gemini CLI** : `--yolo` approuve automatiquement toutes les actions.
- **Codex CLI** : `--full-auto` (exécution autonome dans un bac à sable), et un mode de contournement total des approbations et du bac à sable, avec l'alias `--yolo`.
- **Claude Code** : modes de permission
  - `default` : demande avant chaque action sensible ;
  - `acceptEdits` : accepte les modifications de fichiers sans confirmation ;
  - `plan` : lecture et planification seulement, aucune modification ;
  - `bypassPermissions` : plus aucune demande, activé par `--dangerously-skip-permissions` ;
  - mode **auto** : l'outil décide seul des actions à valider, avec des garde-fous ;
  - `-p` (*print*) : exécution non interactive, dite *headless*, pour les scripts et la CI.
- **Aider** : `--yes-always` répond « oui » à toutes les confirmations.

### 3. Conventions Unix historiques

Le besoin n'est pas nouveau : les outils en ligne de commande ont fixé un vocabulaire bien avant les IA.

- `-y` / `--yes` / `--assume-yes` : répondre « oui » d'avance (`apt-get install -y`).
- `--force` : passer outre les vérifications ou avertissements (`rm -f`, `git push --force`).
- `--no-confirm` : supprimer l'étape de confirmation (`pacman --noconfirm`).
- `--non-interactive` : ne jamais attendre de saisie, échouer plutôt que bloquer.
- `--quiet` / `-q` : réduire la sortie ; souvent combiné aux précédents dans les scripts.

### 4. Lien avec forge : `grave!`

Dans forge, `grave!` reprend cette idée : le `!` marque l'**impératif, sans discussion**.
C'est la même convention que vim, où le `!` force l'action :

- `:q!` : quitter sans enregistrer, sans avertissement ;
- `:w!` : écrire même si le fichier est en lecture seule.

Un alias textuel serait possible (`grave go`, `grave yolo`), mais le `!` a deux avantages :
il est court, et il est déjà idiomatique pour tout développeur habitué à vim ou au shell.
Il se lit sans documentation : « grave, et ne me demande rien ».

### 5. Bonnes pratiques

Un mode sans confirmation reste un outil puissant ; il doit être encadré :

- **Explicite** : jamais activé par défaut ni déduit implicitement ; c'est l'utilisateur qui le demande, en toutes lettres.
- **Ponctuel** : il vaut pour une commande ou une séquence, pas pour toute la session ni les suivantes.
- **Avec garde-fous** : supprimer les questions ne supprime pas les protections.
  - pas de `git push --force`, pas de réécriture d'historique partagé ;
  - arrêt immédiat sur conflit (fusion, rebase) ou sur erreur, avec un compte rendu clair ;
  - aucune action irréversible hors du périmètre demandé.
- **Traçable** : un résumé de ce qui a été fait, pour pouvoir vérifier ou revenir en arrière.

En résumé : « sans question » signifie « sans interruption pour les décisions de routine »,
jamais « sans limite ».
