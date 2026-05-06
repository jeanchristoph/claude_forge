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
