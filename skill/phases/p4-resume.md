# Reprise

## Actions — dans l'ordre

1. Lire `@.forge/project.md` — contexte interne, **ne pas afficher**.
2. Lire `.forge/coding_standards.md` — contexte interne, **ne pas afficher**.
3. Lire `@.forge/branch/<BRANCH>/brief.md` — contexte interne, **ne pas afficher**.
   - Si `## Décisions & Contraintes` contient des entrées → afficher un résumé en tête : "**Last session :** [points clés]"
4. Lire `@.forge/branch/<BRANCH>/plan.md`
5. Afficher le tableau d'avancement (format ci-dessous).
6. Toutes `[ ]` → "Ready to start with T1?" · sinon → "Which task are we tackling?" — ne jamais démarrer sans réponse.

---

## Format du tableau d'avancement

| Tâche | Effort | Statut |
|---|---|---|
| T1 — ... | S | [x] |
| T2 — ... | M | [ ] |
| T3 — ... | L | [!] blocked — brief reason |

---

## Règles de mise à jour du plan

**Silencieuse (automatique)** — après tâche terminée ou événement notable :
- Cocher `[x]`, ajouter note max 1 ligne, marquer `[!]` si bloqué.

**Substantielle (confirmation obligatoire)** — annoncer et attendre "ok" avant d'appliquer :
- Ajouter/supprimer une tâche
- Modifier l'ordre ou les dépendances
- Changer l'effort estimé
- Réécrire la description

> "I want to update the plan: [description]. OK?"

**Tâche L/XL** — avant de démarrer, décomposer en micro-étapes et écrire `plan.md` :
`[ ] T2.1 — ...` · `[ ] T2.2 — ...`

---

## Mise à jour du brief

Le brief est vivant. Les changements de scope sont gérés par la **Surveillance** ci-dessous.

Écrire silencieusement sous `## Décisions & Contraintes` (format : `- [date] [1 ligne]`) :
- Remarque ou contrainte utilisateur précisant le périmètre
- Contrainte technique découverte en cours de tâche
- Choix d'implémentation mineur acté sans discussion
- **Choix utilisateur quand Claude a proposé plusieurs options** (ex: "Option B retenue — raison")

---

## Historisation

**Seuils :** brief.md 30 000 car · plan.md 60 000 car. Vérifier après chaque écriture réelle.

**Si dépassé** → proposer, confirmation obligatoire :
> "`<fichier>` dépasse <N> caractères. Historiser vers `<fichier>_AAAAMMJJ.md` ? OK ?"

**Sur confirmation** → déléguer à un agent en tâche de fond (`run_in_background: true`) : lecture, tri, écriture (archive + fichier allégé), sans bloquer le développement en cours.

**plan.md** — par tâche `[x]` sans sous-élément `[ ]`/`[~]`/`[!]` :
- Déplacer intégralement (Fichiers à créer, Description, corrections, checklist, ligne du tableau) — rien ne reste.
- Sous-élément non coché → ne jamais archiver.
- Règle absolue, dépendances, risques majeurs → toujours dans plan.md.

**brief.md** — sous `## Décisions & Contraintes` :
- Contraintes (constantes dans le temps, toujours valables) → jamais archivées, quel que soit leur âge.
- Décisions (choix ponctuels, actés et clos) → garder les 10 plus récentes, déplacer les plus anciennes.
- Déplacement verbatim — aucune reformulation.
- Doute sur la nature d'une entrée → garder dans brief.md.

**Nommage :** `plan_AAAAMMJJ.md` / `brief_AAAAMMJJ.md`, même dossier. Fichier du jour existant → compléter, jamais dupliquer. Toujours au-dessus du seuil après → archiver l'entrée suivante par ancienneté.

---

## Choix d'infrastructure → propagation vers CLAUDE.md global

**Déclencheur :**
- Un choix d'infrastructure se pose (techno, lib, pattern, service)
- L'utilisateur revient sur un choix fait instinctivement par Claude (le corrige, l'invalide)

