# Reprise

## Actions — dans l'ordre

1. Lire `@.forge/project.md` — contexte interne, **ne pas afficher**.
2. Lire `.forge/coding_standards.md` — contexte interne, **ne pas afficher**.
3. Lire `@.forge/branch/<BRANCH>/brief.md` — contexte interne, **ne pas afficher**.
4. Lire les 40 premières lignes de `.forge/branch/<BRANCH>/log.md` (`Read` avec `limit: 40`), si présent — contexte interne, **ne pas afficher**.
   - Des entrées existent → retenir les 10 plus récentes parmi les lignes lues, afficher un résumé en tête : "**Last session :** [points clés]"
   - ⚠️ Jamais de lecture non bornée de `log.md` — la taille du fichier ne doit jamais peser sur le coût de la reprise.
5. Lire `@.forge/branch/<BRANCH>/plan.md`
6. Vérifier les seuils d'historisation (section « Historisation ») — unique contrôle de la session.
7. Afficher le tableau d'avancement (format ci-dessous).
8. Toutes `[ ]` → "Ready to start with T1?" · sinon → "Which task are we tackling?" — ne jamais démarrer sans réponse.

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

## Mise à jour du brief et du log

Le brief est vivant. Les changements de scope sont gérés par la **Surveillance** ci-dessous.

**Élément de cadre** (valable pour toute la durée de la branche) → écrire silencieusement dans la section `## Scope & rules` de `brief.md` :
- Contrainte technique découverte en cours de tâche
- Règle immuable posée par l'utilisateur
- Remarque utilisateur précisant durablement le périmètre ou le hors périmètre

**Décision ponctuelle** (choix acté et clos à un instant donné) → écrire silencieusement dans LOG (format : `- [date] [1 ligne]`) :
- Choix d'implémentation mineur acté sans discussion
- **Choix utilisateur quand Claude a proposé plusieurs options** (ex: "Option B retenue — raison")

⚠️ Entrée insérée en tête de `log.md`, juste sous le titre — jamais en fin de fichier. La lecture bornée de l'étape 4 suppose les entrées les plus récentes en haut.

---

## Historisation

**Seuils :** log.md 90 000 car · plan.md 20 000 car. Vérifier une seule fois par session, à la reprise (étape 6 des « Actions — dans l'ordre »).

⚠️ Aucune vérification déclenchée par une écriture en cours de session — le développement n'est jamais interrompu.
⚠️ `plan.md` injecté intégralement via `@` → son seuil gouverne le coût de reprise. `log.md` lu borné → son seuil ne gouverne que la lisibilité et le coût de l'agent d'archivage.

**Si dépassé** → proposer, confirmation obligatoire :
> "`<fichier>` dépasse <N> caractères. Historiser vers `<fichier>_AAAAMMJJ.md` ? OK ?"

**Sur confirmation** → déléguer à un agent en tâche de fond (`run_in_background: true`) : lecture, écriture, sans bloquer le développement en cours.

**plan.md** — historisation restreinte à la section `## Tasks` :
- Garder les 10 tâches `[x]` les plus récentes, déplacer les plus anciennes.
- Tâche portant un sous-élément `[ ]`/`[~]`/`[!]` → ne jamais archiver.
- `## Summary` et `## Risks` intactes — le tableau récapitulatif conserve toutes ses lignes, y compris celles des tâches archivées.
- Déplacement verbatim des tâches — aucune reformulation, aucun marqueur d'archive.

**log.md** :
- Garder les 10 entrées les plus récentes, déplacer les plus anciennes.
- Déplacement verbatim — aucune reformulation.

**Nommage :** `plan_AAAAMM.md` / `log_AAAAMM.md`, même dossier. Fichier du jour existant → compléter, jamais dupliquer. Toujours au-dessus du seuil après → archiver l'entrée suivante par ancienneté.

---

## Choix d'infrastructure → propagation vers CLAUDE.md global

**Déclencheur :**
- Un choix d'infrastructure se pose (techno, lib, pattern, service)
- L'utilisateur revient sur un choix fait instinctivement par Claude (le corrige, l'invalide)

