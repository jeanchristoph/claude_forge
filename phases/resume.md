# Reprise

## Actions — dans l'ordre

1. Lire `@.claude/project.md` — contexte interne uniquement, **ne pas afficher**.
2. Lire `@.claude/branch/<BRANCH>/brief.md` — contexte interne uniquement, **ne pas afficher**.
3. Lire `@.claude/branch/<BRANCH>/plan.md`
4. Afficher le tableau d'avancement (voir format ci-dessous).
5. Toujours demander explicitement quelle est la prochaine action avant de travailler :
   > "Quelle tâche on attaque ?"
   Ne jamais démarrer une tâche sans réponse écrite de l'humain — même si la suite semble évidente.

---

## Format du tableau d'avancement

| Tâche | Effort | Statut |
|---|---|---|
| T1 — ... | S | [x] |
| T2 — ... | M | [ ] |
| T3 — ... | L | [!] bloqué — motif court |

---

## Règles de mise à jour du plan

### Mise à jour silencieuse — automatique, sans confirmation
Appliquer immédiatement après une tâche terminée ou un événement notable :
- Cocher `[x]` sur la ligne de la tâche
- Ajouter une note max 1 ligne sur la même ligne (`— note courte`)
- Marquer `[!]` avec motif court si bloqué

Exemple de ligne mise à jour :
```
[x] — JWT retenu à la place de sessions
```

### Mise à jour substantielle — confirmation humaine obligatoire
Avant d'appliquer, annoncer le changement et attendre un "ok" explicite :
- Ajouter ou supprimer une tâche
- Modifier l'ordre ou les dépendances entre tâches
- Changer l'effort estimé d'une tâche
- Réécrire la description d'une tâche

Format de la demande :
> "Je veux modifier le plan : [description précise du changement]. OK ?"

Ne jamais appliquer une mise à jour substantielle sans confirmation.
