# Explication — dispatch de sous-agents sur les tâches du plan

## 2026-08-12 — Automatiser le développement par sous-agents

### Question posée

Une chaîne de rôles — développeur senior, puis QA, puis architecte, puis QA seniors — est-elle
la bonne façon d'automatiser le développement par sous-agents ? Existe-t-il des références
validées sur le sujet ?

### Ce qui existe déjà et ressemble à cette idée

Des systèmes de recherche, pas des outils de production :

- **ChatDev** simule une entreprise logicielle avec des rôles designer, développeur, testeur.
- **MetaGPT** définit cinq rôles couvrant le cycle complet — Product Manager, Architecte,
  Chef de projet, Ingénieur, QA — avec des procédures standardisées et une communication
  **par documents** plutôt que par conversation libre.
- **AgentCoder** décompose la génération de code en agents de génération, de test et de
  raffinement ; **MapCoder** imite le programmeur humain via des agents de récupération,
  planification, codage et débogage.

Référence : https://arxiv.org/html/2404.04834v4

### Les mesures publiées — défavorables au multi-agent

- Sur **SWE-bench Verified**, toutes les architectures multi-agents **dégradent** le résultat
  de 2 à 15 % dès lors que la baseline d'un agent seul dépasse **45 %**.
- **Coût.** Une trajectoire single-agent pour résoudre une issue GitHub tourne autour de
  **48 400 tokens sur 40 étapes**. Les systèmes multi-agents demandent **4 à 220 fois** cette
  base, et encore **2 à 12 fois** en configuration optimisée. MetaGPT et ChatDev dépassent
  **10 dollars par tâche** rien qu'en surcoût de communication.
- **Mécanisme identifié.** Au-delà d'environ 45 % de baseline, le coût de coordination dépasse
  le gain de parallélisation ou de vérification.
- **L'industrie reste majoritairement single-agent en 2026** (GitHub Copilot, Cursor, Windsurf).
  Cursor 2.0 n'a introduit du multi-agent que pour de l'exécution parallèle isolée en tâche
  de fond.

Référence : https://arxiv.org/pdf/2604.03515

### Ce qui est validé et fonctionne

- **Le relecteur en contexte frais.** Un sous-agent neuf n'est pas biaisé vers le code qu'il
  vient d'écrire : il ne voit que le diff et les critères. C'est **le contexte vierge** qui
  produit l'effet, pas l'intitulé « senior » du rôle — les titres ronflants n'ont **aucun effet
  mesuré**.
- **Le fan-out sur unités indépendantes**, en worktrees git, avec la **partition décidée avant
  le lancement** : deux sous-agents écrivant dans le même fichier produisent une course.
- **La boucle de vérification mécanique** : suite de tests complète avant de déclarer une tâche
  terminée. Le juge doit être le compilateur, les types et les tests — **jamais un agent**.

Référence : https://code.claude.com/docs/en/best-practices

### Le schéma retenu pour la forge

**Partition préalable.** Les tâches sont regroupées selon les fichiers qu'elles touchent,
information que le plan porte déjà dans son champ `Files`. Fichiers disjoints → parallèle en
worktree. Intersection → séquentiel dans le même groupe.

**Pipeline plutôt que barrière.** Chaque tâche traverse implémentation, vérification mécanique
puis vérification adversariale sans attendre les autres.

**Cellule par tâche :**

1. **Implémentation** — contexte = brief + coding-standards + la tâche.
2. **Vérification mécanique** — tests, lint, types.
   - Rouge → retour à l'implémentation, **deux reprises au maximum**, puis `[!] blocked` dans
     le plan avec la raison.
   - Vert → étape suivante.
3. **Vérification adversariale** — trois vérificateurs en contexte frais, chacun avec un angle
   distinct (respect du brief, régression, sécurité, dette introduite), ne voyant que le diff
   et le brief.
   - Majorité défavorable → retour à l'implémentation, **deux reprises au maximum**.

**Une seule barrière, à la fin.** Une revue transversale unique cherche les incohérences entre
tâches, les doublons et la dette accumulée. Une revue *uniquement* globale arriverait trop
tard : une tâche défectueuse aurait déjà servi de fondation aux suivantes.

**Un seul écrivain sur `plan.md` et `log.md` : l'orchestrateur.** Les agents rendent un verdict
structuré, jamais une écriture directe — des écritures concurrentes corrompraient les fichiers.

**Confirmation unique au lancement**, sur un récapitulatif chiffré (nombre de tâches, nombre
d'agents, ordre), à l'image de ce que fait déjà la procédure de Livraison pour git.

### Cadrage

La forge traite des tâches **XS à M** — précisément le régime où un agent seul est performant
et où la coordination coûte le plus cher **en proportion**. Le multi-agent paie sur des
chantiers longs et découpables (migration, audit large), pas sur l'ajout de deux fichiers.

**Recommandation** : démarrer par la version minimale — un implémenteur, un vérificateur en
contexte frais, une boucle de tests plafonnée — l'éprouver sur des tâches réelles, et n'ajouter
des rôles qu'en cas de manque constaté.

### Nom de la commande

`frappe` / `hammer`, retenu contre `trempe` / `temper`, `atelier` / `workshop` et
`compagnons` / `journeymen`. La frappe désigne les coups répétés sur la pièce chauffée : c'est
la boucle implémentation → vérification → reprise, jouée autant de fois que nécessaire.
Verbe à l'impératif, comme toutes les commandes de la forge (`grave`, `range la forge`) — une
racine métier, une forme propre à chaque langue, et aucun accent à taper.
