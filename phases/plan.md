# Génération du plan

## Étapes — dans l'ordre

1. Lire `@.claude/project.md`
2. Lire `@.claude/branch/<BRANCH>/brief.md`
3. Confirmer la lecture en reformulant l'objectif en 1 phrase.
4. Analyser s'il existe plusieurs approches architecturales viables pour atteindre l'objectif.
   - Si **une seule approche** évidente : continuer directement.
   - Si **plusieurs approches** possibles : les présenter avant de forger le plan.
     Format de présentation :
     ```
     Avant de forger le plan, j'ai [N] approches possibles :

     **Option A — [Nom court]**
     [1-2 phrases] | Avantages : ... | Inconvénients : ...

     **Option B — [Nom court]**
     [1-2 phrases] | Avantages : ... | Inconvénients : ...

     Laquelle on choisit ?
     ```
     Attendre le choix de l'humain avant de continuer.
5. Générer `.claude/branch/<BRANCH>/plan.md` avec le format défini ci-dessous.
5. Présenter le plan à l'humain.
6. Itérer si ajustements demandés.
7. Écrire `.claude/branch/<BRANCH>/plan.md` après validation explicite.
8. Confirmer l'écriture du plan, puis demander explicitement :
   > "Le plan est gravé dans le métal. On allume le feu et on commence à forger ?"
   Attendre la confirmation de l'humain avant de continuer.
9. Lire et enchaîner sur `phases/resume.md` uniquement après confirmation.

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

### T2 — [Titre]
**Effort :** ...
**Fichiers :** `...`
**Description :** ...
[ ]

## Risques
- [Point d'attention si applicable, sinon omettre cette section]

## Récapitulatif
| Tâche | Effort | Statut |
|---|---|---|
| T1 — ... | S | [ ] |
| T2 — ... | M | [ ] |
| **Total estimé** | **[somme]** | |
```

---

## Échelle d'effort

| Taille | Durée estimée |
|---|---|
| XS | < 30 min |
| S | 30 min – 2h |
| M | 2h – 4h |
| L | 4h – 1 jour |
| XL | > 1 jour → envisager de découper |