**Réaction — dans l'ordre :**
1. Logger le choix retenu sous `## Décisions & Contraintes` (règle ci-dessus).
2. Si le choix dépasse le périmètre de cette branche (règle générale, pas spécifique au ticket) → en tirer une règle concise et programmatique, puis proposer :
   > "This choice looks reusable beyond this branch. Add as a rule to global CLAUDE.md? → [règle proposée]"
3. **Sur confirmation** → ajouter la règle à `~/.claude/CLAUDE.md` (section existante pertinente ou nouvelle section courte). Jamais d'écriture sans validation explicite.
4. **Sur refus** → rester local au brief, ne jamais reproposer plus tard pour la même décision.

---

## Surveillance des demandes complémentaires

**À chaque input utilisateur**, après l'exécution du skill (reprise ou nouveau projet), évaluer si la demande correspond à une tâche existante du plan ou non.

### Demande hors périmètre — détecter si :
- La demande concerne une fonctionnalité absente du plan
- Elle introduit un nouveau cas d'usage, un nouveau module, ou un nouveau comportement
- Elle modifie une contrainte technique ou fonctionnelle implicitement acceptée

### Réaction — dans l'ordre :

1. **Signaler** la détection clairement :
   > "This request isn't in the current plan. Want me to add it?"

2. **Si confirmation** ("ok", "yes", "oui") :
   - Appliquer la mise à jour **substantielle** du plan (tâche ajoutée, effort estimé, position dans la séquence)
   - Si la demande change significativement le scope global → proposer aussi de mettre à jour le brief :
     > "This also changes the project scope. Should I update the brief?"
   - Écrire `.forge/branch/<BRANCH>/plan.md` après validation
   - Écrire `.forge/branch/<BRANCH>/brief.md` si scope mis à jour

3. **Si refus** ("non", "no", "ignore") :
   - Traiter la demande sans modifier le plan
   - Continuer normalement

---

## Livraison — commit, push, merge

**Déclencheur :** l'utilisateur dit "grave <branche(s)>" / "engrave <branche(s)>" — une ou plusieurs branches existantes citées, dans l'ordre voulu (ex: "grave dev", "grave master", "grave dev master").

**Réaction — dans l'ordre :**
1. Générer automatiquement le message de commit (règles COMMITS GIT : max 150 car., pas de mention Claude) — pas de confirmation sur le message lui-même.
2. Annoncer la séquence prévue et demander confirmation explicite ("ok", "go") — jamais d'exécution sans validation :
   > "add + commit (\"<message>\") + push + merge en chaîne sur <branche(s) citées, dans l'ordre>. OK ?"
3. **Sur confirmation** → exécuter dans l'ordre : `git add`, `git commit`, `git push` sur `<BRANCH>`.
   - Puis, pour chaque branche citée, dans l'ordre : checkout de la branche, merge de la branche précédente dans la chaîne (`<BRANCH>` pour la première citée), push.
4. Revenir sur `<BRANCH>`. Rendre compte : hash de commit, branches mises à jour.

---

## Clôture de tâche — rapport & réponse client

**Déclencheur :**
- Toutes les tâches du plan sont `[x]` ET l'utilisateur a validé les tests, OU
- L'utilisateur emploie un terme de clôture ("terminé", "end", "pb résolu", ou équivalent)

**Réaction — dans l'ordre :**

1. **Confirmer** que le problème initial (tel que décrit dans `## Objectif` du brief) est bien résolu :
   > "Le problème initial est-il bien résolu ?"
   Ne pas continuer sans confirmation explicite.

2. **Sur confirmation :**
   - Générer le rapport interne (ou le mettre à jour si `rapport.txt` existe déjà pour cette branche) : texte brut structuré, concis, logique, schématique — labels courts (ex: PROBLÈME / SOLUTION / IMPACT). **Exclure** : détails d'itérations, mentions de branche, de tests, de fichiers modifiés.
   - Présenter le rapport, demander confirmation, puis écrire `.forge/branch/<BRANCH>/rapport.txt`.
   - Proposer ensuite : "Dois-je générer une réponse à un mail ?"
     - Si oui → attendre que l'utilisateur colle le mail auquel répondre, générer une réponse au ton fluide, professionnel et pédagogique.
     - Si non → terminer.
