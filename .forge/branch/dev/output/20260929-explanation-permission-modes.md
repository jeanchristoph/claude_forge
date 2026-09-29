# Un skill peut-il changer le mode de Claude ?

## 2026-09-29

### Les modes de permission de Claude Code

| Mode | Comportement |
|---|---|
| `default` | Demande l'autorisation avant chaque action sensible |
| `acceptEdits` | Accepte automatiquement les modifications de fichiers |
| `plan` | Lecture seule : analyse, puis plan soumis à l'approbation de l'utilisateur |
| `auto` | Autonome, avec des garde-fous de sécurité assurés par un classifieur |
| `bypassPermissions` | Aucune demande d'autorisation |

C'est l'utilisateur qui choisit le mode :
- **Shift+Tab** pendant la session ;
- `--permission-mode <mode>` au lancement ;
- `permissions.defaultMode` dans `settings.json`.

### Ce qu'est un skill

Un skill n'est qu'un ensemble d'instructions injectées dans le contexte. Il n'a, à lui seul, aucun pouvoir de basculer le mode de la session.

### Ce qu'un skill PEUT faire

1. **Demander à Claude d'appeler l'outil `EnterPlanMode`** : Claude entre en mode plan, puis en sort via `ExitPlanMode`, qui soumet le plan à l'utilisateur pour approbation.
2. **Pré-autoriser des outils** pendant qu'il est actif, via le champ `allowed-tools` du frontmatter : moins de demandes d'autorisation, mais ce n'est pas un changement de mode.
3. **Choisir un modèle** via le champ `model` du frontmatter.

### Ce qu'un skill NE PEUT PAS faire

- Activer le mode `auto` ou `bypassPermissions`.
- Abaisser le niveau de sécurité de la session.

Ces choix restent une décision de l'utilisateur.

### Exemple appliqué à forge

La phase `p4-plan` pourrait appeler `EnterPlanMode` pour garantir une phase de planification strictement en lecture seule.

**Limite** : l'approbation demandée par `ExitPlanMode` ferait doublon avec l'étape Valider / Annuler propre à forge — l'utilisateur validerait deux fois le même plan.

### Synthèse

| Action | Possible depuis un skill ? | Moyen |
|---|---|---|
| Entrer en mode plan | Oui, indirectement | Instruction d'appeler `EnterPlanMode` |
| Sortir du mode plan | Oui, avec approbation utilisateur | `ExitPlanMode` |
| Réduire les demandes d'autorisation | Oui, le temps du skill | Frontmatter `allowed-tools` |
| Choisir le modèle | Oui | Frontmatter `model` |
| Passer en `acceptEdits`, `auto` ou `bypassPermissions` | Non | Réservé à l'utilisateur (Shift+Tab, `--permission-mode`, `settings.json`) |
| Abaisser la sécurité | Non | Réservé à l'utilisateur |

## 2026-09-29 — Mode plan et effort de raisonnement

### Le mode plan ne raisonne pas plus profondément

Le mode `plan` est un mode de permission : il restreint les actions (lecture seule jusqu'à l'approbation du plan), pas la profondeur de réflexion. Le mode `auto` raisonne avec la même profondeur ; seul un classifieur en arrière-plan remplace les demandes d'autorisation.

L'impression de « mieux réfléchir » en mode plan vient du fait d'explorer avant d'agir, pas d'un budget de réflexion plus grand.

### L'effort est un réglage distinct

Niveaux : `low` / `medium` / `high` / `xhigh` / `max` (disponibilité selon le modèle).

| Moyen | Portée |
|---|---|
| `/effort <niveau>` | Pendant la session |
| `claude --effort <niveau>` | Au lancement |
| Variable d'environnement `CLAUDE_CODE_EFFORT_LEVEL` | Environnement |
| `"effortLevel"` dans `settings.json` | Configuration |
| `"modelSettings": { "<modèle>": { "effort": "<niveau>" } }` | Par modèle |

### Effort et skills / sous-agents

- **Skill** : le frontmatter de `SKILL.md` accepte `effort: xhigh`, appliqué à la seule invocation de ce skill. Cela complète la liste « Ce qu'un skill PEUT faire » ci-dessus.
- **Sous-agent** : aucun champ `effort` documenté. Champs disponibles : `name`, `description`, `tools`, `model`, `permissionMode`, `maxTurns`, `skills`, `memory`, `isolation`, `mcpServers`, `hooks`.

### Exemple appliqué à forge

Un `effort` dans le frontmatter de forge s'appliquerait à tout le skill. Aucun champ ne permet de l'augmenter pour la seule phase de planification : il faudrait que l'utilisateur lance `/effort`, ou créer un skill dédié.

### Sources

- code.claude.com/docs/en/permission-modes
- code.claude.com/docs/en/model-config
- code.claude.com/docs/en/skills
- code.claude.com/docs/en/sub-agents

## 2026-09-29 — Effort et lenteur d'un sous-agent

### L'effort d'un sous-agent

- Aucun champ `effort` documenté dans la définition d'un sous-agent : son niveau de raisonnement ne se règle pas agent par agent.
- Leviers documentés : le champ `model` (par exemple un modèle plus léger pour un agent de recherche, ou `inherit`) et les réglages d'effort de la session.
- Un sous-agent hérite-t-il de l'effort de la session ? Ce n'est pas documenté explicitement.

### Pourquoi un sous-agent paraît plus lent

1. **Contexte vierge** : il démarre sans contexte et doit le reconstruire en lisant lui-même fichiers et documentation, alors que l'agent parent l'avait déjà.
2. **Appels séquentiels** : chaque appel d'outil est un aller-retour. Exemple : une vérification de documentation aujourd'hui a pris environ 15 appels d'outils et 2 min 30, surtout des récupérations web.
3. **Réponse en fin de course** : tout son raisonnement se déroule avant qu'une réponse soit visible ; le parent ne voit que le rapport final.
4. **Surcoût de lancement et de retour** : s'y ajoute le temps pour le parent de relayer et reformuler le résultat.

### La contrepartie

- Le contexte du parent reste propre.
- Il peut tourner en parallèle et en arrière-plan.
- Il apporte un regard indépendant.

### Règle pratique

| Situation | Choix |
|---|---|
| Fichier ou fait déjà connu | Recherche directe |
| Exploration large, travail parallélisable, vérification indépendante | Sous-agent |

### Exemple appliqué à forge

La commande « frappe » et le mode professeur utilisent déjà des agents en arrière-plan, précisément parce que l'utilisateur ne les attend pas.
