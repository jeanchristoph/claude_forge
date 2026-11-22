# Actual time — temps réel d'une tâche

## 1. Définition

Chaque tâche de `plan.md` porte deux durées :

- **`**Estimated time:**`** : le temps prévu, écrit au plan et **jamais modifié** ensuite (ex. `≈ 4 min (1-5)` : valeur centrale et fourchette).
- **`**Actual time:**`** : le temps réellement passé par l'agent, écrit **au moment de la coche `[x]`**, juste sous la ligne prévue (à défaut sous `**Effort:**`). Forme : `≈ <agent_minutes> min · <actual_files> files`.

## 2. Comment il est mesuré

1. **Démarrage de la tâche** → `time-mark.sh --task T<n> --event start`, avant toute autre action. Il ajoute au journal du hook (`time-log.jsonl`) une marque `task_start` horodatée, avec l'empreinte des fichiers modifiés du dépôt (chemin + hash, hors `.forge`).
2. **Coche** → `time-mark.sh --event done` (marque `task_done`, nouvelle empreinte), puis `time-aggregate.sh --task T<n>`, dans le même appel Bash.
3. `time-aggregate.sh` lit, entre les deux marques, les événements que le **hook de mesure** a écrits (`UserPromptSubmit`, `Stop`, `PreToolUse`/`PostToolUse`, `SubagentStart`/`SubagentStop`) :
   - temps de l'agent = tours de travail, **attentes de question retirées** (`AskUserQuestion` ouvert → fermé : c'est du temps humain, pas du temps agent) ;
   - fichiers réels = fichiers dont l'empreinte diffère entre `task_start` et `task_done` (un fichier touché par deux tâches compte dans chacune).
4. Le skill recopie le JSON : `measured` vrai → `≈ X min · N files` (sans « files » si `actual_files` est `null`) ; `measured` faux → **`**Actual time:** —`**.

Pas de hook installé, pas de journal → rien n'est écrit par les scripts, aucune erreur, et la ligne vaut `—`. Jamais de durée estimée à la main pour la remplacer. Tâche-branche d'essaim ou tâche déléguée à un projet lié : pas de marque, le réel vient de la fusion ou du retour du délégué.

## 3. À quoi il sert

`time-calibrate.sh` lit les **40 dernières tâches mesurées** de tous les `plan.md` (branches filles comprises, tâches-branches et déléguées écartées) et en tire :

- **r = minutes par fichier** (médiane réel ÷ fichiers réels) et l'erreur de prévision du nombre de fichiers, dès 20 tâches ;
- la **fourchette** : 20e et 80e centiles du rapport réel ÷ estimé, dès 20 tâches.

En dessous de 20 tâches, les valeurs de référence du skill s'appliquent et l'estimation reste marquée `indicative`. Le réel d'aujourd'hui fait donc l'estimation de demain.

## 4. Pièges

- **Sous-agents de fond non comptés avant T14.** Jusqu'à la correction T14 de cette branche, seuls les délégués forge (ligne `delegate`) entraient dans la mesure. Un agent lancé par l'outil `Agent` en arrière-plan tourne pendant que la session principale attend sans tour actif : son temps disparaissait. Depuis T14, toute paire `SubagentStart` → `SubagentStop` est comptée, coupée à la fenêtre de la tâche ; un agent associé à une autre branche reste écarté (jamais compté deux fois).
- **Tâches parallèles à fenêtres superposées.** Si T2 et T3 sont ouvertes en même temps, chacune compte les agents actifs dans sa fenêtre : un même agent peut alors gonfler les deux. Limite documentée, non corrigée.
- **Réels déjà écrits figés.** Un `Actual time` écrit n'est jamais recalculé : ceux posés avant T14 restent sous-évalués et continuent d'alimenter le calibrage tant qu'ils figurent parmi les 40 dernières tâches.

## 5. Exemple chiffré (`audit-v0-13`)

| Tâche | Estimé | Réel | Lecture |
|---|---|---|---|
| T6 — Permissions des scripts | ≈ 4 min (1-5) | ≈ 2.2 min · 6 files | Mesure fiable : travail en session principale. Rapport 0,55, dans la fourchette ; 6 fichiers réels pour 8 prévus (README reporté à T12). r ≈ 0,37 min/fichier. |
| T1 à T4 — Audit | ≈ 1 min chacune | 0,1 / 0,5 / 0,7 / 0,3 min · 1 file | Faux bas : le travail a été fait par des agents de fond qui ont tourné **4 à 13 min** chacun ; la mesure n'a retenu que le lancement et la relecture des notes. |

Après T14, la mesure de branche donne 14,7 min de session principale + **29,1 min de sous-agents (7)**. Les réels de T1 à T4, eux, restent figés à 0,1–0,7 min : ils tirent r vers le bas pour les prochaines estimations tant qu'ils restent dans l'échantillon.
