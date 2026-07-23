# Coding Standards Init

## Objectif
Générer `.forge/coding_standards.md` — conventions de code (structure, nommage, principes) à appliquer au moment d'écrire du code, communes à toutes les branches.

## Garde
Si `.forge/coding_standards.md` existe déjà → passer directement à `phases/p2-brief.md` sans réécrire.

## Génération
Écrire (Write tool) dans la langue de l'utilisateur, avec :
- Un titre : nom du projet
- Une courte explication (1-2 lignes) précisant que ce fichier contient les conventions de code (structure, nommage, principes) à appliquer au moment d'écrire du code — une norme continue, pas un audit ponctuel — à compléter au fil du projet.

⚠️ Ne jamais utiliser `mkdir` sur les chemins `.forge/` — Write tool crée les dossiers parents automatiquement.

## Après génération
Revenir à la section « Détection d'état » de `SKILL.md` pour enchaîner sur l'état suivant.