**Réaction — dans l'ordre :**
1. Logger le choix retenu dans LOG (règle ci-dessus).
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

**Déclencheur :** l'utilisateur dit "grave" / "engrave", seul ou suivi d'une ou plusieurs branches existantes, dans l'ordre voulu (ex: "grave", "grave dev", "grave dev master").

**INVARIANT :** git opère uniquement sur le dépôt courant — jamais sur un autre dépôt ouvert en parallèle.

⚠️ Aucune commande git — `git add` compris — avant la confirmation de l'étape 3.

**Réaction — dans l'ordre :**
1. Générer automatiquement le message de commit (règles COMMITS GIT : max 150 car., pas de mention Claude) — pas de confirmation sur le message lui-même.
2. Afficher le tableau récapitulatif des actions prévues (format ci-dessous).
3. Demander une confirmation unique, couvrant toute la séquence :
   > Run this sequence? OK?
4. **Sur refus** → n'exécuter aucune action. STOP — ne pas continuer.
5. **Sur confirmation** → exécuter la séquence entière sans validation intermédiaire, dans l'ordre : `git add`, `git commit`, `git push` sur `<BRANCH>`.
6. Aucune branche citée → passer directement à l'étape 8.
7. Pour chaque branche citée, dans l'ordre : branche citée égale à `<BRANCH>` → ignorer sans message ; sinon → checkout de la branche, merge de `<BRANCH>` (toujours la branche de départ, jamais la branche précédente de la chaîne), push.
8. Revenir sur `<BRANCH>`. Rendre compte : hash de commit, branches mises à jour.

### Format du tableau récapitulatif

Une ligne par action git prévue, dans l'ordre d'exécution. Trois colonnes, en-têtes générés dans la langue de l'utilisateur : numéro d'ordre, action git, détail.

Actions et détail associé — aucune autre :
- `add` → branche courante
- `commit` → message généré, entre guillemets
- `push` → remote et branche poussée
- `merge` → `<BRANCH>` → branche cible, une ligne par branche citée
- `checkout` → dernière ligne du tableau uniquement, retour sur `<BRANCH>` ; omise si aucune branche n'est citée

⚠️ Jamais de ligne `checkout` pour les changements de branche de l'étape 7 : ils restent implicites. Seul le retour final sur `<BRANCH>` est listé.
⚠️ Jamais de liste de fichiers modifiés, jamais de décompte de lignes.

---

## Clôture de tâche — rapport & réponse client

**Déclencheur :**
- Toutes les tâches du plan sont `[x]` ET l'utilisateur a validé les tests, OU
- L'utilisateur emploie un terme de clôture ("terminé", "end", "pb résolu", ou équivalent)

**Réaction — dans l'ordre :**

1. **Confirmer** que le problème initial (tel que décrit dans `## Objective` du brief) est bien résolu :
   > "Le problème initial est-il bien résolu ?"
   Ne pas continuer sans confirmation explicite.

2. **Sur confirmation :**
   - Générer le rapport interne (ou le mettre à jour si `report.txt` existe déjà pour cette branche) : texte brut structuré, concis, logique, schématique — labels courts (ex: PROBLÈME / SOLUTION / IMPACT). **Exclure** : détails d'itérations, mentions de branche, de tests, de fichiers modifiés.
   - Rédiger intégralement dans la langue de l'utilisateur, labels compris — seul fichier produit exempté des libellés de structure figés en anglais.
   - Présenter le rapport, demander confirmation, puis écrire `.forge/branch/<BRANCH>/report.txt`.
   - Proposer ensuite : "Dois-je générer une réponse à un mail ?"
     - Si oui → attendre que l'utilisateur colle le mail auquel répondre, générer une réponse au ton fluide, professionnel et pédagogique, rédigée dans la langue du mail reçu — jamais celle de l'utilisateur si elle diffère.
     - Si non → terminer.
