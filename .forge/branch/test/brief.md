# Brief — test

## Objectif

Renforcer la phase Livraison de la skill forge (`skill/phases/p5-resume.md`) : sur déclencheur « grave », préparer le commit sans lancer aucune commande git — `git add` compris — puis afficher un tableau récapitulatif des actions prévues (add, commit avec son message généré, push, puis chaque merge sous la forme branche source → branche cible).

Ce tableau se limite aux actions : pas de liste de fichiers, pas de décompte de lignes.

La confirmation est unique et couvre toute la séquence : sur « ok », exécuter `add` + `commit` + `push` sur la branche courante, puis les merges dans l'ordre cité, sans redemander de validation intermédiaire.

## Contraintes
