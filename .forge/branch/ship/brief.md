## Objective

Extraire la séquence git de la livraison (`ship` / `engrave`) du texte de `phases/p5-resume.md` vers un script bash unique, exécuté par l'outil Bash sur toutes les plateformes. Le script prend la branche de départ, le message de commit et une liste de branches cibles de longueur variable ; il produit le tableau récapitulatif selon un template fixe, puis exécute `add` → `commit` → `push`, une suite `checkout` → `merge` → `push` par branche citée, et le retour final sur `<BRANCH>`. Le skill n'a plus qu'à appeler le script, d'abord en mode aperçu (tableau), puis en mode exécution après la confirmation `Engrave` ou à l'issue de la question `Ship` — l'arrêt sur conflit ou push rejeté est géré par le script lui-même.

## Scope & rules
