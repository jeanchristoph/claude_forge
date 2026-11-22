#!/bin/bash
# Hook de coche du plan : mesure une tâche quand sa ligne de statut passe à [x] — le modèle ne pose aucune marque.
#   Déclaré par les installeurs sur PostToolUse (Edit|Write|MultiEdit), synchrone : hors d'un fichier
#   .forge/branch/<branche>/plan.md, il sort aussitôt, sans lancer de processus
#   État dans le journal de mesure : ligne {"event":"plan_checkpoint","done":"T1 T2","files":…} — heure, tâches
#   cochées, empreinte du dossier ; jamais de fichier d'état à part
#   Premier passage → premier point d'étape, aucune marque. Tâche ### Tn passée à [x] → task_start rétroactive
#   (heure et empreinte du dernier point d'étape), task_done maintenant, nouveau point d'étape ; réel par
#   time-aggregate.sh --task, écrit en **Actual time:** sous la tâche (« — » sans mesure)
#   Coche retirée → point d'étape réécrit avec la liste à jour, heure et empreinte gardées
#   Tâche-branche d'essaim (titre « — Branch ») ou déléguée à un projet lié (note « delegated to ») : aucune marque,
#   son réel vient du skill ; sa coche déplace le point d'étape
#   Délégué (agent_id) dont le cwd mène au journal d'une autre branche : marques dans ce journal, avec la branche du plan
#   Sans journal (hook de mesure absent) : chaque tâche cochée sans **Actual time:** reçoit « — »
#   À chaque écriture du plan, après la mesure : tâche avec **Files:** sans **Estimated time:** estimée, en-tête
#   **Estimate:** ajouté s'il manque (estimation existante jamais recalculée) ; ## Summary réécrit depuis les tâches —
#   Task | Effort | Files | Estimated | Actual | Status, titre court d'une ligne gardé, ligne **Total**, ligne
#   **Remaining** des tâches ouvertes (retirée sans tâche ouverte) ; un seul appel time-calibrate.sh
# Entrée : JSON du hook sur l'entrée standard
# Sortie : additionalContext quand plan.md est réécrit ; sortie 0 dans tous les cas

exec 2>/dev/null

readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")/../scripts"
source "$SCRIPT_DIR/json.sh" || exit 0
source "$SCRIPT_DIR/task-marks.sh" || exit 0
source "$SCRIPT_DIR/task-files.sh" || exit 0

readonly TIME_LOG_NAME="time-log.jsonl"
readonly PLAN_PATH_PATTERN='^(.*)/\.forge/branch/(.+)/plan\.md$'
readonly NO_MEASURE="—"

# Une ligne « tâche<TAB>statut<TAB>écartée<TAB>réel_présent » par tâche ### Tn, statut lu par TASK_STATUS_AWK.
readonly PLAN_TASKS_PROGRAM="$TASK_STATUS_AWK"'
  function flush() { if (task != "") printf "%s\t%s\t%d\t%d\n", task, status, is_skipped, has_actual; task = "" }
                                   { sub(/\r$/, "") }
  is_task_heading($0)              { flush(); task = $2; status = "open"; is_skipped = ($0 ~ / — Branch /); has_actual = 0; next }
  /^## /                           { flush(); next }
  task != "" && /^\*\*Actual time:\*\*/ { has_actual = 1 }
  task != "" && is_status_line($0) { status = status_of($0); if ($0 ~ /delegated to/) is_skipped = 1 }
  END { flush() }'

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
#   remaining (« fichiers<TAB>≈ m min (b-h) ») vide → pas de ligne **Remaining**. Fins de ligne du plan gardées.
readonly SUMMARY_PROGRAM="$TASK_STATUS_AWK$TASK_FILES_AWK"'
  function trim(text) { sub(/^[ \t]+/, "", text); sub(/[ \t]+$/, "", text); return text }
  function after_label(text, label) { return trim(substr(text, length(label) + 1)) }
  function first_number(text) { return match(text, /[0-9]+(\.[0-9]+)?/) ? substr(text, RSTART, RLENGTH) + 0 : 0 }
  function without_range(text) { sub(/ *\([^)]*\)$/, "", text); return text }
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
    else emit_row("**Total** (0/" tasks " measured) | | | — | — |")
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
  line ~ /^\*\*Estimate:\*\*/ && header != "" { print "**Estimate:** " header eol; next }
  { print }
  line ~ /^\*\*Date:\*\*/ && !has_header && header != "" { print "**Estimate:** " header newline }
  is_task_heading(line) { current = $2 }
  line ~ /^\*\*Effort:\*\*/ && (current in new_estimate) { print "**Estimated time:** " new_estimate[current] newline }
  END {
    if (in_summary && !table_written) emit_table()
    if (!has_summary) { print newline; print "## Summary" newline; emit_table() }
  }'

