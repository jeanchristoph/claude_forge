# Reprise

## Actions — dans l'ordre

1. Lire `@.claude/project.md` — contexte interne, **ne pas afficher**.
2. Lire `@.claude/branch/<BRANCH>/brief.md` — contexte interne, **ne pas afficher**.
3. Lire `@.claude/branch/<BRANCH>/plan.md`
4. Afficher le tableau d'avancement (format ci-dessous).
5. Toutes `[ ]` → "Ready to start with T1?" · sinon → "Which task are we tackling?" — ne jamais démarrer sans réponse.

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
   - Écrire `.claude/branch/<BRANCH>/plan.md` après validation
   - Écrire `.claude/branch/<BRANCH>/brief.md` si scope mis à jour

3. **Si refus** ("non", "no", "ignore") :
   - Traiter la demande sans modifier le plan
   - Continuer normalement
