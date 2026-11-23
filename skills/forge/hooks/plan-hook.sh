#!/bin/bash
# Hook de coche du plan : mesure une tâche quand sa ligne de statut passe à [x] — le modèle ne pose aucune marque.
#   Déclaré par les installeurs sur PostToolUse (Edit|Write|MultiEdit), synchrone : hors d'un fichier
#   .forge/branch/<branche>/plan.md, il sort aussitôt, sans lancer de processus
#   État dans le journal de mesure : ligne {"event":"plan_checkpoint","done":"T1 T2","files":…} — heure, tâches
#   cochées, empreinte du dossier ; jamais de fichier d'état à part
#   Premier passage → premier point d'étape, aucune marque. Tâche ### Tn passée à [x] → task_start rétroactive
#   (heure et empreinte du dernier point d'étape), task_done maintenant, nouveau point d'étape ; réel par
#   time-aggregate.sh --task, écrit en **Actual time:** sous la tâche : « ≈ <a> min agent (incl. <c> min checks) ·
#   human <h> min (<n> questions) · <f> files · total ≈ <t> min » (« — » sans mesure) ; premier nombre = temps d'agent,
#   vérifications comprises, comparable à l'estimation et lu par le calibrage avec la part « min checks »
#   Coche retirée → point d'étape réécrit avec la liste à jour, heure et empreinte gardées
#   Estimation d'une tâche liée : « · indicative » tant que le plan de son délégué n'existe pas ; dès qu'il existe, à une
#   écriture du plan parent, ses fichiers prévus remplacent ceux de la tâche (**Estimated files:**) et l'estimation est
#   refaite une seule fois, figée
#   Tâche-branche d'essaim (titre « — Branch ») : aucune marque ; à sa coche, réel = agent_minutes du metrics.json de la
#   branche fille, arrivé avec sa fusion, « — » sans lui
#   Tâche déléguée à un projet lié (linked_unit, task-files.sh) : aucune marque, jamais le temps de la session parente ;
#   à sa coche, réel des seuls délégués de ce projet — toute l'unité quand une seule tâche la porte, sinon ses tâches
#   enfant (« ← parent Tn » du plan lié) ; « — » sans mesure. Temps humain « — » : il est celui de la session parente
#   Délégué (agent_id) dont le cwd mène au journal d'une autre branche : marques dans ce journal, avec la branche du plan
#   et, hors du dépôt parent, son projet lié ; première écriture de son plan → ligne {"event":"delegate"} qui associe
#   l'agent à cette branche et à ce projet, sans le modèle
#   Sans journal (hook de mesure absent) : chaque tâche cochée sans **Actual time:** reçoit « — »
#   À chaque écriture du plan, après la mesure : tâche avec **Files:** sans **Estimated time:** estimée, en-tête
#   **Estimate:** ajouté s'il manque (estimation existante jamais recalculée) ; ## Summary réécrit depuis les tâches —
#   Task | Effort | Files | Estimated | Actual | Status, titre court d'une ligne gardé, ligne **Total**, ligne
#   **Remaining** des tâches ouvertes (retirée sans tâche ouverte) ; un seul appel time-calibrate.sh
#   En-tête **Actual:** de la branche jamais écrit ici : metrics.sh l'écrit à la livraison et à la clôture, le hook le
#   garde tel quel ; **Total** à 0 tâche mesurée → renvoi à **Actual:** quand la ligne existe
#   À chaque écriture du plan, réécrit ou non : fichiers output/….sql cités sous ## Deployment et déjà écrits, script
#   de déploiement exclu → alerte « deployment script missing » sans output/*-deployment-script.sql, « … incomplete »
#   quand l'un d'eux n'y est pas cité (commands/deployment-sql.md)
# Entrée : JSON du hook sur l'entrée standard
# Sortie : additionalContext quand plan.md est réécrit ou qu'une alerte de déploiement existe ; sortie 0 dans tous les cas

exec 2>/dev/null

readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")/../scripts"
source "$SCRIPT_DIR/json.sh" || exit 0
source "$SCRIPT_DIR/task-marks.sh" || exit 0
source "$SCRIPT_DIR/task-files.sh" || exit 0

readonly TIME_LOG_NAME="time-log.jsonl"
readonly PLAN_PATH_PATTERN='^(.*)/\.forge/branch/(.+)/plan\.md$'
readonly NO_MEASURE="—"