INPUT=""
ROOT=""
BRANCH=""
PLAN=""
TIME_LOG=""
MARK_BRANCH=""
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
# où ses marques portent alors la branche du plan (MARK_BRANCH).
resolve_time_log() {
  local lines top branch parent_log
  TIME_LOG="$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME"
  MARK_BRANCH=""
  json_string_field agent_id "$INPUT"
  [ -n "$REPLY" ] || return 0
  json_path_field cwd "$INPUT"
  lines=$(git -C "$REPLY" rev-parse --show-toplevel --abbrev-ref HEAD) || return 0
  top=${lines%%$'\n'*}
  branch=${lines#*$'\n'}
  parent_log="$top/.forge/branch/$branch/$TIME_LOG_NAME"
  [ "$branch" != "HEAD" ] && [ -f "$parent_log" ] || return 0
  [ "$parent_log" -ef "$TIME_LOG" ] && return 0
  TIME_LOG=$parent_log
  MARK_BRANCH=$BRANCH
}

# Tâches cochées du plan : DONE_TASKS (toutes, ordre du plan), MEASURABLE_DONE (hors tâches écartées),
# UNMEASURED_DONE (mesurables sans **Actual time:**).
read_plan_tasks() {
  local task status is_skipped has_actual
  while IFS=$'\t' read -r task status is_skipped has_actual; do
    [ "$status" = "done" ] || continue
    DONE_TASKS+="${DONE_TASKS:+ }$task"
    [ "$is_skipped" = 1 ] && continue
    MEASURABLE_DONE+=("$task")
    [ "$has_actual" = 1 ] || UNMEASURED_DONE+=("$task")
  done < <(awk "$PLAN_TASKS_PROGRAM" "$PLAN")
}

is_in_list() {
  [[ " $2 " == *" $1 "* ]]
}

# Dernier point d'étape de la branche : CHECKPOINT_TS, CHECKPOINT_DONE, CHECKPOINT_FILES (chaîne JSON, vide hors git) ;
# rend 1 sans point d'étape.
read_last_checkpoint() {
  local branch_key="" line
  if [ -n "$MARK_BRANCH" ]; then
    json_escape "$MARK_BRANCH"
    branch_key="\"branch\":$REPLY"
  fi
  line=$(awk -v key="$branch_key" '
    index($0, "\"event\":\"plan_checkpoint\"") && (key == "" ? !index($0, "\"branch\":") : index($0, key)) { last = $0 }
    END { print last }' "$TIME_LOG")
  [[ $line =~ \"ts\":([0-9]+) ]] || return 1
  CHECKPOINT_TS=${BASH_REMATCH[1]}
  CHECKPOINT_DONE=""
  [[ $line =~ \"done\":\"([^\"]*)\" ]] && CHECKPOINT_DONE=${BASH_REMATCH[1]}
  CHECKPOINT_FILES=""
  [[ $line =~ \"files\":(\"([^\"\\]|\\.)*\") ]] && CHECKPOINT_FILES=${BASH_REMATCH[1]}
  return 0
}

append_checkpoint() {
  local time=$1 files_json=$2 line="{\"ts\":$1,\"event\":\"plan_checkpoint\""
  if [ -n "$MARK_BRANCH" ]; then
    json_escape "$MARK_BRANCH"
    line+=",\"branch\":$REPLY"
  fi
  line+=",\"done\":\"$DONE_TASKS\""
  [ -n "$files_json" ] && line+=",\"files\":$files_json"
  printf '%s}\n' "$line" >> "$TIME_LOG"
}

# Réel d'une tâche dans REPLY : « ≈ <min> min · <n> files · <c> min checks », sans la partie fichiers inconnue, ou « — ».
# La part de vérifications nourrit le coût fixe de vérification du calibrage (time-calibrate.sh).
measure_task() {
  local result parent_log=()
  [ -n "$MARK_BRANCH" ] && parent_log=(--parent-log "$TIME_LOG")
  result=$(bash "$SCRIPT_DIR/time-aggregate.sh" --root "$ROOT" --branch "$BRANCH" "${parent_log[@]}" --task "$1")
  REPLY=$NO_MEASURE
  [[ $result == *'"measured":true'* ]] && [[ $result =~ \"agent_minutes\":([0-9.]+) ]] || return 0
  REPLY="≈ ${BASH_REMATCH[1]} min"
  [[ $result =~ \"actual_files\":([0-9]+) ]] && REPLY+=" · ${BASH_REMATCH[1]} files"
  [[ $result =~ \"check_minutes\":([0-9.]+) ]] && REPLY+=" · ${BASH_REMATCH[1]} min checks"
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
    task_mark_line "$CHECKPOINT_TS" task_start "$task" "$MARK_BRANCH" "$CHECKPOINT_FILES"
    printf '%s\n' "$REPLY" >> "$TIME_LOG"
    task_mark_line "$now" task_done "$task" "$MARK_BRANCH" "$files_json"
    printf '%s\n' "$REPLY" >> "$TIME_LOG"
  done
  append_checkpoint "$now" "$files_json"
  for task in "$@"; do
    measure_task "$task"
    updates+="$task"$'\t'"$REPLY"$'\n'
  done
  REPLY=$updates
}

# Coches comparées au dernier point d'étape ; « tâche<TAB>réel » des tâches à écrire dans REPLY, vide sinon.
measure_ticks() {
  local task new_tasks=() has_new_tick=0
  REPLY=""
  if ! read_last_checkpoint; then
    current_time_ms || return 0
    local now=$REPLY
    snapshot_files "$ROOT" && json_escape "$REPLY" || REPLY=""
    append_checkpoint "$now" "$REPLY"
    REPLY=""
    return 0
  fi
  [ "$DONE_TASKS" = "$CHECKPOINT_DONE" ] && return 0
  for task in $DONE_TASKS; do
    is_in_list "$task" "$CHECKPOINT_DONE" && continue
    has_new_tick=1
    is_in_list "$task" "${MEASURABLE_DONE[*]}" && new_tasks+=("$task")
  done
  if [ "$has_new_tick" = 0 ]; then
    append_checkpoint "$CHECKPOINT_TS" "$CHECKPOINT_FILES"
    return 0
  fi
  mark_new_tasks "${new_tasks[@]}"
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
  local index open_files=0 open_minutes=0 open_low=0 open_high=0
  NEW_ESTIMATES=""; REMAINING=""; INDICATIVE=0
  read_inventory
  [ "$HAS_OPEN" = 1 ] || [ "$HAS_HEADER" = 0 ] || [ "$HAS_MISSING" = 1 ] || return 0
  [ ${#TASK_IDS[@]} -gt 0 ] || return 0
  calibrate "$(IFS=,; echo "${TASK_FILE_COUNTS[*]}")" || return 0
  for index in "${!TASK_IDS[@]}"; do
    if [ "${TASK_IS_MISSING[index]}" = 1 ]; then
      NEW_ESTIMATES+="${TASK_IDS[index]}"$'\t'"≈ ${TASK_MINUTES[index]} min (${TASK_LOW[index]}-${TASK_HIGH[index]})"$'\n'
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
  compute_estimates
  current=$(cat "$PLAN")
  content=$(awk -v estimates="$NEW_ESTIMATES" -v indicative="$INDICATIVE" -v remaining="$REMAINING" \
    "$SUMMARY_PROGRAM" "$PLAN" "$PLAN") || return 1
  [ -n "$content" ] && [ "$content" != "$current" ] || return 1
  printf '%s\n' "$content" > "$PLAN"
}

report_to_model() {
  local summary=${1//$'\t'/ → } message="forge plan-hook: plan.md rewritten ($PLAN)"
  summary=${summary%$'\n'}
  summary=${summary//$'\n'/ ; }
  [ -n "$summary" ] && message+=" — **Actual time:** $summary"
  message+=" — ## Summary, estimates and remaining work kept up to date by the hook. Read plan.md again before editing it."
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
    measure_ticks
  else
    unmeasured_updates
  fi
  updates=$REPLY
  [ -n "$updates" ] && write_actual_times "$updates" && is_rewritten=1
  refresh_summary && is_rewritten=1
  [ "$is_rewritten" = 1 ] || exit 0
  report_to_model "$updates"
}

main
exit 0
