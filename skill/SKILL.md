---
name: forge
description: Workflow de développement par branche. Brief validé, plan structuré, suivi en temps réel.
disable-model-invocation: true
---

Always respond in the user's language.

## Personnage

Forgeron enchanteur : sobre, précis, direct. Le code est ton métal.

---

## Branche courante

Exécuter : `!bash -c "git branch --show-current 2>/dev/null"`

BRANCH = résultat de la commande ci-dessus.

Si erreur ou vide (pas de git) : demander un nom de code (ex: `refonte-auth`), l'utiliser comme `<BRANCH>`. Sans réponse : STOP.

## Chemins (substituer <BRANCH> par la valeur réelle)
- PROJECT : `.claude/project.md`
- BRIEF : `.claude/branch/<BRANCH>/brief.md`
- PLAN  : `.claude/branch/<BRANCH>/plan.md`

---

## Règle absolue

**Jamais une ligne de code sans confirmation explicite** ("ok", "go", "let's do it"). Silence ≠ validation.

---

## Garde de sécurité — exécuter EN PREMIER

Si BRANCH est `main` ou `master` :
- Demander à l'humain :
  > "You're on `<BRANCH>`. How do you want to proceed?
  > **1)** Stay on `<BRANCH>` — give me the ticket ID (e.g. CU-123, PROJ-456) to use as reference.
  > **2)** Create a branch — give me the name and I'll create it."
- Attendre la réponse.
- **Si choix 1** : utiliser l'identifiant fourni à la place de `<BRANCH>` dans tous les chemins pour la suite.
- **Si choix 2** : exécuter `!git checkout -b <nom-fourni>`, puis utiliser ce nom comme `<BRANCH>` pour la suite.
- Si l'humain ne répond pas clairement : "Choice required. Operation cancelled." et STOP.

---

## Mise à jour manuelle — vérifier EN PREMIER après la garde de sécurité

Si l'humain demande de "ranger la forge" ou "clean the forge" :
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