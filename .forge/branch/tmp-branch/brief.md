# Brief — tmp-branch

## Objective

Quand `/forge` est lancé sans argument sur `master`/`main`, la garde de sécurité propose une option de plus : créer une **branche temporaire** sans demander de nom. Forge génère le nom, bascule sur la branche, puis demande directement l'objectif de la tâche (phase Brief).

Le nom suit le format `tmp/<user>-<ddmmyyyy>`. `<user>` vient de la partie locale de `git config user.email`, sans le préfixe numérique des adresses noreply (`<id>+` pour GitHub, `<id>-` pour GitLab), puis convertie en slug : minuscules, sans accents, tout caractère hors `[a-z0-9]` remplacé par `-`. Le préfixe `tmp/` la distingue d'une branche de feature. Exemple : `tmp/jeanchristoph-27102026`.

## Scope & rules
