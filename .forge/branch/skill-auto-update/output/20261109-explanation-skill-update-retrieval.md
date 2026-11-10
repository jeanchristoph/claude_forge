# Explication — Récupération d'une nouvelle version du skill forge

## 2026-11-09

## Vue d'ensemble

La mise à jour se fait en deux phases, toutes deux portées par `skills/forge/scripts/update.sh` et pilotées par `commands/update.md` :

1. **Détection** (`update.sh check`) : savoir si un tag `vX.Y.Z` plus récent que la version installée existe.
2. **Installation** (`update.sh run`) : cloner ce tag et exécuter son propre installeur.

Le script renvoie du JSON sur une ligne ; l'IA le lit comme contexte interne et formule elle-même les messages.

## Détection — `update.sh check`

État mémorisé dans `install.json` (dossier du skill) :

| Champ | Rôle |
|---|---|
| `version` | version installée |
| `repository` | URL du dépôt interrogé |
| `last_check` | horodatage (secondes) du dernier contrôle réussi |
| `latest` | dernier tag `vX.Y.Z` connu |
| `dismissed` | version refusée (« Later »), plus proposée |

Fonctionnement :

- **Délai de 7 jours** : tant que `last_check` a moins de 7 jours, `check` ne lit que `install.json` — aucune écriture, aucun réseau, aucun processus lancé (`check: "skipped"`).
- **Contrôle échu** : un sous-processus détaché en arrière-plan exécute `git ls-remote --tags --refs` (`check: "started"`), sans faire attendre le lancement de `/forge`.
- **URL** : une URL ssh `git@host:chemin` est convertie en `https://host/chemin` ; `GIT_TERMINAL_PROMPT=0` garantit qu'aucune saisie n'est attendue.
- **Choix du tag** : seuls les tags `vX.Y.Z` comptent ; le plus haut gagne par comparaison numérique de chaque composante (`v0.9.10` > `v0.9.2`).
- **Résultat** : `latest` et `last_check` sont écrits dans `install.json` ; la proposition arrive au `/forge` suivant.
- **`install.json` absent ou illisible** (pas de `last_check` numérique) : contrôle immédiat échu, sur l'URL par défaut `https://github.com/jeanchristoph/claude_forge.git`.
- **Version refusée** : si `latest` égale `dismissed`, elle n'est pas proposée, sauf tag plus récent ou contrôle forcé (`check --force`, au premier plan, quel que soit le délai).

## Installation — `update.sh run`

Déclenchée par le choix « Update now » :

1. `git clone --depth 1 --branch <tag>` dans `${TMPDIR:-/tmp}/forge-update` (dossier recréé à chaque fois).
2. Exécution de **l'installeur du clone lui-même** : `install/install.ps1` via `powershell.exe -ExecutionPolicy Bypass` (portée limitée au processus, rien de persistant) sur msys/cygwin, sinon `install/install.sh`.
3. L'installeur réécrit `install.json` (nouvelle version).
4. Le dossier temporaire est supprimé, succès ou échec.
5. Échec : JSON `status: "failed"`, `reason` (`no known version`, `clone failed`, `installer failed`) et `detail` = 5 dernières lignes de sortie, code de sortie 2.
6. Succès : l'IA invite à relancer `/forge`, car les instructions chargées dans le tour sont celles de l'ancienne version.

## Diagramme de séquence

```
/forge        update.sh            GitHub          install.json
  |--check------>|-------------------------------------->| lit (7 j ?)
  |              |--(échu) ls-remote --tags (fond)->|     |
  |              |<-------- tags vX.Y.Z ------------|     |
  |              |------------- écrit latest/last_check ->|
  |<-JSON--------|
  |  (au /forge suivant : proposition Update now / Later)
  |--run-------->|--clone --depth 1 --branch tag-->|
  |              |<------------ sources ------------|
  |              |-- lance install.ps1 | install.sh du clone
  |              |-- (installeur réécrit install.json)
  |              |-- supprime forge-update
  |<-JSON--------|   -> relancer /forge
```

## Conséquences pratiques

- Seuls les **tags publiés** `vX.Y.Z` comptent : pousser sur `master` ne déclenche rien.
- `git` et un accès https à GitHub sont requis.
- Hors réseau, le contrôle échoue en silence ; `check --force` renvoie `check: "failed"`.
- Un contrôle automatique au plus tous les 7 jours ; le contrôle manuel (`--force`) ignore le délai.

## 2026-11-09 — Le contrôle détaché : attendre sans bloquer

Dans `run_check`, quand le délai de 7 jours est échu (et hors `--force`), une seule ligne lance la requête réseau :

```bash
( refresh_latest_version ) </dev/null >/dev/null 2>&1 &
```

Chaque élément a un rôle précis :

- **`( … )`** : un sous-shell, copie du script en cours. Il hérite des variables déjà lues (`REPOSITORY`, `NOW`, `LATEST_VERSION`…) sans relire `install.json`.
- **`&`** : le sous-shell part en arrière-plan ; le script principal n'attend pas sa fin et passe à la ligne suivante (`check_status=$CHECK_STARTED`, puis `render_check`).
- **`</dev/null >/dev/null 2>&1`** : entrée, sortie et erreurs sont coupées du terminal. Sans cela, l'outil Bash de Claude Code resterait en attente tant qu'un descripteur du processus reste ouvert, et `/forge` serait bloqué.

Ce que fait le sous-processus, seul, après le retour du script :

1. `fetch_latest_tag` exécute `git ls-remote --tags --refs` (0,5 à 1 s) ;
2. il retient le plus haut tag `vX.Y.Z` (comparaison numérique) ;
3. `refresh_latest_version` réécrit `install.json` (`latest`, `last_check`) puis se termine.

Hors réseau, `git` échoue, `fetch_latest_tag` renvoie 1 et rien n'est écrit : `last_check` reste ancien, donc le contrôle est retenté au lancement suivant.

```
temps ->  0 ms        80 ms                    ~1 s
script    |--lit install.json--|--JSON--> fin
principal |   lance le sous-shell (&)
                 \
sous-proc.        |------- git ls-remote (0,5-1 s) ------|-écrit install.json-| fin
                  (détaché : le terminal n'attend pas)
```

Conséquence directe : la nouvelle version est proposée au **/forge suivant**, pas à celui qui a déclenché la requête, puisque le JSON est rendu avant la réponse du réseau. Lors du test, il a fallu deux lancements pour voir la proposition apparaître.

Vérification faite sous Git Bash : le processus détaché survit à la fin de l'appel de l'outil Bash et termine bien l'écriture de `install.json`.

**Alternative non retenue** : attendre au premier plan avec un délai court (environ 2 s, une fois par semaine) pour proposer la version dès le lancement courant. Elle supprime le décalage d'un `/forge`, mais impose une attente visible à l'utilisateur et, hors réseau, le délai entier avant l'échec. Le choix actuel privilégie un démarrage toujours instantané.
