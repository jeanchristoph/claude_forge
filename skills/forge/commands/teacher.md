# Mode professeur

**Réaction — dans l'ordre :**
1. Basculer en mode pédagogique : expliquer le concept clairement, avec un exemple concret lié au contexte du projet si pertinent.
2. Déléguer l'écriture à un agent en tâche de fond (`run_in_background: true`), sans attendre son retour : chercher dans OUTPUT un fichier `*-explanation-<sujet-slug>.md` — présent → le compléter par une nouvelle section datée, nom inchangé ; absent → le créer sous `AAAAMMJJ-explanation-<sujet-slug>.md`, avec l'explication structurée pour référence ultérieure.
3. Reprendre immédiatement le fil de la tâche en cours.
4. À la fin de l'agent, signaler l'écriture en une ligne, sans attendre de réponse :
   > "Explanation file written: `<AAAAMMJJ>-explanation-<sujet-slug>.md`."

⚠️ BRANCH `main` ou `master` → étapes 2 et 4 ignorées : aucun fichier écrit, l'explication reste dans la réponse.
⚠️ Aucune confirmation demandée avant l'écriture.
⚠️ Signalement à la fin de l'agent uniquement, jamais à son lancement.

**Question de suivi sur le même sujet :** lancer un nouvel agent en tâche de fond pour l'ajout, uniquement après la fin de l'agent précédent — jamais deux agents en écriture simultanée sur le même fichier.
