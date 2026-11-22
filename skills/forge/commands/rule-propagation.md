# Correction ou choix d'infrastructure → propagation vers CLAUDE.md

## Garde

Mode délégué → aucune proposition : `AskUserQuestion` est inaccessible et aucune écriture n'a lieu hors de ROOT. STOP — ne pas continuer ce fichier.

**Réaction — dans l'ordre :**
1. Correction demandée → l'appliquer d'abord.
2. Logger le choix retenu ou la correction dans LOG (« Mise à jour du brief et du log » de `phases/p5-resume.md`).
3. Si le cas est propre à cette branche ou à une seule occurrence (coquille isolée) → STOP — ne pas continuer ce fichier.
4. Si `~/.claude/CLAUDE.md` ou le `CLAUDE.md` à la racine du projet couvre déjà le cas → STOP — ne pas continuer ce fichier.
5. En tirer une règle concise et programmatique au format `Quand [cas] → [conduite]`, généralisée, sans nom de fichier ni de ticket, et l'afficher telle qu'elle serait écrite.
6. Poser le choix avec `AskUserQuestion` — `header` : `Rule`, trois options, dans cet ordre :
   - `Add to global CLAUDE.md` → "Add this rule to `~/.claude/CLAUDE.md`, for all your projects."
   - `Add to project CLAUDE.md` → "Add this rule to the `CLAUDE.md` at the project root, created if absent."
   - `Keep it local` → "Write nothing to any `CLAUDE.md`."
7. **Sur `Add to global CLAUDE.md`** → ajouter la règle à `~/.claude/CLAUDE.md` (section existante pertinente ou nouvelle section courte).
8. **Sur `Add to project CLAUDE.md`** → ajouter la règle au `CLAUDE.md` à la racine du projet (section existante pertinente ou nouvelle section courte), créé s'il est absent.
9. **Sur `Keep it local`** → n'écrire dans aucun `CLAUDE.md`, ne jamais reproposer plus tard pour le même cas.

⚠️ Aucune écriture dans un `CLAUDE.md` sans réponse à cette question. Sans réponse → n'écrire rien.
