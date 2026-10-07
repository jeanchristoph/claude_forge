# Pourquoi un script shell (bash) pour la livraison forge

*2026-10-07*

## Contexte

Le skill forge est un skill Claude Code composé uniquement d'instructions Markdown. Aujourd'hui, la séquence de livraison (`grave` / `engrave` / `ship`) est décrite en prose dans `skills/forge/phases/p5-resume.md` :

1. `git add`, `git commit`, `git push` sur la branche de départ ;
2. pour chaque branche citée : `checkout`, `merge` de la branche de départ, `push` ;
3. retour sur la branche de départ ;
4. tableau récapitulatif ;
5. branches ignorées : branche absente, branche égale à la branche de départ, branche extraite dans un autre worktree ;
6. arrêt sur conflit ou sur push rejeté.

À chaque livraison, Claude réinterprète ce texte et tape les commandes git une par une.

## 1. Le besoin : un programme, pas une procédure en prose

- **Déterminisme** : une prose relue à chaque fois produit des variations — ordre des commandes, gestion des cas limites, forme du tableau, qui diverge dès 3 ou 4 branches.
- **Testabilité** : une procédure en prose ne se teste pas ; un programme si.
- **Reproductibilité** : même entrée → mêmes commandes, toujours.

## 2. Pourquoi un langage est nécessaire

Les règles de saut, d'arrêt et le format du récapitulatif sont de la logique conditionnelle et itérative (boucle sur N branches, tests d'existence, détection de worktree, codes de retour git). Cette logique doit vivre dans du code exécutable, versionné et couvert par des tests, et non dans l'interprétation du modèle. Claude n'a plus qu'à appeler le script et relayer sa sortie.

## 3. Comparatif bash / PowerShell / Node

| Critère | bash | PowerShell | Node |
|---|---|---|---|
| Disponibilité | Partout où tourne Claude Code (Git Bash sous Windows) | 5.1 : Windows uniquement par défaut ; `pwsh` à installer sous Unix | Disponible (déjà utilisé par les installeurs) |
| Déjà requis par le skill | Oui (`bash -c "git branch --show-current"`) | Non | Non pour l'exécution du skill |
| Enchaînement de commandes git | Natif, concis | Correct, mais pièges sur stderr des exécutables natifs en 5.1 | Verbeux (`child_process`, gestion des sorties) |
| Tests sur dépôts temporaires | Simple (`mktemp`, `git init --bare`) | Possible | Possible, plus de code |

## 4. Décision retenue

**bash seul** :

- **une source de vérité** : `skills/forge/scripts/forge-ship.sh` ;
- **deux modes** : `preview` (affiche le tableau figé, en-têtes en anglais `| # | Action | Detail |`) et `run` (exécute la séquence) ;
- **nombre variable de branches cibles** passées en arguments positionnels ;
- **une suite de tests** : `tests/forge-ship.test.sh`, sur des dépôts temporaires avec un remote bare.

Pas de double implémentation bash + PowerShell : elle doublerait la maintenance et les tests pour un gain nul, bash étant déjà un prérequis.

## 5. Exemple d'appel

```bash
forge-ship.sh preview --branch ship --message "…" dev master
forge-ship.sh run --branch ship --message "…" dev master
```
