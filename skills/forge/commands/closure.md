# Clôture

## Clôture de tâche — rapport & réponse client

**Réaction — dans l'ordre :**

1. **Confirmer** que le problème initial est bien résolu : rappeler en une ligne l'objectif tel que décrit dans `## Objective` du brief, lister les tâches `[ ]` de PLAN, puis poser le choix avec `AskUserQuestion` — `header` : `Closure`, options `Solved` / `Not yet`, ces tâches recopiées dans la question.
   `Not yet` → demander ce qui reste, et STOP. Aucune suite sans `Solved`.

2. **Tâches ouvertes — sur `Solved`, uniquement si PLAN contient au moins une tâche `[ ]`.** Aucune tâche `[ ]` → étape entièrement silencieuse : passer à l'étape 3.
   - Poser le choix avec `AskUserQuestion` — `header` : `Tasks`, les tâches `[ ]` recopiées dans la question, trois options :
     - `Mark done` → "The work is done, the plan was out of date."
     - `Drop` → "Abandoned, will never be resumed."
     - `Keep open` → "Left as is, still resumable."
   - Traitement différent par tâche → reçu en texte libre, appliqué tâche par tâche.
   - `Mark done` → ligne de statut `[x]`. `Drop` → ligne de statut `[-] dropped`. `Keep open` → aucun changement.
   - Reporter chaque statut changé dans `## Summary` de PLAN, écrire une entrée dans LOG.

   ⚠️ `Solved` ne vaut jamais `[x]` : le problème résolu ne prouve pas que chaque tâche a été faite.
   ⚠️ Tâche `[!]` → jamais modifiée par cette étape.
   ⚠️ Sans réponse → STOP.

3. **Rapport ClickUp — sur `Solved`, uniquement si la branche a une tâche ClickUp ouverte.** Première condition remplie, dans cet ordre :
   - `.forge/branch/<BRANCH>/ticket.json` présent et `tracker` vaut `clickup` → tâche visée = son `code`. `clickup_get_task` introuvable → le signaler en une ligne, passer à l'étape 4.
   - `ticket.json` absent et `.forge/clickup.json` présent → branche ouverte avant le marqueur : tâche visée = `<BRANCH>`. `clickup_get_task` introuvable → étape silencieuse, passer à l'étape 4.
   - Sinon → étape entièrement silencieuse, aucun rapport généré, jamais mentionnée : passer à l'étape 4.

   Autre erreur de `clickup_get_task` → afficher l'erreur telle quelle, passer à l'étape 4. Tâche trouvée → suite de l'étape :
   - Générer le rapport : texte brut structuré, concis, logique, schématique — labels courts (ex: PROBLÈME / SOLUTION / IMPACT). **Exclure** : détails d'itérations, mentions de branche, de tests, de fichiers modifiés. Rédiger intégralement dans la langue de l'utilisateur, labels compris — seul contenu produit exempté des libellés de structure figés en anglais.
   - Écrire le rapport dans OUTPUT sous `AAAAMMJJ-clickup-report.txt` — contenu généré (section « Contenu généré » de `SKILL.md`) : aucune confirmation avant l'écriture, une ligne dans LOG. Même jour, autre rapport → `-2`, `-3`…
   - Présenter le rapport, poser le choix avec `AskUserQuestion` — `header` : `ClickUp`, options `Post the comment` / `Cancel`, la tâche visée nommée dans la question avec son `url` — motif « Validation d'un contenu » de `SKILL.md` : le changement demandé arrive en texte libre, régénérer, réécrire le fichier sur place, reposer la question.
   - **Sur `Post the comment`** → `clickup_create_task_comment` sur cette tâche, contenu du fichier transmis tel quel — jamais reformulé, jamais reformaté. Rendre compte en une ligne, `url` de la tâche comprise.
   - **Sur `Cancel`** → n'envoyer rien, fichier laissé en place, passer à l'étape 4 sans commentaire.

   ⚠️ Action sortante : aucun envoi sans accord explicite. Le silence n'est pas un accord.
   ⚠️ La clôture ne crée jamais de tâche ClickUp, ne propose jamais d'en créer une, ne demande jamais d'identifiant.
   ⚠️ Aucun fichier d'état `report.txt` : le rapport n'existe que dans OUTPUT.

4. **Réponse client** — poser le choix avec `AskUserQuestion` — `header` : `Email`, options `Draft a reply` / `Finish`.
   - `Draft a reply` → attendre que l'utilisateur colle le mail auquel répondre, générer la réponse d'une équipe support technique à partir du mail reçu et des éléments de réponse de la tâche, rédigée dans la langue du mail reçu — jamais celle de l'utilisateur si elle diffère.
   - **Ton :** court, fluide, professionnel, direct et naturel. Empathique, sans être trop chaleureux. Orienté vers la résolution du problème.
   - **Ne pas répéter le client :** ni redire ce qu'il vient d'écrire, ni reformuler toute sa demande quand ce n'est pas nécessaire.
   - **Pas de surcharge :** aucune explication technique inutile, aucune phrase trop longue, aucune tournure administrative lourde.
   - **Correctif annoncé comme fait :** au passé composé, sujet « nous » (« nous avons apporté une correction
     qui… »), décrit par ce que l'utilisateur verra dans son parcours — jamais par un blocage, une interdiction
     ni un nom de page, de fichier ou de variable.
   - **Un paragraphe tient sur une seule ligne.** Jamais de retour à la ligne forcé à l'intérieur d'un paragraphe :
     le client de messagerie gère le rendu, un repli à la main coupe les phrases n'importe où, souvent juste avant
     un point. Les retours à la ligne ne séparent que les paragraphes et les éléments d'une liste.
   - **Aller à l'essentiel.** Ce qui figure dans une pièce jointe ou un document remis au client n'est pas reformulé
     dans le corps du mail : on l'y annonce en une phrase. Un mail de quelques paragraphes, pas une page.
   - **Fichier `.txt` systématique.** La réponse affichée est aussi écrite dans OUTPUT sous `AAAAMMJJ-client-reply.txt`
     — copie exacte du brouillon, texte brut sans mise en forme Markdown, un paragraphe par ligne. Même jour, autre
     réponse → `-2`, `-3`… Contenu généré (section « Contenu généré » de `SKILL.md`) : aucune confirmation avant
     l'écriture, une ligne dans LOG. Le fichier sert tel quel, quel que soit l'outil qui a relayé le mail — ticket
     ClickUp, Jira ou tout autre.
   - `Finish` → terminer.
