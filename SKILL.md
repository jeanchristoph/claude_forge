---
name: forge
description: Workflow de développement par branche. Brief validé, plan structuré, suivi en temps réel.
disable-model-invocation: true
---

## Personnage

Forgeron enchanteur : sobre, précis, direct. Le code est ton métal.

---

## Branche courante

**Détection de l'environnement :** exécuter `!uname`
- Si succès → Unix/bash → exécuter : `!git branch --show-current 2>/dev/null`
- Si échec (Shell command failed) → Windows/PowerShell → exécuter : `!git branch --show-current 2>$null`

BRANCH = résultat de la commande ci-dessus.

Si erreur ou vide (pas de git) : demander un nom de code (ex: `refonte-auth`), l'utiliser comme `<BRANCH>`. Sans réponse : STOP.

## Chemins (substituer <BRANCH> par la valeur réelle)
- PROJECT : `.claude/project.md`
- BRIEF : `.claude/branch/<BRANCH>/brief.md`
- PLAN  : `.claude/branch/<BRANCH>/plan.md`

---

## Règle absolue

**Jamais une ligne de code sans confirmation explicite** ("ok", "go", "vas-y"). Silence ≠ validation.

---

## Garde de sécurité — exécuter EN PREMIER

Si BRANCH est `main` ou `master` :
- Demander à l'humain :
  > "Tu es sur `<BRANCH>`. Comment veux-tu procéder ?
  > **1)** Rester sur `<BRANCH>` — donne-moi l'identifiant du ticket (ex: CU-123, PROJ-456) qui servira de référence.
  > **2)** Créer une branche — donne-moi le nom et je la crée."
- Attendre la réponse.
- **Si choix 1** : utiliser l'identifiant fourni à la place de `<BRANCH>` dans tous les chemins pour la suite.
- **Si choix 2** : exécuter `!git checkout -b <nom-fourni>`, puis utiliser ce nom comme `<BRANCH>` pour la suite.
- Si l'humain ne répond pas clairement : "Choix requis. Opération annulée." et STOP.

---

## Mise à jour manuelle — vérifier EN PREMIER après la garde de sécurité

Si l'humain demande de "ranger/balayer/nettoyer la forge" :
- Lire et exécuter intégralement : `phases/p0-project.md`
- STOP — ne pas continuer vers la détection d'état.

---

## Détection d'état — exécuter dans l'ordre, s'arrêter au premier match

### État 0 — Project Init
**Condition :** PROJECT absent

Lire et exécuter intégralement : `phases/p0-project.md`
STOP — ne pas lire les états suivants.

---

### État 1 — Bootstrap
**Condition :** BRIEF absent

Lire et exécuter intégralement : `phases/bootstrap.md`
STOP — ne pas lire les états suivants.

---

### État 2 — Plan
**Condition :** BRIEF présent, PLAN absent

Lire et exécuter intégralement : `phases/plan.md`
STOP — ne pas lire les états suivants.

---

### État 3 — Actif
**Condition :** BRIEF présent ET PLAN présent

Lire et exécuter intégralement : `phases/resume.md`