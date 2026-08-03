# Claude_forge

Conventions de formulation pour les fichiers d'instructions du skill (`skill/SKILL.md`, `skill/phases/*.md`). Norme continue, jamais un audit ponctuel.

## Formulation des instructions

- Infinitif impératif uniquement : Lire, Écrire, Générer, Vérifier, Afficher, Poser, Croiser, Décomposer. Jamais de futur, de conditionnel de politesse, ni de sujet autre que Claude sous-entendu.
- Zéro remplissage : pas de justification, pas de reformulation, pas de phrase de transition. Une instruction = une action.
- Étapes séquentielles → liste numérotée sous un en-tête `## Actions — dans l'ordre` / `## Étapes — dans l'ordre`. Jamais de prose narrative pour décrire une séquence.
- Conditions/critères de déclenchement → liste à puces, jamais numérotée (une puce = un critère indépendant, pas une étape).
- Logique conditionnelle → `Si <condition> → <conséquence>`. La flèche `→` remplace systématiquement « donc », « alors », « dans ce cas ».
- Décision binaire → les deux issues toujours explicites, jamais une seule sous-entendue : `Sur confirmation → ...` / `Sur refus → ...`, ou `Silencieuse (automatique)` / `Substantielle (confirmation obligatoire)`.
- Clause de garde en tête de fichier/section, sous `## Garde` : condition de sortie précoce vérifiée avant toute autre action, court-circuite le reste si remplie.
- Label structurant en tête de paragraphe, gras + deux-points, un seul par paragraphe : `**Condition :**`, `**Déclencheur :**`, `**Réaction — dans l'ordre :**`, `**INVARIANT :**`.
- Titre de section au format `Nom — qualificatif` (tiret cadratin) quand une précision d'ordre ou de nature est nécessaire : « Actions — dans l'ordre », « Réaction — dans l'ordre ». Si l'ordre d'exécution entre sections compte, le dire en majuscules dans le titre : « exécuter EN PREMIER ».
- Règle absolue/invariant → énoncée une seule fois dans tout le skill, en gras ; jamais reformulée ni dupliquée ailleurs (renvoyer vers elle, ne pas la réécrire).
- Fin de séquence toujours explicite : `STOP — ne pas continuer` (halte dure) ou renvoi littéral « Revenir à la section « Détection d'état » de `SKILL.md` pour enchaîner sur l'état suivant. » (halte molle). Jamais de fin implicite.
- Réplique que Claude doit prononcer à l'exécution → citée verbatim en anglais, en blockquote `>` ou entre guillemets, formulée en question fermée si une confirmation est attendue. Une réplique = une ligne.
- Placeholder à substituer par une valeur d'exécution (branche, chemin réel) → chevrons `<BRANCH>`. Placeholder à remplir dans un gabarit de sortie → crochets `[Titre]`, `[1 phrase]`. Ne jamais mélanger les deux conventions dans le même fichier.
- Libellé de structure d'un fichier produit (titre de section, nom de champ, en-tête de colonne) → toujours en anglais, figé littéralement dans l'instruction : `## Objective`, `## Scope & rules`, `## Tasks`, `**Effort:**`. Seul le contenu rédigé suit la langue de l'utilisateur. Un libellé traduit rend instable toute relecture programmatique (migration, hook, `grep`) d'un projet à l'autre.
- Chemin, identifiant, variable → toujours en inline code, jamais en texte nu.
- Piège connu ou contrainte à ne pas violer → préfixe `⚠️` seul en tête de ligne, jamais noyé dans un paragraphe.
- Terme du domaine du skill (Brief, Plan, État, Scope & rules, Hors périmètre, Historisation) → toujours le même mot une fois introduit, jamais de synonyme.
