# Brief — auto-update

## Objective

Au lancement de `/forge`, hors mode délégué, forge vérifie si une version plus récente du skill est publiée : le tag le plus récent du dépôt distant est comparé à la version installée. Ce contrôle a lieu au plus une fois par 24 h et reste silencieux hors réseau.

Si une version plus récente existe, forge propose de mettre à jour. Sur accord, il clone ce tag dans un dossier temporaire, lance l'installeur de la plateforme (`install.ps1` sous Windows, `install.sh` sous Unix), supprime le dossier temporaire, puis demande de relancer `/forge`.

Pour cela, l'installeur écrit `~/.claude/skills/forge/install.json` : version installée, URL du dépôt, date du dernier contrôle. Une installation sans ce fichier n'est jamais contrôlée.

## Scope & rules
