# Comportement des hooks Claude Code — vérification du 2026-11-20

Claude Code 2.1.329, Windows 11, Git Bash. Sources : documentation (`hooks.md`, `skills.md`, `sub-agents.md` sur code.claude.com/docs) et essai réel, dépôt jetable avec un worktree `child` : un hook qui journalise son entrée brute horodatée, une session `claude -p` qui invoque le skill, lance un sous-agent exécutant une commande dans le worktree, puis une seconde session `--continue`.

## Résultats

| Point (§7 de la proposition) | Documentation | Essai réel | Verdict |
|---|---|---|---|
| Hook de frontmatter actif après l'invocation du skill | « rest of the session » | actif dans le tour d'invocation (`SubagentStart`, `PreToolUse`, `PostToolUse`, `Stop` reçus) | oui, dans la session courante |
| Hook de frontmatter conservé après reprise (`--continue`) | non documenté | aucun événement au tour repris | **non** : perdu à la reprise d'une session |
| `UserPromptSubmit` du tour qui invoque le skill | — | non reçu (le hook s'enregistre après) | **perdu** : le tour `/forge` échappe à la mesure |
| Hook de frontmatter dans les outils d'un sous-agent | non documenté | `Bash` du sous-agent non reçu ; `SubagentStop` non reçu | **non** |
| `${CLAUDE_SKILL_DIR}` dans la commande d'un hook de frontmatter | documenté pour le contenu du skill et `allowed-tools` seulement | hook jamais exécuté | **non substitué** |
| Hook déclaré par réglages (`--settings`) dans un sous-agent | « apply inside subagents » | `PreToolUse` / `PostToolUse` du sous-agent reçus avec `agent_id`, `SubagentStart` et `SubagentStop` reçus | **oui** |
| `cwd` d'un événement de délégué | non documenté | toujours le dossier de la session parente, même après `cd <worktree>` dans la commande | **jamais le worktree** |
| `agent_id` absent dans la session principale | non explicite | absent sur `UserPromptSubmit`, `Stop` et les outils de la session principale | oui |
| `duration_ms` sur `PostToolUse` | oui | oui (`70` ms pour un `echo`) | oui |
| Horodatage dans l'entrée | aucun | aucun | le script le prend |
| Shell sous Windows | Git Bash, sinon PowerShell ; champ `shell` | Git Bash | oui |
| `UserPromptSubmit` déclenché par un retour de sous-agent | non documenté | oui : le compte rendu du délégué arrive comme un prompt (`<agent-message …>`) | **à distinguer** d'un prompt humain |
| Entrée des hooks | — | contient le texte du prompt, des commandes et des réponses d'outils | le script n'en garde aucun contenu |

## Conséquences pour la mesure

1. **Déclaration :** les hooks de frontmatter ne conviennent pas : ils ne voient pas les délégués, disparaissent à la reprise et manquent le tour d'invocation. Le hook passe par les installeurs (`settings.json`, même mécanique que `PreCompact`), comme prévu en repli.
2. **Rattachement à une branche :** la règle « branche extraite dans `cwd` » vaut pour la session principale seulement. Tout événement de délégué arrive avec le `cwd` du parent et un `agent_id`. Il faut donc une correspondance `agent_id` → branche fille, écrite par le parent au lancement de chaque délégué (l'identifiant figure dans le retour de l'outil `Agent`), et l'agrégation de la branche fille lit ces événements dans le journal du parent.
3. **Temps humain :** un `UserPromptSubmit` dont le prompt commence par `<agent-message` ou `<task-notification` est un retour de délégué, pas une reprise humaine. Le script note seulement l'origine (`human` / `agent`), à partir du premier caractère du prompt, sans en garder le contenu.
4. **Délégués :** chaque retour (`FORGE_QUESTION`, `FORGE_DONE`) produit un `SubagentStop`, chaque reprise par `SendMessage` un `SubagentStart` : l'attente des réponses de l'utilisateur est exclue d'office.
5. **Hook global :** déclaré dans les réglages, il tourne dans tous les projets. Le script sort aussitôt, sans rien écrire, quand le dossier `.forge/branch/<branche>/` est absent.
