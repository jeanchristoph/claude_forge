# Brief

## Objective

Auditer la version 0.13.0 de forge par rapport à la 0.12.6 :
- mesurer ce que la 0.13 apporte en fluidité et en vitesse de développement ;
- vérifier que la fonction swarm est bien intégrée, se déclenche au bon moment et ne demande qu'un minimum d'actions utilisateur ;
- vérifier l'absence de régression : le skill répond comme la version précédente sur les autres fonctions ;
- proposer des améliorations d'expérience utilisateur, de performance, de niveau d'information, de fluidité et de facilité d'utilisation, y compris des angles nouveaux comme un plugin Claude Code.

## Scope & rules

- Branche étendue à l'implémentation des pistes A1, A2, A3, A7, A8, A9, A12 du rapport d'audit (`output/20261122-audit-v0-13.md`) ; les autres pistes restent hors périmètre. S'y ajoute l'alignement de la validation d'un ajout de tâches sur celle d'un plan neuf (T13). S'y ajoute l'automatisation en bash de la mesure et de l'estimation (T16 à T19) : le modèle ne pose plus de marque, ne calcule plus et n'écrit plus de durée. S'y ajoute le coût fixe des vérifications par tâche dans l'estimation (T20). S'y ajoutent les corrections de fin d'audit (T21) ; la réduction du temps des tests (suites ciblées par tâche) reste hors périmètre, à voir plus tard.
