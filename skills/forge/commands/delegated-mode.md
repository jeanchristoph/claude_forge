# Mode délégué

**INVARIANT :** rien du parent n'entre — ni `project.md`, ni standards, ni plan, ni log ; rien d'autre qu'un bloc `FORGE_QUESTION` ou `FORGE_DONE` ne sort.

**Règles communes :**
- ROOT = valeur de la ligne `ROOT:` du prompt. Aucune écriture, aucune commande git hors de ROOT.
- Langue de l'utilisateur = valeur de la ligne `LANGUAGE:` du prompt — le prompt lui-même n'en est pas un indice.
- Point bloquant (confirmation, choix fermé, question ouverte) → terminer le tour par un bloc `FORGE_QUESTION` (format ci-dessous), puis attendre. La réponse arrive dans un message `FORGE_ANSWER: <réponse>` — la traiter comme la réponse de l'utilisateur.
- **Contenu entier dans la question :** démarrage d'une tâche ou validation d'un contenu présenté (description de la tâche, plan, objectif du brief, entrée `## Scope & rules`, rapport, tableau récapitulatif) → le champ `content:` du bloc recopie ce contenu **intégralement** — jamais un résumé, jamais un intitulé seul : le parent ne peut pas trancher sans le voir. Rien à trancher → `content: none`.
- Clôture de tâche non applicable : la séquence se termine par `FORGE_DONE` (format ci-dessous). Toutes les tâches du plan traitées (`[x]` ou `[!]`) → terminer le tour par ce bloc. STOP — ne pas continuer.

**`SCOPE: linked` — projet lié :**
- BRIEF porte `## Origin` : le mandat du parent, marqueur lu par les phases.
- BRANCH = valeur de la ligne `BRANCH:` du prompt, de la forme `<parent>/<branche parente>` (`forge/linked-project`, `forge/CU-123`) : le préfixe nomme le dossier du parent, la partie droite est sa branche telle quelle. Tous les chemins `.forge/branch/<BRANCH>/` la contiennent telle quelle, slash compris — jamais le nom nu de la branche parente.
- Plan validé → enchaîner toutes les tâches ouvertes dans l'ordre, sans question de mode : la validation du plan vaut accord.
- Livraison non applicable : la livraison du projet lié est proposée au parent lors de son propre « grave ».
- `FORGE_DONE` : `done` / `blocked` tracés `← parent T<n>`, `out_of_mandate` renseigné.

**`SCOPE: branch` — branche du même dépôt :**
- Pas de `## Origin`, pas de mandat : `project.md`, standards, brief, log et plan sont lus comme les phases le prescrivent.
- **Chaque choix est relayé à l'utilisateur** par `FORGE_QUESTION` — objectif du brief, validation du plan, mode (enchaîner / choisir), feu vert avant chaque tâche. Le raccourci « plan validé vaut accord » ne s'applique pas, sauf choix explicite de `Validate and chain` à la validation du plan.
- Livraison applicable, sous ROOT (le worktree), sans confirmation : compte rendu de livraison dans `content`.
- `FORGE_DONE` : `done` / `blocked` sans `← parent`, `out_of_mandate: none`, compte rendu d'une ligne.

**`SWARM:` présent — branche fille d'un essaim** (`commands/swarm.md`), en plus des règles `SCOPE: branch` :
- Livraison non applicable : le parent commite et fusionne la branche (« Fusion d'une branche fille »). `FORGE_DONE` laisse le travail non commité dans ROOT.
- Jamais de fusion de la branche parente dans la branche : le parent seul fusionne.
- Fichiers temporaires dans le dossier de la ligne `SCRATCHPAD:` seulement, jamais à la racine du dossier temporaire.
- Application, serveur ou service local lancé → port de la ligne `PORT:`, adresse `127.0.0.1` ; `PORT: none` → rien n'est lancé. Nouvelle dépendance installée dans ROOT seulement, manifeste et fichier de verrouillage gardés dans la branche.
- Avant chaque tâche : entrée LOG `- [AAAA-MM-JJ HH:MM] task <n> started`.
- `RESUME:` autre que `none` → appliquer la consigne de reprise avant toute autre action ; plan validé avec enchaînement → aucune question `Mode`.
- Tâche du plan qui remplit la « Règle de branche » de `phases/p4-plan.md` en cours de réalisation → `FORGE_QUESTION` `header` `Promotion` : "T<n> deserves its own branch: move it out of this plan and add it to the parent plan?", options `Promote` / `Keep it here` ; sur `Promote`, la tâche est retirée du plan, sa description recopiée entière dans `content`.
- Toute `FORGE_QUESTION` de choix apporte le contexte de décision : ce que fait l'existant, ce que chaque option change pour l'utilisateur final, ce qu'il faudrait refaire si le choix s'avère mauvais.

### Format `FORGE_QUESTION`

```
FORGE_QUESTION
header: [header]
question: [question]
content:
[contenu entier à trancher, sur autant de lignes que nécessaire — ou `none`]
options:
- [label] — [description]
```

Question ouverte → `options: none`.

### Format `FORGE_DONE`

```
FORGE_DONE
done:
- T1 ← parent T3 — [note]
blocked:
- T2 ← parent T5 — [raison]
out_of_mandate:
- [besoin hors mandat, une ligne]
files:
- `chemin/relatif/sous/ROOT`
```

Liste vide → `none`. `SCOPE: branch` → `- T1 — [note]`, sans `← parent`.
