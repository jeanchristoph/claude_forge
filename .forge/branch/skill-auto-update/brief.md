## Objective

Au lancement de `/forge`, hors mode délégué, forge signale qu'une version plus récente du skill est publiée, sans jamais ralentir le démarrage. Le dernier tag `vX.Y.Z` du dépôt distant (`git ls-remote --tags`, URL `https`, sans invite interactive) est comparé à la version installée.

Rapidité au démarrage : `update.sh check` s'exécute dans le même appel Bash que `status.sh`. Il lit `install.json` avec les commandes internes de bash, sans aucune écriture. Si le dernier contrôle date de plus de 7 jours, ou si `install.json` est absent ou illisible, il lance l'interrogation du dépôt distant en arrière-plan, détachée, sans l'attendre. Seule cette interrogation, une fois par semaine au plus, réécrit `install.json`, et la nouvelle version est proposée au `/forge` suivant. Hors réseau → silence, rien ne bloque.

Un déclencheur manuel, « mettre à jour la forge » / « update the forge » (sur le modèle de « ranger la forge »), interroge le dépôt distant immédiatement, au premier plan (`update.sh check --force`), et signale aussi l'absence de nouvelle version ou l'échec réseau.

Le contrôle et l'application vivent dans un script dédié `skills/forge/scripts/update.sh`, à deux modes et sortie JSON, sur le modèle de `engrave.sh` : `check` et `run` (récupère le tag dans un dossier temporaire, lance l'installeur de la plateforme, nettoie). `status.sh` reste inchangé. Version plus récente connue → forge la propose via `AskUserQuestion` ; sur accord, `update.sh run` s'exécute, puis forge demande de relancer `/forge`.

`~/.claude/skills/forge/install.json` porte tout l'état : version installée, URL du dépôt, date du dernier contrôle, dernier tag publié connu. L'installeur (`install.ps1` / `install.sh`) l'écrit ; l'interrogation du dépôt distant le réécrit en écriture simple, et un échec reste silencieux. Sans `install.json` lisible (installation antérieure, fichier abîmé), l'URL par défaut du dépôt est utilisée et la version installée est considérée comme dépassée : la mise à jour est proposée dès que le dernier tag est connu, et l'installeur réécrit `install.json`.

## Scope & rules