# Une ligne « tâche<TAB>statut<TAB>écartée<TAB>réel_présent<TAB>unité » par tâche ### Tn, statut lu par TASK_STATUS_AWK ;
# unité : branche fille d'une tâche écartée, « projet @ branche » d'une tâche liée, vide sinon.
readonly PLAN_TASKS_PROGRAM="$TASK_STATUS_AWK"'
  function child_branch(title) { sub(/^.* — Branch /, "", title); gsub(/`/, "", title); sub(/ .*/, "", title); return title }
  function flush() { if (task != "") printf "%s\t%s\t%d\t%d\t%s\n", task, status, is_skipped, has_actual, unit; task = "" }
                                   { sub(/\r$/, "") }
  is_task_heading($0)              { flush(); task = $2; status = "open"; is_skipped = ($0 ~ / — Branch /); has_actual = 0; unit = is_skipped ? child_branch($0) : ""; next }
  /^## /                           { flush(); next }
  task != "" && /^\*\*Actual time:\*\*/ { has_actual = 1 }
  task != "" && unit == ""         { unit = linked_unit($0) }
  task != "" && is_status_line($0) { status = status_of($0) }
  END { flush() }'

# Tâches d un plan lié qui répondent à la tâche parente « parent » : numéros séparés par des virgules.
readonly CHILD_TASKS_PROGRAM="$TASK_STATUS_AWK"'
  { sub(/\r$/, "") }
  is_task_heading($0) && match($0, /← parent T[0-9]+/) {
    traced = substr($0, RSTART, RLENGTH); sub(/^.* /, "", traced)
    if (traced == parent) list = list (list == "" ? "" : ",") $2
  }
  END { print list }'

# Réécrit **Actual time:** des tâches de « updates » (« tâche<TAB>valeur » par ligne) — un réel déjà mesuré (≈) n'est
# jamais remplacé par « — » (deux coches d'une même modification, simultanées pour la mesure) : ancienne ligne retirée,
# nouvelle sous **Estimated time:**, à défaut sous **Effort:**, à défaut sous le titre ; fins de ligne gardées.
# Le plan est lu deux fois : repérage, puis réécriture.
readonly ACTUAL_TIME_PROGRAM='
  BEGIN {
    count = split(updates, rows, "\n")
    for (i = 1; i <= count; i++) if (split(rows[i], pair, "\t") == 2) value[pair[1]] = pair[2]
  }
  { line = $0; sub(/\r$/, "", line) }
  FNR == NR {
    if (line ~ /^### T[0-9]+/) { split(line, words, " "); task = (words[2] in value) ? words[2] : ""; if (task != "") anchor[task] = FNR; next }
    if (line ~ /^## /) { task = ""; next }
    if (task == "") next
    if (line ~ /^\*\*Actual time:\*\*/ && value[task] == "—" && line ~ /≈/) { delete anchor[task]; task = ""; next }
    if (line ~ /^\*\*Actual time:\*\*/) drop[FNR] = 1
    else if (line ~ /^\*\*Estimated time:\*\*/) { anchor[task] = FNR; has_estimate[task] = 1 }
    else if (line ~ /^\*\*Effort:\*\*/ && !(task in has_estimate)) anchor[task] = FNR
    next
  }
  FNR == 1 { for (task in anchor) inserted_after[anchor[task]] = task }
  !(FNR in drop) { print }
  FNR in inserted_after { print "**Actual time:** " value[inserted_after[FNR]] (($0 ~ /\r$/) ? "\r" : "") }'

# Fichiers prévus d un plan lié : ceux des tâches qui répondent à « parent », toutes quand parent est vide.
readonly LINKED_FILES_PROGRAM="$TASK_STATUS_AWK$TASK_FILES_AWK"'
  function flush() { if (is_counted) total += planned_files_from(estimated_files_line, files_line); is_counted = 0 }
  { sub(/\r$/, "") }
  is_task_heading($0) {
    flush(); estimated_files_line = ""; files_line = ""; traced = ""
    if (match($0, /← parent T[0-9]+/)) { traced = substr($0, RSTART, RLENGTH); sub(/^.* /, "", traced) }
    is_counted = (parent == "" || traced == parent); next
  }
  /^## / { flush(); next }
  /^\*\*Estimated files:\*\*/ { estimated_files_line = $0 }
  /^\*\*Files:\*\*/ { files_line = $0 }
  END { flush(); print total + 0 }'

# Estimation indicative de la tâche « task » retirée, fichiers du plan lié écrits à sa place : le plan est réestimé ensuite.
readonly ADOPT_ESTIMATE_PROGRAM='
  { line = $0; eol = (line ~ /\r$/) ? "\r" : ""; sub(/\r$/, "", line) }
  line ~ /^### T[0-9]+/ { split(line, words, " "); is_target = (words[2] == task) }
  line ~ /^## / { is_target = 0 }
  is_target && line ~ /^\*\*Estimated (time|files):\*\*/ { next }
  { print }
  is_target && line ~ /^\*\*Files:\*\*/ { print "**Estimated files:** " files eol }'

# Tâches liées à l estimation encore indicative, une par ligne.
readonly INDICATIVE_TASKS_PROGRAM="$TASK_STATUS_AWK"'
  { sub(/\r$/, "") }
  is_task_heading($0) { task = $2; next }
  /^## / { task = "" }
  task != "" && /^\*\*Estimated time:\*\*.* · indicative$/ { print task }'

# Inventaire du plan pour l'estimation : « task<TAB>id<TAB>fichiers<TAB>estimée 0/1<TAB>statut » par tâche ### Tn,
# puis « header<TAB>0/1 » (en-tête **Estimate:** présent).
readonly INVENTORY_PROGRAM="$TASK_STATUS_AWK$TASK_FILES_AWK"'
  function flush() {
    if (task != "") printf "task\t%s\t%d\t%d\t%s\n", task, planned_files_from(estimated_files_line, files_line), has_estimate, status
    task = ""
  }
                                   { sub(/\r$/, "") }
  /^\*\*Estimate:\*\*/             { has_header = 1 }
  is_task_heading($0)              { flush(); task = $2; status = "open"; has_estimate = 0; estimated_files_line = ""; files_line = ""; next }
  /^## /                           { flush(); next }
  task == ""                       { next }
  /^\*\*Estimated time:\*\*/       { has_estimate = 1 }
  /^\*\*Estimated files:\*\*/      { estimated_files_line = $0 }
  /^\*\*Files:\*\*/                { files_line = $0 }
  is_status_line($0)               { status = status_of($0) }
  END { flush(); printf "header\t%d\n", has_header }'

# Réécriture du plan, lu deux fois (repérage, puis écriture) :
#   estimates (« id<TAB>≈ m min (b-h) » par ligne) → **Estimated time:** inséré sous **Effort:** ;
#   **Estimate:** recalculé depuis les estimations figées des tâches (fichiers de toutes les tâches, minutes et
#   fourchette sommées), mention indicative gardée ; absent → inséré sous **Date:**, indicatif si indicative vaut 1 ;
#   ## Summary → table régénérée à la place de ses lignes « | », texte libre gardé ; section ajoutée en fin si absente ;
#   **Total** calculé sur les seules tâches au réel mesuré : estimé et réel portent sur les mêmes tâches ;
#   remaining (« fichiers<TAB>≈ m min (b-h) ») vide → pas de ligne **Remaining** ;
#   **Unplanned** (écrite par metrics.sh) gardée telle quelle sous **Total** ;
#   **Actual:** gardé tel quel ; **Total** à 0 tâche mesurée renvoie à **Actual:** quand la ligne existe.
#   Fins de ligne du plan gardées.
readonly SUMMARY_PROGRAM="$TASK_STATUS_AWK$TASK_FILES_AWK"'
  function trim(text) { sub(/^[ \t]+/, "", text); sub(/[ \t]+$/, "", text); return text }
  function after_label(text, label) { return trim(substr(text, length(label) + 1)) }
  function first_number(text) { return match(text, /[0-9]+(\.[0-9]+)?/) ? substr(text, RSTART, RLENGTH) + 0 : 0 }
  function without_range(text) { sub(/ · indicative$/, "", text); sub(/ *\([^)]*\)$/, "", text); return text }
  function record_estimate(id, text) {
    estimated[id] = without_range(text)
    if (match(text, /\([0-9]+-[0-9]+\)/)) { split(substr(text, RSTART + 1, RLENGTH - 2), bounds, "-"); estimated_low[id] = bounds[1]; estimated_high[id] = bounds[2] }
  }
  function header_value(   i, id, total_files, minutes, low, high, has_estimates) {
    for (i = 1; i <= tasks; i++) {
      id = order[i]; total_files += files[id]
      if (estimated[id] == "") continue
      has_estimates = 1; minutes += first_number(estimated[id]); low += estimated_low[id]; high += estimated_high[id]
    }
    return has_estimates ? sprintf("≈ %d files · ≈ %d min (%d-%d)", total_files, minutes, low, high) : ""
  }
  function escape_pipes(text) { gsub(/\|/, "\\|", text); return text }
  function status_cell(text) { return (status_of(text) == "blocked") ? escape_pipes(text) : substr(text, 1, 3) }
  function flush_task() { if (task != "") files[task] = planned_files_from(estimated_files_line, files_line); task = "" }
  function effort_mix(   i, sizes, mix) {
    split("XS S M L XL", sizes, " ")
    for (i = 1; i <= 5; i++) if (effort_count[sizes[i]]) mix = mix (mix == "" ? "" : ", ") effort_count[sizes[i]] sizes[i]
    return mix
  }
  function emit_row(cells) { print "| " cells " |" newline }
  function emit_table(   i, id, title, estimate, actual, estimated_total, actual_total, measured, measured_files, pair) {
    emit_row("Task | Effort | Files | Estimated | Actual | Status")
    print "|---|---|---|---|---|---|" newline
    for (i = 1; i <= tasks; i++) {
      id = order[i]
      title = (id in summary_title) ? summary_title[id] : heading[id]
      estimate = (estimated[id] != "") ? estimated[id] : "—"
      actual = (actual_time[id] != "") ? actual_time[id] : "—"
      if (actual ~ /^≈/) {
        measured++; measured_files += files[id]; effort_count[effort[id]]++
        estimated_total += first_number(estimated[id]); actual_total += first_number(actual)
      }
      emit_row(title " | " effort[id] " | " files[id] " | " estimate " | " actual " | " status[id])
    }
    if (measured) emit_row("**Total** (" measured "/" tasks " measured) | **" effort_mix() "** | **" measured_files "** | **" sprintf("≈ %g min", estimated_total) "** | **" sprintf("≈ %.1f min", actual_total) "** |")
    else emit_row("**Total** (0/" tasks " measured) | | | — | " (has_actual_header ? "see **Actual:**" : "—") " |")
    if (unplanned_row != "") print unplanned_row newline
    if (remaining != "") { split(remaining, pair, "\t"); emit_row("**Remaining** | | **" pair[1] "** | **" pair[2] "** | |") }
    table_written = 1
  }
  BEGIN {
    count = split(estimates, rows, "\n")
    for (i = 1; i <= count; i++) if (split(rows[i], pair, "\t") == 2) new_estimate[pair[1]] = pair[2]
  }
  { line = $0; eol = (line ~ /\r$/) ? "\r" : ""; sub(/\r$/, "", line) }
  FNR == NR && FNR == 1 { newline = eol }
  FNR == NR && is_task_heading(line) {
    flush_task(); task = $2; order[++tasks] = task; heading[task] = escape_pipes(substr(line, 5))
    status[task] = "[ ]"; estimated_files_line = ""; files_line = ""; in_summary = 0; next
  }
  FNR == NR && line ~ /^## / { flush_task(); in_summary = (line ~ /^## Summary/); next }
  FNR == NR && line ~ /^\*\*Estimate:\*\*/ { has_header = 1; is_indicative = (line ~ /indicative/) }
  FNR == NR && line ~ /^\*\*Actual:\*\*/ { has_actual_header = 1 }
  FNR == NR && in_summary && line ~ /^\| \*\*Unplanned\*\*/ { unplanned_row = line; next }
  FNR == NR && in_summary && line ~ /^\| *T[0-9]+/ { split(line, cells, "|"); split(trim(cells[2]), words, " "); summary_title[words[1]] = trim(cells[2]); next }
  FNR == NR && task != "" {
    if (line ~ /^\*\*Effort:\*\*/) effort[task] = after_label(line, "**Effort:**")
    else if (line ~ /^\*\*Estimated time:\*\*/) record_estimate(task, after_label(line, "**Estimated time:**"))
    else if (line ~ /^\*\*Actual time:\*\*/) actual_time[task] = after_label(line, "**Actual time:**")
    else if (line ~ /^\*\*Estimated files:\*\*/) estimated_files_line = line
    else if (line ~ /^\*\*Files:\*\*/) files_line = line
    else if (is_status_line(line)) status[task] = status_cell(line)
  }
  FNR == NR { next }
  FNR == 1 {
    flush_task(); in_summary = 0
    for (id in new_estimate) if (estimated[id] == "") record_estimate(id, new_estimate[id])
    header = header_value()
    if (!has_header) is_indicative = (indicative == 1)
    if (header != "" && is_indicative) header = header " · indicative"
  }
  line ~ /^## / {
    if (in_summary && !table_written) emit_table()
    in_summary = (line ~ /^## Summary/); if (in_summary) has_summary = 1
    print; next
  }
  in_summary && line ~ /^\|/ { if (!table_written) emit_table(); next }
  line ~ /^\*\*Estimate:\*\*/ { print (header != "" ? "**Estimate:** " header eol : $0); next }
  { print }
  line ~ /^\*\*Date:\*\*/ && !has_header && header != "" { print "**Estimate:** " header newline }
  is_task_heading(line) { current = $2 }
  line ~ /^\*\*Effort:\*\*/ && (current in new_estimate) { print "**Estimated time:** " new_estimate[current] newline }
  END {
    if (in_summary && !table_written) emit_table()
    if (!has_summary) { print newline; print "## Summary" newline; emit_table() }
  }'

# Chemins output/….sql cités sous ## Deployment, un par ligne, sans doublon ; script de déploiement exclu.
readonly DEPLOYMENT_SQL_PROGRAM='
                  { sub(/\r$/, "") }
  /^## /          { in_deployment = ($0 ~ /^## Deployment/); next }
  !in_deployment  { next }
  {
    rest = $0
    while (match(rest, /output\/[^` \t)]+\.sql/)) {
      path = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
      if (path !~ /-deployment-script\.sql$/ && !(path in seen)) { seen[path] = 1; print path }
    }
  }'

