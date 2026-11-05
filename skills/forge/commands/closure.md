# Clôture

## Clôture de tâche — rapport & réponse client

**Réaction — dans l'ordre :**

1. **Confirmer** que le problème initial est bien résolu : rappeler en une ligne l'objectif tel que décrit dans `## Objective` du brief, puis poser le choix avec `AskUserQuestion` — `header` : `Closure`, options `Solved` / `Not yet`.
   `Not yet` → demander ce qui reste, et STOP. Aucune suite sans `Solved`.

2. **Rapport ClickUp — sur `Solved`, uniquement si `.forge/clickup.json` est présent.** Fichier absent → étape entièrement silencieuse, aucun rapport généré, jamais mentionnée : passer à l'étape 3.
   - Lire `branch_code` dans `.forge/clickup.json` : `<BRANCH>` est le code de la tâche ClickUp, `custom_id` ou `id` selon ce champ.
   - Vérifier la tâche par `clickup_get_task` avant tout envoi. Introuvable → le signaler, demander l'identifiant, ne jamais deviner. Sans réponse : passer à l'étape 3.
   - Générer le rapport : texte brut structuré, concis, logique, schématique — labels courts (ex: PROBLÈME / SOLUTION / IMPACT). **Exclure** : détails d'itérations, mentions de branche, de tests, de fichiers modifiés. Rédiger intégralement dans la langue de l'utilisateur, labels compris — seul contenu produit exempté des libellés de structure figés en anglais.
   - Écrire le rapport dans OUTPUT sous `AAAAMMJJ-clickup-report.txt` — contenu généré (section « Contenu généré » de `SKILL.md`) : aucune confirmation avant l'écriture, une ligne dans LOG. Même jour, autre rapport → `-2`, `-3`…
   - Présenter le rapport, poser le choix avec `AskUserQuestion` — `header` : `ClickUp`, options `Post the comment` / `Cancel`, la tâche visée nommée dans la question — motif « Validation d'un contenu » de `SKILL.md` : le changement demandé arrive en texte libre, régénérer, réécrire le fichier sur place, reposer la question.
   - **Sur `Post the comment`** → `clickup_create_task_comment` sur cette tâche, contenu du fichier transmis tel quel — jamais reformulé, jamais reformaté. Rendre compte en une ligne.
   - **Sur `Cancel`** → n'envoyer rien, fichier laissé en place, passer à l'étape 3 sans commentaire.

   ⚠️ Action sortante : aucun envoi sans accord explicite. Le silence n'est pas un accord.
   ⚠️ Aucun fichier d'état `report.txt` : le rapport n'existe que dans OUTPUT.

3. **Réponse client** — poser le choix avec `AskUserQuestion` — `header` : `Email`, options `Draft a reply` / `Finish`.
   - `Draft a reply` → attendre que l'utilisateur colle le mail auquel répondre, générer la réponse d'une équipe support technique à partir du mail reçu et des éléments de réponse de la tâche, rédigée dans la langue du mail reçu — jamais celle de l'utilisateur si elle diffère.
   - **Ton :** court, fluide, professionnel, direct et naturel. Empathique, sans être trop chaleureux. Orienté vers la résolution du problème.
   - **Ne pas répéter le client :** ni redire ce qu'il vient d'écrire, ni reformuler toute sa demande quand ce n'est pas nécessaire.
   - **Pas de surcharge :** aucune explication technique inutile, aucune phrase trop longue, aucune tournure administrative lourde.
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
