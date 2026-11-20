## Objective

Ajouter au skill forge le travail en essaim d'agents IA, en trois développements tirés des propositions de `.forge/branch/agent-swarm/input/` :
- **Hook de mesure** : un script de hook propre à forge enregistre, par branche, le temps des agents (session principale et délégués), le temps humain, les questions et les vérifications dans `.forge/branch/<BRANCH>/time-log.jsonl`. Un script d'agrégation renvoie ces durées en JSON.
- **Estimation du temps** : chaque tâche du plan estime le nombre de fichiers qu'elle touchera. La durée d'agent est annoncée avec une fourchette et se recale sur les mesures du projet. Les durées humaines attachées aux lettres d'effort disparaissent.
- **Délégation en essaim** : un plan de branches filles avec leurs dépendances. Le parent garde N délégués en cours dans des worktrees, relaie et regroupe leurs questions, fusionne chaque branche terminée dans la branche parente et relance aussitôt les branches débloquées. Il tient l'état de l'essaim dans `swarm.md` et sait reprendre après une interruption.

## Scope & rules

- Les propositions de `input/` sont la référence. Un écart à leur texte se signale et se tranche avec l'utilisateur, il ne s'applique pas en silence.
- Le texte du skill suit `coding-standards.md` : infinitif impératif, libellés de structure en anglais, règle énoncée une seule fois.
- Chaque nouveau script (`time-hook.sh`, `time-aggregate.sh`…) a son test dans `tests/`, sur des dépôts jetables, comme les scripts existants. Il renvoie du JSON, sans `jq`, en s'appuyant sur `json.sh`.
- Un script de hook sort toujours avec le code 0, n'écrit rien sur la sortie standard et ne lit jamais un transcript.
- Les points à vérifier du §7 de la proposition de hook (hooks déclarés dans le frontmatter d'un skill, `cwd` et `agent_id` des sous-agents) sont vérifiés avant d'écrire les scripts. Le repli par réglages passe par les installeurs existants (`install.ps1` / `install.sh`, qui fusionnent déjà `settings.json` pour le hook `PreCompact`), jamais par une écriture du skill dans les réglages.
- L'essaim ne pousse rien et ne fusionne jamais vers la branche par défaut : la parente est livrée par `grave`, sur décision de l'utilisateur.
- Hors périmètre : la mise en commun des mesures entre projets (§3.1 de l'estimation, « plus tard »).