INPUT=""
ROOT=""
BRANCH=""
PLAN=""
TIME_LOG=""
MARK_BRANCH=""
MARK_PROJECT=""
AGENT_ID=""
declare -A LINKED_UNITS=()
declare -A CHILD_BRANCHES=()
ADOPTED_TASKS=""
DONE_TASKS=""
MEASURABLE_DONE=()
UNMEASURED_DONE=()

# Plan modifié → ROOT, BRANCH, PLAN ; rend 1 pour tout autre fichier.
resolve_plan() {
  json_path_field file_path "$INPUT"
  [[ $REPLY =~ $PLAN_PATH_PATTERN ]] || return 1
  ROOT=${BASH_REMATCH[1]}
  BRANCH=${BASH_REMATCH[2]}
  PLAN=$REPLY
  [ -f "$PLAN" ]
}

# Journal du plan, ou celui de la session parente pour un délégué : son cwd mène au journal d'une autre branche,
# où ses marques portent alors la branche du plan (MARK_BRANCH) et son projet lié (MARK_PROJECT, vide dans le même dépôt).
resolve_time_log() {
  local lines top branch parent_log
  TIME_LOG="$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME"
  MARK_BRANCH=""
  json_string_field agent_id "$INPUT"
  AGENT_ID=$REPLY
  [ -n "$AGENT_ID" ] || return 0
  json_path_field cwd "$INPUT"
  lines=$(git -C "$REPLY" rev-parse --show-toplevel --abbrev-ref HEAD) || return 0
  top=${lines%%$'\n'*}
  branch=${lines#*$'\n'}
  parent_log="$top/.forge/branch/$branch/$TIME_LOG_NAME"
  [ "$branch" != "HEAD" ] && [ -f "$parent_log" ] || return 0
  [ "$parent_log" -ef "$TIME_LOG" ] && return 0
  TIME_LOG=$parent_log
  MARK_BRANCH=$BRANCH
  linked_project "$ROOT" "$top"
  MARK_PROJECT=$REPLY
}

# Association du délégué à sa branche et à son projet lié, écrite une fois par agent dans le journal parent — sans
# horodatage, comme celle de time-mark.sh : triée en tête du journal, elle précède son SubagentStart.
associate_delegate() {
  local line
  [ -n "$MARK_BRANCH" ] || return 0
  json_escape "$AGENT_ID"; line="{\"event\":\"delegate\",\"agent_id\":$REPLY"
  json_escape "$MARK_BRANCH"; line+=",\"branch\":$REPLY"
  if [ -n "$MARK_PROJECT" ]; then
    json_escape "$MARK_PROJECT"
    line+=",\"project\":$REPLY"
  fi
  line+="}"
  grep -qxF -- "$line" "$TIME_LOG" || printf '%s\n' "$line" >> "$TIME_LOG"
}

# Tâches cochées du plan : DONE_TASKS (toutes, ordre du plan), MEASURABLE_DONE (hors tâches écartées),
# UNMEASURED_DONE (mesurables ou liées sans **Actual time:**), LINKED_UNITS (tâche liée, cochée ou non → unité),
# CHILD_BRANCHES (tâche-branche → branche fille).
read_plan_tasks() {
  local task status is_skipped has_actual unit
  while IFS=$'\t' read -r task status is_skipped has_actual unit; do
    if [ "$is_skipped" = 1 ]; then CHILD_BRANCHES[$task]=$unit; elif [ -n "$unit" ]; then LINKED_UNITS[$task]=$unit; fi
    [ "$status" = "done" ] || continue
    DONE_TASKS+="${DONE_TASKS:+ }$task"
    [ "$is_skipped" = 1 ] && continue
    [ -n "$unit" ] || MEASURABLE_DONE+=("$task")
    [ "$has_actual" = 1 ] || UNMEASURED_DONE+=("$task")
  done < <(awk "$PLAN_TASKS_PROGRAM" "$PLAN")
}

is_in_list() {
  [[ " $2 " == *" $1 "* ]]
}

# Valeur brute du champ <nom> du JSON <json> dans REPLY (nombre, true, false, null) ; « null » si absent.
json_number_field() {
  local pattern="\"$1\":([^,}\"]+)"
  REPLY=null
  [[ $2 =~ $pattern ]] && REPLY=${BASH_REMATCH[1]}
}

# Somme de deux durées à une décimale (« 1.2 »), « null » comptant pour zéro, dans REPLY — sans processus.
add_minutes() {
  local first=${1/null/0.0} second=${2/null/0.0} tenths
  tenths=$(( 10#${first/./} + 10#${second/./} ))
  REPLY="$((tenths / 10)).$((tenths % 10))"
}

# Réel d'une tâche dans REPLY : « ≈ <a> min agent (incl. <c> min checks) · human <h> min (<n> questions) · <f> files ·
# total ≈ <t> min », sans la partie fichiers inconnue, ou « — ». Premier nombre = temps d'agent, vérifications comprises,
# comparé à l'estimation ; la part « min checks » nourrit le coût fixe de vérification du calibrage (time-calibrate.sh).
# BUSINESS_RULE: total = agent + humain — les vérifications sont une part du temps d'agent, jamais ajoutées au total
measure_task() {
  local result agent human questions checks files parent_log=()
  [ -n "$MARK_BRANCH" ] && parent_log=(--parent-log "$TIME_LOG")
  [ -n "$MARK_PROJECT" ] && parent_log+=(--project "$MARK_PROJECT")
  result=$(bash "$SCRIPT_DIR/time-aggregate.sh" --root "$ROOT" --branch "$BRANCH" "${parent_log[@]}" --task "$1")
  REPLY=$NO_MEASURE
  [[ $result == *'"measured":true'* ]] || return 0
  json_number_field agent_minutes "$result"; agent=$REPLY
  json_number_field human_minutes "$result"; human=$REPLY
  json_number_field questions "$result"; questions=$REPLY
  json_number_field check_minutes "$result"; checks=$REPLY
  json_number_field actual_files "$result"; files=$REPLY
  add_minutes "$agent" "$human"
  local total=$REPLY
  REPLY="≈ $agent min agent (incl. $checks min checks) · human $human min ($questions questions)"
  [ "$files" != null ] && REPLY+=" · $files files"
  REPLY+=" · total ≈ $total min"
}

# Worktree de <dossier> qui extrait <branche> dans REPLY, vide si aucun.
worktree_of_branch() {
  REPLY=$(git -C "$1" worktree list --porcelain | awk -v ref="branch refs/heads/$2" '
    /^worktree / { path = substr($0, 10) }
    $0 == ref { print path; exit }')
}

# Nombre de tâches du plan qui partagent l'unité <unité>, dans REPLY.
count_unit_tasks() {
  local task
  REPLY=0
  for task in "${!LINKED_UNITS[@]}"; do [ "${LINKED_UNITS[$task]}" = "$1" ] && REPLY=$((REPLY + 1)); done
}

# Réel d'une tâche liée dans REPLY : délégués de son projet seulement, jamais la session parente ; « — » sans mesure.
# Fichiers absents sans worktree : rien à compter, jamais zéro.
measure_linked_task() {
  local unit=${LINKED_UNITS[$1]} directory branch worktree options result agent checks files=null children
  REPLY=$NO_MEASURE
  [[ $unit == *" @ "* ]] || return 0
  directory=${unit% @ *}; branch=${unit##* @ }
  [[ $directory == /* || $directory == [A-Za-z]:* ]] || directory="$ROOT/$directory"
  linked_project "$directory" "$ROOT"
  [ -n "$REPLY" ] || { REPLY=$NO_MEASURE; return 0; }
  options=(--branch "$branch" --parent-log "$TIME_LOG" --project "$REPLY")
  worktree_of_branch "$directory" "$branch"; worktree=$REPLY
  options+=(--root "${worktree:-$directory}")
  REPLY=$NO_MEASURE
  count_unit_tasks "$unit"
  if [ "$REPLY" -gt 1 ]; then
    REPLY=$NO_MEASURE
    children=$(awk -v parent="$1" "$CHILD_TASKS_PROGRAM" "$worktree/.forge/branch/$branch/plan.md")
    [ -n "$worktree" ] && [ -n "$children" ] || return 0
    result=$(bash "$SCRIPT_DIR/time-aggregate.sh" "${options[@]}" --task "$children")
    [[ $result == *'"measured":true'* ]] || return 0
    json_number_field agent_minutes "$result"; agent=$REPLY
    json_number_field actual_files "$result"; files=$REPLY
  else
    result=$(bash "$SCRIPT_DIR/time-aggregate.sh" "${options[@]}")
    json_number_field delegates "$result"
    [ "$REPLY" != null ] && [ "$REPLY" != 0 ] || { REPLY=$NO_MEASURE; return 0; }
    json_number_field delegated_minutes "$result"; agent=$REPLY
    if [ -n "$worktree" ]; then json_number_field files "$result"; files=$REPLY; fi
  fi
  json_number_field check_minutes "$result"; checks=$REPLY
  REPLY="≈ $agent min agent (incl. $checks min checks) · human $NO_MEASURE"
  [ "$files" != null ] && REPLY+=" · $files files"
  REPLY+=" · total ≈ $agent min"
}

# Réel d'une tâche-branche dans REPLY : minutes d'agent de sa branche fille, lues dans le metrics.json fusionné avec elle.
measure_child_branch() {
  local metrics="$ROOT/.forge/branch/${CHILD_BRANCHES[$1]}/metrics.json"
  REPLY=$NO_MEASURE
  [ -n "${CHILD_BRANCHES[$1]}" ] && [ -f "$metrics" ] || return 0
  json_number_field agent_minutes "$(cat "$metrics")"
  if [ "$REPLY" = null ]; then REPLY=$NO_MEASURE; else REPLY="≈ $REPLY min"; fi
}

# Marques des tâches nouvellement cochées, nouveau point d'étape, puis réel de chacune ; « tâche<TAB>réel » dans REPLY.
mark_new_tasks() {
  local now files_json="" task updates=""
  current_time_ms || return 1
  now=$REPLY
  if snapshot_files "$ROOT"; then
    json_escape "$REPLY"
    files_json=$REPLY
  fi
  for task in "$@"; do
    task_mark_line "$CHECKPOINT_TS" task_start "$task" "$MARK_BRANCH" "$CHECKPOINT_FILES" "$MARK_PROJECT"
    printf '%s\n' "$REPLY" >> "$TIME_LOG"
    task_mark_line "$now" task_done "$task" "$MARK_BRANCH" "$files_json" "$MARK_PROJECT"
    printf '%s\n' "$REPLY" >> "$TIME_LOG"
  done
  append_checkpoint "$TIME_LOG" "$now" "$DONE_TASKS" "$files_json" "$MARK_BRANCH" "$MARK_PROJECT"
  for task in "$@"; do
    measure_task "$task"
    updates+="$task"$'\t'"$REPLY"$'\n'
  done
  REPLY=$updates
}

# Coches comparées au dernier point d'étape ; « tâche<TAB>réel » des tâches à écrire dans REPLY, vide sinon.
measure_ticks() {
  local task new_tasks=() linked_tasks=() child_tasks=() has_new_tick=0 updates
  REPLY=""
  if ! read_last_checkpoint "$TIME_LOG" "$MARK_BRANCH" "$MARK_PROJECT"; then
    current_time_ms || return 0
    local now=$REPLY
    snapshot_files "$ROOT" && json_escape "$REPLY" || REPLY=""
    append_checkpoint "$TIME_LOG" "$now" "$DONE_TASKS" "$REPLY" "$MARK_BRANCH" "$MARK_PROJECT"
    REPLY=""
    return 0
  fi
  [ "$DONE_TASKS" = "$CHECKPOINT_DONE" ] && return 0
  for task in $DONE_TASKS; do
    is_in_list "$task" "$CHECKPOINT_DONE" && continue
    has_new_tick=1
    is_in_list "$task" "${MEASURABLE_DONE[*]}" && new_tasks+=("$task")
    [ -n "${LINKED_UNITS[$task]:-}" ] && linked_tasks+=("$task")
    [ -n "${CHILD_BRANCHES[$task]:-}" ] && child_tasks+=("$task")
  done
  if [ "$has_new_tick" = 0 ]; then
    append_checkpoint "$TIME_LOG" "$CHECKPOINT_TS" "$DONE_TASKS" "$CHECKPOINT_FILES" "$MARK_BRANCH" "$MARK_PROJECT"
    return 0
  fi
  mark_new_tasks "${new_tasks[@]}" || { REPLY=""; return 0; }
  updates=$REPLY
  for task in "${linked_tasks[@]}"; do
    measure_linked_task "$task"
    updates+="$task"$'\t'"$REPLY"$'\n'
  done
  for task in "${child_tasks[@]}"; do
    measure_child_branch "$task"
    updates+="$task"$'\t'"$REPLY"$'\n'
  done
  REPLY=$updates
}

# Sans journal : « — » pour chaque tâche cochée mesurable qui n'a pas encore de réel.
unmeasured_updates() {
  local task
  REPLY=""
  for task in "${UNMEASURED_DONE[@]}"; do
    REPLY+="$task"$'\t'"$NO_MEASURE"$'\n'
  done
}

write_actual_times() {
  local content
  content=$(awk -v updates="$1" "$ACTUAL_TIME_PROGRAM" "$PLAN" "$PLAN") || return 1
  [ -n "$content" ] || return 1
  printf '%s\n' "$content" > "$PLAN"
}

# Plan du délégué d'une tâche liée dans REPLY, vide sans worktree ni plan.
linked_plan_of() {
  local unit=${LINKED_UNITS[$1]} directory branch
  directory=${unit% @ *}; branch=${unit##* @ }
  [[ $directory == /* || $directory == [A-Za-z]:* ]] || directory="$ROOT/$directory"
  worktree_of_branch "$directory" "$branch"
  [ -n "$REPLY" ] || return 0
  REPLY="$REPLY/.forge/branch/$branch/plan.md"
  [ -f "$REPLY" ] || REPLY=""
}

# Estimations indicatives des tâches liées dont le délégué a écrit son plan : fichiers repris de ce plan, une fois.
adopt_linked_estimates() {
  local task plan files parent content
  while IFS= read -r task; do
    [ -n "${LINKED_UNITS[$task]:-}" ] || continue
    linked_plan_of "$task"; plan=$REPLY
    [ -n "$plan" ] || continue
    count_unit_tasks "${LINKED_UNITS[$task]}"
    parent=""; [ "$REPLY" -gt 1 ] && parent=$task
    files=$(awk -v parent="$parent" "$LINKED_FILES_PROGRAM" "$plan")
    [ "${files:-0}" -gt 0 ] || continue
    content=$(awk -v task="$task" -v files="$files" "$ADOPT_ESTIMATE_PROGRAM" "$PLAN")
    [ -n "$content" ] && printf '%s\n' "$content" > "$PLAN"
    ADOPTED_TASKS+=" $task"
  done < <(awk "$INDICATIVE_TASKS_PROGRAM" "$PLAN")
}

# Estimation de chaque tâche, une valeur par tâche : TASK_MINUTES, TASK_LOW, TASK_HIGH (dans l'ordre) ; INDICATIVE
# pour un en-tête neuf. Un seul appel ; une liste d'une valeur ne rend que « estimate ».
calibrate() {
  local result estimates pattern='\{"files":([0-9]+),"minutes":([0-9]+),"low":([0-9]+),"high":([0-9]+)\}'
  TASK_MINUTES=(); TASK_LOW=(); TASK_HIGH=(); INDICATIVE=0
  result=$(bash "$SCRIPT_DIR/time-calibrate.sh" --root "$ROOT" --files "$1") || return 1
  [[ $result == *'"indicative":true'* ]] && INDICATIVE=1
  [[ ${result#*\"estimate\":} =~ ^$pattern ]] || return 1
  estimates=${result#*\"estimate\":}
  [[ $result == *'"estimates":['* ]] && estimates=${result#*\"estimates\":[}
  while [[ $estimates =~ $pattern ]]; do
    TASK_MINUTES+=("${BASH_REMATCH[2]}"); TASK_LOW+=("${BASH_REMATCH[3]}"); TASK_HIGH+=("${BASH_REMATCH[4]}")
    estimates=${estimates#*"${BASH_REMATCH[0]}"}
    [[ $result == *'"estimates":['* ]] || break
  done
  [ ${#TASK_MINUTES[@]} -gt 0 ]
}

# Inventaire du plan, une case par tâche : TASK_IDS, TASK_FILE_COUNTS, TASK_IS_OPEN, TASK_IS_MISSING (fichiers sans
# estimation) ; HAS_HEADER, HAS_OPEN, HAS_MISSING.
read_inventory() {
  local kind id files has_estimate status
  TASK_IDS=(); TASK_FILE_COUNTS=(); TASK_IS_OPEN=(); TASK_IS_MISSING=()
  HAS_HEADER=1; HAS_OPEN=0; HAS_MISSING=0
  while IFS=$'\t' read -r kind id files has_estimate status; do
    [ "$kind" = "header" ] && { HAS_HEADER=$id; continue; }
    TASK_IDS+=("$id"); TASK_FILE_COUNTS+=("$files")
    if [ "$status" = "open" ]; then TASK_IS_OPEN+=(1); HAS_OPEN=1; else TASK_IS_OPEN+=(0); fi
    if [ "$has_estimate" = 0 ] && [ "$files" -gt 0 ]; then TASK_IS_MISSING+=(1); HAS_MISSING=1; else TASK_IS_MISSING+=(0); fi
  done < <(awk "$INVENTORY_PROGRAM" "$PLAN")
}

# Valeurs de la réécriture : NEW_ESTIMATES, REMAINING, INDICATIVE (en-tête absent). Un seul appel de calibration, une valeur par
# tâche : le reste à faire additionne les tâches ouvertes, chacune avec son coût fixe de vérification.
compute_estimates() {
  local index estimate open_files=0 open_minutes=0 open_low=0 open_high=0
  NEW_ESTIMATES=""; REMAINING=""; INDICATIVE=0
  read_inventory
  [ "$HAS_OPEN" = 1 ] || [ "$HAS_HEADER" = 0 ] || [ "$HAS_MISSING" = 1 ] || return 0
  [ ${#TASK_IDS[@]} -gt 0 ] || return 0
  calibrate "$(IFS=,; echo "${TASK_FILE_COUNTS[*]}")" || return 0
  for index in "${!TASK_IDS[@]}"; do
    if [ "${TASK_IS_MISSING[index]}" = 1 ]; then
      estimate="≈ ${TASK_MINUTES[index]} min (${TASK_LOW[index]}-${TASK_HIGH[index]})"
      [ -n "${LINKED_UNITS[${TASK_IDS[index]}]:-}" ] && ! is_in_list "${TASK_IDS[index]}" "$ADOPTED_TASKS" && estimate+=" · indicative"
      NEW_ESTIMATES+="${TASK_IDS[index]}"$'\t'"$estimate"$'\n'
    fi
    [ "${TASK_IS_OPEN[index]}" = 1 ] || continue
    open_files=$((open_files + TASK_FILE_COUNTS[index]))
    open_minutes=$((open_minutes + TASK_MINUTES[index]))
    open_low=$((open_low + TASK_LOW[index])); open_high=$((open_high + TASK_HIGH[index]))
  done
  [ "$HAS_OPEN" = 1 ] && REMAINING="$open_files"$'\t'"≈ $open_minutes min ($open_low-$open_high)"
}

# Estimations et ## Summary réécrits ; rend 0 seulement si plan.md a changé.
refresh_summary() {
  local current content
  current=$(cat "$PLAN")
  adopt_linked_estimates
  compute_estimates
  content=$(awk -v estimates="$NEW_ESTIMATES" -v indicative="$INDICATIVE" -v remaining="$REMAINING" \
    "$SUMMARY_PROGRAM" "$PLAN" "$PLAN") || return 1
  [ -n "$content" ] && [ "$content" != "$current" ] || return 1
  printf '%s\n' "$content" > "$PLAN"
}

# Liste « a, b » des arguments.
join_paths() {
  REPLY=$(printf '%s, ' "$@")
  REPLY=${REPLY%, }
}

# Alerte du script de déploiement SQL dans REPLY, vide sans alerte : fichiers d'étape de ## Deployment déjà écrits,
# absents de tout output/*-deployment-script.sql de la branche, ou ce script absent.
check_deployment_script() {
  local branch_dir="$ROOT/.forge/branch/$BRANCH" path written=() scripts=() unreferenced=()
  REPLY=""
  while IFS= read -r path; do
    [ -f "$branch_dir/$path" ] && written+=("$path")
  done < <(awk "$DEPLOYMENT_SQL_PROGRAM" "$PLAN")
  [ ${#written[@]} -gt 0 ] || return 0
  scripts=("$branch_dir"/output/*-deployment-script.sql)
  if [ ! -f "${scripts[0]}" ]; then
    join_paths "${written[@]}"
    REPLY="forge plan-hook: deployment script missing — SQL step files written: $REPLY — apply commands/deployment-sql.md now."
    return 0
  fi
  for path in "${written[@]}"; do
    grep -qF -- "$path" "${scripts[@]}" || unreferenced+=("$path")
  done
  [ ${#unreferenced[@]} -gt 0 ] || return 0
  join_paths "${unreferenced[@]}"
  REPLY="forge plan-hook: deployment script incomplete — SQL step files not referenced: $REPLY — apply commands/deployment-sql.md now."
}

# Compte rendu au modèle : réécriture du plan (is_rewritten = 1) avec ses réels, puis alerte de déploiement ;
# rien sans l'un ni l'autre.
report_to_model() {
  local summary=${1//$'\t'/ → } is_rewritten=$2 warning=$3 message=""
  if [ "$is_rewritten" = 1 ]; then
    summary=${summary%$'\n'}
    summary=${summary//$'\n'/ ; }
    message="forge plan-hook: plan.md rewritten ($PLAN)"
    [ -n "$summary" ] && message+=" — **Actual time:** $summary"
    message+=" — ## Summary, estimates and remaining work kept up to date by the hook. Read plan.md again before editing it."
  fi
  [ -n "$warning" ] && message+="${message:+$'\n'}$warning"
  [ -n "$message" ] || return 0
  json_escape "$message"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":%s}}\n' "$REPLY"
}

main() {
  local updates is_rewritten=0
  INPUT=$(cat) || exit 0
  resolve_plan || exit 0
  read_plan_tasks
  resolve_time_log
  if [ -f "$TIME_LOG" ]; then
    associate_delegate
    measure_ticks
  else
    unmeasured_updates
  fi
  updates=$REPLY
  [ -n "$updates" ] && write_actual_times "$updates" && is_rewritten=1
  refresh_summary && is_rewritten=1
  check_deployment_script
  report_to_model "$updates" "$is_rewritten" "$REPLY"
}

main
exit 0
