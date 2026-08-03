# Génération du plan

## Étapes — dans l'ordre

1. Lire `@.forge/project.md`
2. Lire `.forge/coding_standards.md`
3. Lire `@.forge/branch/<BRANCH>/brief.md`
4. Reformuler l'objectif en 1 phrase pour confirmer la lecture.
5. Si plusieurs approches architecturales viables, les présenter :
   ```
   I have [N] possible approaches:
   **Option A — [Name]** : [1-2 sentences] | + ... | - ...
   **Option B — [Name]** : [1-2 sentences] | + ... | - ...
   Which one do we go with?
   ```
   Attendre le choix avant de continuer.
6. Générer le plan (format ci-dessous) et le présenter.
7. Itérer si ajustements demandés.
8. Écrire `.forge/branch/<BRANCH>/plan.md` après validation.
9. Si `project.md` contient uniquement `<!-- pending -->` → le compléter (stack, périmètre, conventions du plan).
10. Continuer directement à l'État 5 : lire et exécuter `phases/p5-resume.md`.

---

## Format du plan

⚠️ Titres de sections et libellés de champs écrits tels quels ci-dessous, en anglais, quelle que soit la langue de l'utilisateur — seul le contenu entre crochets suit sa langue.

```markdown
# Plan — <BRANCH>
**Objective:** [1 phrase tirée du brief]
**Date:** [date du jour]

## Tasks

### T1 — [Titre court et précis]
**Effort:** XS/S/M/L/XL
**Files:** `chemin/vers/fichier`
**Description:** [Ce qui doit être fait, comment, avec quels patterns]
[ ]

<!-- Tâche L ou XL : décomposer en micro-étapes avant de démarrer
[ ] T1.1 — ...
[ ] T1.2 — ...
-->

## Risks
- [Point d'attention si applicable, sinon omettre]

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — ... | S | [ ] |
| **Total** | **[somme]** | |
```

**Effort :** XS <30min · S 30min-2h · M 2-4h · L 4h-1j · XL >1j → découper
