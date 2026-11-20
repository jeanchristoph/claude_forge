## Objective

Donner à chaque tâche d'un plan forge un temps estimé et un temps réel mesuré, en s'appuyant sur la mesure déjà livrée par `agent-swarm` (hook `time-hook.sh`, `time-aggregate.sh`, `time-calibrate.sh`, `metrics.json`).

**1. Temps estimé figé par tâche** (`phases/p4-plan.md`)
- À l'écriture du plan, chaque tâche porte `**Estimated time:** ≈ <min> min (<bas>-<haut>)`, sous `**Estimated files:**`, calculé par `time-calibrate.sh --files <Estimated files>`.
- Valeur figée : jamais recalculée, c'est la prévision comparée au réel. Seule la ligne `Remaining ≈ …` de la reprise suit le ratio du moment.

**2. Temps réel par tâche**
- Nouveau script `time-mark.sh --root <ROOT> --branch <BRANCH> --task T<n> --event start|done` : ajoute une ligne horodatée `{"event":"task_start"|"task_done","task":"T<n>"}` à `.forge/branch/<BRANCH>/time-log.jsonl` ; journal absent (hook non installé) → n'écrit rien ; sortie 0 dans tous les cas, rien sur la sortie standard.
- Le skill l'appelle au démarrage de chaque tâche et à sa coche, dans tous les modes (aujourd'hui seul le mode délégué d'essaim trace « task <n> started », dans LOG uniquement).
- `time-aggregate.sh --task T<n>` : temps d'agent entre les deux marques, avec les règles actuelles (attentes de question retirées, temps humain à part, absence au-delà de 6 h écartée). Délégué : marques dans le journal du worktree, événements dans le journal du parent, reliés par la ligne `delegate` existante (`--parent-log`), sans `agent_id` à transmettre.
- À la coche : `**Actual time:** ≈ <min> min` sous `**Estimated time:**` ; mesure absente (pas de journal, `late_start`, marque de début manquante) → `**Actual time:** —`, jamais une durée estimée à la main.
- Tâche-branche d'un essaim : réel = `agent_minutes` du `metrics.json` de la branche, déjà calculé à la fusion (`commands/swarm.md`), reporté aussi dans `**Actual time:**`.

**3. Affichage** — tableau d'avancement de `phases/p5-resume.md` : Tâche | Effort | Fichiers | Estimé | Réel | Statut.

**4. Tests** — `tests/time-mark.test.sh` ; cas `--task` dans `tests/time-aggregate.test.sh` : fenêtre normale, question dans la fenêtre, marque manquante, délégué, absence > 6 h.

## Scope & rules

- Branche créée depuis `agent-swarm` (non fusionnée dans `master`) : elle porte la mesure dont dépend cette branche.
- Le texte du skill suit `.forge/coding-standards.md` : infinitif impératif, libellés de structure en anglais, règle énoncée une seule fois.
- Chaque nouveau script a son test dans `tests/`, sur des dépôts jetables, comme les scripts existants ; JSON sans `jq`, via `json.sh`.
- Un script appelé comme hook ou marqueur sort toujours avec le code 0, n'écrit rien sur la sortie standard et ne lit jamais un transcript.
- Hors périmètre : calibrage du ratio à partir des tâches (fichiers réels par tâche inconnus) ; mise en commun des mesures entre projets.
- Rien n'est poussé ni fusionné : la livraison se décide par l'utilisateur.
- Écart au brief (décision du 2026-11-20, option C) : les marques de tâche d'un délégué vont dans le `time-log.jsonl` de la branche parente, pas dans celui du worktree — le hook y écrit déjà les événements du délégué (cwd du parent), le worktree n'a jamais de journal. `time-mark.sh --time-log <fichier>` remplace le journal de la branche, la marque porte `"branch":"<X>"` ; ligne `TIME_LOG:` ajoutée au prompt du délégué dans `commands/delegation.md` et `commands/swarm.md`. Session non déléguée inchangée (journal de sa propre branche) ; règle « journal absent → rien » conservée.
