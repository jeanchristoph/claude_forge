# Génération du plan

## Étapes — dans l'ordre

1. Lire `@.claude/project.md`
2. Lire `@.claude/branch/<BRANCH>/brief.md`
3. Reformuler l'objectif en 1 phrase pour confirmer la lecture.
4. Si plusieurs approches architecturales viables, les présenter :
   ```
   I have [N] possible approaches:
   **Option A — [Name]** : [1-2 sentences] | + ... | - ...
   **Option B — [Name]** : [1-2 sentences] | + ... | - ...
   Which one do we go with?
   ```
   Attendre le choix avant de continuer.
5. Générer le plan (format ci-dessous) et le présenter.
6. Itérer si ajustements demandés.
7. Écrire `.claude/branch/<BRANCH>/plan.md` après validation.
8. Demander : "Plan is set. Ready to start?" — attendre confirmation.
9. Si `project.md` contient uniquement `<!-- pending -->` → le compléter (stack, périmètre, conventions du plan).
10. Enchaîner sur `phases/resume.md`.

---

## Format du plan

```markdown
# Plan — <BRANCH>
**Objectif :** [1 phrase tirée du brief]
**Date :** [date du jour]

## Tâches

### T1 — [Titre court et précis]
**Effort :** XS/S/M/L/XL
**Fichiers :** `chemin/vers/fichier`
**Description :** [Ce qui doit être fait, comment, avec quels patterns]
[ ]

## Risques
- [Point d'attention si applicable, sinon omettre]

## Récapitulatif
| Tâche | Effort | Statut |
|---|---|---|
| T1 — ... | S | [ ] |
| **Total estimé** | **[somme]** | |
```

**Effort :** XS <30min · S 30min-2h · M 2-4h · L 4h-1j · XL >1j → découper
