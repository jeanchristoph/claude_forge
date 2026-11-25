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
#   Tâche ajoutée au plan (ouverte, avec **Files:**, encore sans **Estimated time:**) sans tâche en cours → point d'étape
#   avancé : la formulation d'une tâche n'entre pas dans son réel. Code modifié depuis le dernier point d'étape → gardé
#   Rafale : tâche à fichiers prévus cochée moins de BURST_MS après la coche précédente, dossier inchangé entre les
#   deux → son travail a eu lieu dans la fenêtre précédente ; elle en reprend le départ, tout le groupe est simultané,
#   « — » pour chacune, réel déjà écrit de la première compris
#   Coche retirée → point d'étape réécrit avec la liste à jour, heure et empreinte gardées
#   Tâche-branche d'essaim (titre « — Branch ») et tâche déléguée à un projet lié (linked_unit, task-files.sh) : aucune
#   marque, jamais le temps de la session parente ; estimation et réel = somme des tâches de leur plan (celui du worktree
#   de leur branche, ou de la branche fille fusionnée), limitée aux tâches enfant (« ← parent Tn ») quand plusieurs tâches
#   parentes partagent la branche liée ; réel « — » sans plan ou avec une tâche faite non mesurée
#   Leur estimation : « · indicative » sur les fichiers déclarés tant que ce plan n'est pas écrit et estimé ; puis somme
#   de ses tâches, une seule fois, figée ; ses fichiers prévus remplacent les leurs (**Estimated files:**)
#   Délégué (agent_id) dont le cwd mène au journal d'une autre branche : marques dans ce journal, avec la branche du plan
#   et, hors du dépôt parent, son projet lié ; première écriture de son plan → ligne {"event":"delegate"} qui associe
#   l'agent à cette branche et à ce projet, sans le modèle
#   Sans journal (hook de mesure absent) : chaque tâche cochée sans **Actual time:** reçoit « — »
#   À chaque écriture du plan, après la mesure : tâche avec **Files:** sans **Estimated time:** estimée, en-tête
#   **Estimate:** ajouté s'il manque (estimation existante jamais recalculée) ; ## Summary réécrit depuis les tâches —
#   Task | Effort | Files | Estimated | Actual | Status, titre court d'une ligne gardé, ligne **Total**, ligne
#   **Remaining** des tâches ouvertes (retirée sans tâche ouverte) ; un seul appel time-calibrate.sh
#   Tâche de relecture (**Kind:** review) : « **Estimated time:** — » tant que time-calibrate.sh ne rend pas
#   d'estimation, remplacé par la première rendue si la tâche est encore ouverte, figée ensuite ; à « — », absente de
#   l'en-tête, de **Total** et des minutes de **Remaining**
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
# BUSINESS_RULE: une tâche à fichiers prévus cochée moins d'une minute après une autre, sans fichier changé, a été
#   menée avec elle
readonly BURST_MS=60000

# Une ligne « tâche<TAB>statut<TAB>écartée<TAB>réel_présent<TAB>fichiers prévus<TAB>unité » par tâche ### Tn, statut lu
# par TASK_STATUS_AWK ;
# unité : branche fille d'une tâche écartée, « projet @ branche » d'une tâche liée, vide sinon.
readonly PLAN_TASKS_PROGRAM="$TASK_STATUS_AWK$TASK_FILES_AWK"'
  function child_branch(title) { sub(/^.* — Branch /, "", title); gsub(/`/, "", title); sub(/ .*/, "", title); return title }
  function flush() { if (task != "") printf "%s\t%s\t%d\t%d\t%d\t%s\n", task, status, is_skipped, has_actual, planned_files_from(estimated_files_line, files_line), unit; task = "" }
                                   { sub(/\r$/, "") }
  is_task_heading($0)              { flush(); task = $2; status = "open"; is_skipped = ($0 ~ / — Branch /); has_actual = 0; estimated_files_line = ""; files_line = ""; unit = is_skipped ? child_branch($0) : ""; next }
  /^## /                           { flush(); next }
  task != "" && /^\*\*Actual time:\*\*/ { has_actual = 1 }
  task != "" && /^\*\*Estimated files:\*\*/ { estimated_files_line = $0 }
  task != "" && /^\*\*Files:\*\*/  { files_line = $0 }
  task != "" && unit == ""         { unit = linked_unit($0) }
  task != "" && is_status_line($0) { status = status_of($0) }
  END { flush() }'

# Réécrit **Actual time:** des tâches de « updates » (« tâche<TAB>valeur » par ligne) — un réel déjà mesuré (≈) n'est
# jamais remplacé par « — » (deux coches d'une même modification, simultanées pour la mesure), sauf tâche de « forced »
# (groupe d'une rafale de coches, séparé par des espaces) : ancienne ligne retirée,
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
    if (line ~ /^\*\*Actual time:\*\*/ && value[task] == "—" && line ~ /≈/ && !index(" " forced " ", " " task " ")) { delete anchor[task]; task = ""; next }
    if (line ~ /^\*\*Actual time:\*\*/) drop[FNR] = 1
    else if (line ~ /^\*\*Estimated time:\*\*/) { anchor[task] = FNR; has_estimate[task] = 1 }
    else if (line ~ /^\*\*Effort:\*\*/ && !(task in has_estimate)) anchor[task] = FNR
    next
  }
  FNR == 1 { for (task in anchor) inserted_after[anchor[task]] = task }
  !(FNR in drop) { print }
  FNR in inserted_after { print "**Actual time:** " value[inserted_after[FNR]] (($0 ~ /\r$/) ? "\r" : "") }'

# Somme des tâches du plan d une unité déléguée (branche fille ou liée) : celles qui répondent à « parent », toutes quand
# parent est vide. Une ligne « fichiers|estimation|réel » : estimation « ≈ m min (b-h) », vide tant qu une tâche à
# fichiers n est pas estimée ; réel au format d une tâche classique, vide sans tâche faite ou avec une tâche faite sans
# mesure ventilée — une tâche qui en regroupe d autres vaut la somme de ses tâches, rien d autre.
readonly UNIT_TASKS_PROGRAM="$TASK_STATUS_AWK$TASK_FILES_AWK"'
  function number_after(text, label,   rest) {
    if (!match(text, label)) return 0
    rest = substr(text, RSTART + RLENGTH)
    return match(rest, /[0-9]+(\.[0-9]+)?/) ? substr(rest, RSTART, RLENGTH) + 0 : 0
  }
  function add_estimate(text,   bounds) {
    if (!match(text, /\([0-9]+-[0-9]+\)/)) return 0
    split(substr(text, RSTART + 1, RLENGTH - 2), bounds, "-")
    minutes += number_after(text, "≈"); low += bounds[1]; high += bounds[2]
    return 1
  }
  function add_actual(text) {
    if (text !~ /≈ [0-9.]+ min agent \(incl\. [0-9.]+ min checks\) · human [0-9.]+ min \([0-9]+ questions\)/) return 0
    agent += number_after(text, "≈"); checks += number_after(text, "incl"); human += number_after(text, "human")
    questions += number_after(text, "human [0-9.]+ min")
    if (text ~ /· [0-9]+ files/) actual_files += number_after(text, "questions[)]"); else has_unknown_files = 1
    return 1
  }
  function flush(   planned) {
    if (is_counted && status != "dropped") {
      planned = planned_files_from(estimated_files_line, files_line); files += planned
      if (add_estimate(estimated_line)) estimated++
      else if (planned > 0 && !(is_review && estimated_line ~ /—$/)) is_estimate_missing = 1
      if (status == "done") { done++; if (!add_actual(actual_line)) is_measure_missing = 1 }
    }
    is_counted = 0
  }
  { sub(/\r$/, "") }
  is_task_heading($0) {
    flush(); status = "open"; estimated_files_line = files_line = estimated_line = actual_line = ""; traced = ""; is_review = 0
    if (match($0, /← parent T[0-9]+/)) { traced = substr($0, RSTART, RLENGTH); sub(/^.* /, "", traced) }
    is_counted = (parent == "" || traced == parent); next
  }
  /^## / { flush(); next }
  /^\*\*Estimated files:\*\*/ { estimated_files_line = $0 }
  /^\*\*Files:\*\*/ { files_line = $0 }
  /^\*\*Estimated time:\*\*/ { estimated_line = $0 }
  /^\*\*Actual time:\*\*/ { actual_line = $0 }
  is_review_kind($0) { is_review = 1 }
  is_status_line($0) { status = status_of($0) }
  END {
    flush()
    if (estimated && !is_estimate_missing) estimate = sprintf("≈ %d min (%d-%d)", minutes, low, high)
    if (done && !is_measure_missing) {
      actual = sprintf("≈ %.1f min agent (incl. %.1f min checks) · human %.1f min (%d questions)", agent, checks, human, questions)
      if (!has_unknown_files) actual = actual sprintf(" · %d files", actual_files)
      actual = actual sprintf(" · total ≈ %.1f min", agent + human)
    }
    printf "%d|%s|%s\n", files, estimate, actual
  }'

# Estimation indicative de la tâche « task » remplacée par « estimate », ses fichiers par « files » (0 → gardés).
readonly ADOPT_ESTIMATE_PROGRAM='
  { line = $0; eol = (line ~ /\r$/) ? "\r" : ""; sub(/\r$/, "", line) }
  line ~ /^### T[0-9]+/ { split(line, words, " "); is_target = (words[2] == task) }
  line ~ /^## / { is_target = 0 }
  is_target && line ~ /^\*\*Estimated time:\*\*/ { print "**Estimated time:** " estimate eol; next }
  is_target && files > 0 && line ~ /^\*\*Estimated files:\*\*/ { next }
  { print }
  is_target && files > 0 && line ~ /^\*\*Files:\*\*/ { print "**Estimated files:** " files eol }'

# Tâches à l estimation encore indicative, une par ligne.
readonly INDICATIVE_TASKS_PROGRAM="$TASK_STATUS_AWK"'
  { sub(/\r$/, "") }
  is_task_heading($0) { task = $2; next }
  /^## / { task = "" }
  task != "" && /^\*\*Estimated time:\*\*.* · indicative$/ { print task }'

# Inventaire du plan pour l'estimation : « task<TAB>id<TAB>fichiers<TAB>estimée 0/1<TAB>statut<TAB>code ou review<TAB>minutes
# basse haute »
# par tâche ### Tn, les trois nombres tirés de l'estimation écrite,
# puis « header<TAB>0/1 » (en-tête **Estimate:** présent).
readonly INVENTORY_PROGRAM="$TASK_STATUS_AWK$TASK_FILES_AWK"'
  function flush() {
    if (task != "") printf "task\t%s\t%d\t%d\t%s\t%s\t%s\n", task, planned_files_from(estimated_files_line, files_line), has_estimate, status, kind, bounds
    task = ""
  }
                                   { sub(/\r$/, "") }
  /^\*\*Estimate:\*\*/             { has_header = 1 }
  is_task_heading($0)              { flush(); task = $2; status = "open"; has_estimate = 0; kind = "code"; bounds = ""; estimated_files_line = ""; files_line = ""; next }
  /^## /                           { flush(); next }
  task == ""                       { next }
  /^\*\*Estimated time:\*\*/       { has_estimate = 1; if (match($0, /[0-9]+ min \([0-9]+-[0-9]+\)/)) { bounds = substr($0, RSTART, RLENGTH); gsub(/[^0-9]+/, " ", bounds) } }
  /^\*\*Estimated files:\*\*/      { estimated_files_line = $0 }
  /^\*\*Files:\*\*/                { files_line = $0 }
  is_review_kind($0)               { kind = "review" }
  is_status_line($0)               { status = status_of($0) }
  END { flush(); printf "header\t%d\n", has_header }'

# Réécriture du plan, lu deux fois (repérage, puis écriture) :
#   estimates (« id<TAB>≈ m min (b-h) » par ligne) → **Estimated time:** inséré sous **Effort:** ;
#   **Estimate:** recalculé depuis les estimations figées des tâches (fichiers de toutes les tâches, minutes et
#   fourchette sommées), mention indicative gardée ; absent → inséré sous **Date:**, indicatif si indicative vaut 1 ;
#   ## Summary → table régénérée à la place de ses lignes « | », texte libre gardé ; section ajoutée en fin si absente ;
#   **Total** calculé sur les seules tâches au réel mesuré, relecture sans estimation exclue : estimé et réel portent
#   sur les mêmes tâches ;
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
      if (!has_figure(id)) continue
      has_estimates = 1; minutes += first_number(estimated[id]); low += estimated_low[id]; high += estimated_high[id]
    }
    return has_estimates ? sprintf("≈ %d files · ≈ %d min (%d-%d)", total_files, minutes, low, high) : ""
  }
  function has_figure(id) { return estimated[id] != "" && estimated[id] != "—" }
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
      if (actual ~ /^≈/ && estimated[id] != "—") {
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
    for (id in new_estimate) if (!has_figure(id)) record_estimate(id, new_estimate[id])
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
  line ~ /^\*\*Estimated time:\*\* *—$/ && (current in new_estimate) { next }
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
declare -A PLANNED_FILES=()
BURST_TASKS=""
UNIT_FILES=0
UNIT_ESTIMATE=""
UNIT_ACTUAL=""
DONE_TASKS=""
MEASURABLE_DONE=()
UNMEASURED_DONE=()
HAD_CHECKPOINT=0
HAS_ADDED_TASK=0

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
# CHILD_BRANCHES (tâche-branche → branche fille), PLANNED_FILES (tâche → fichiers prévus).
read_plan_tasks() {
  local task status is_skipped has_actual planned unit
  while IFS=$'\t' read -r task status is_skipped has_actual planned unit; do
    PLANNED_FILES[$task]=$planned
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

# Tâches du plan de l'unité déléguée de <tâche>, additionnées : UNIT_FILES, UNIT_ESTIMATE, UNIT_ACTUAL, vides sans plan.
# Branche liée partagée par plusieurs tâches parentes → seules les tâches enfant de <tâche> ; sinon toutes.
read_unit() {
  local parent="" plan
  UNIT_FILES=0; UNIT_ESTIMATE=""; UNIT_ACTUAL=""
  unit_plan_of "$1"
  plan=$REPLY
  [ -n "$plan" ] || return 0
  if [ -n "${LINKED_UNITS[$1]:-}" ]; then
    count_unit_tasks "${LINKED_UNITS[$1]}"
    [ "$REPLY" -gt 1 ] && parent=$1
  fi
  IFS='|' read -r UNIT_FILES UNIT_ESTIMATE UNIT_ACTUAL < <(awk -v parent="$parent" "$UNIT_TASKS_PROGRAM" "$plan")
}

# Réel d'une tâche-branche ou liée dans REPLY : somme des réels de ses tâches, « — » sans mesure complète.
measure_unit_task() {
  read_unit "$1"
  REPLY=${UNIT_ACTUAL:-$NO_MEASURE}
}

# Coche qui suit la précédente de moins de BURST_MS, dossier inchangé : le point d'étape est bien celui de cette coche
# (jamais celui d'une livraison ni d'un ajout de tâche), LAST_* lus. Hors git, rien ne dit que le dossier est inchangé.
# Usage : is_burst <maintenant> <empreinte en chaîne JSON, vide hors git>
is_burst() {
  [ -n "$2" ] && [ "$2" = "$CHECKPOINT_FILES" ] || return 1
  [ $(($1 - CHECKPOINT_TS)) -lt "$BURST_MS" ] || return 1
  read_last_task_marks "$TIME_LOG" "$MARK_BRANCH" "$MARK_PROJECT" || return 1
  [ "$LAST_DONE_TS" = "$CHECKPOINT_TS" ]
}

# Tâches du groupe de la coche précédente (LAST_GROUP), encore cochées, hors tâches passées en arguments, dans REPLY.
burst_companions() {
  local task companions=""
  for task in $LAST_GROUP; do
    is_in_list "$task" "$DONE_TASKS" && ! is_in_list "$task" "$*" && companions+="${companions:+ }$task"
  done
  REPLY=$companions
}

# Marques des tâches nouvellement cochées, nouveau point d'étape, puis réel de chacune ; « tâche<TAB>réel » dans REPLY.
# Rafale : départ de la coche précédente repris, réel du reste de son groupe réécrit lui aussi (BURST_TASKS).
mark_new_tasks() {
  local now files_json="" task updates="" is_burst_tick=0 has_joined=0 start_ts start_files measured=("$@")
  current_time_ms || return 1
  now=$REPLY
  if snapshot_files "$ROOT"; then
    json_escape "$REPLY"
    files_json=$REPLY
  fi
  is_burst "$now" "$files_json" && is_burst_tick=1
  for task in "$@"; do
    start_ts=$CHECKPOINT_TS; start_files=$CHECKPOINT_FILES
    if [ "$is_burst_tick" = 1 ] && [ "${PLANNED_FILES[$task]:-0}" -gt 0 ]; then
      start_ts=$LAST_START_TS; start_files=$LAST_START_FILES; has_joined=1
    fi
    task_mark_line "$start_ts" task_start "$task" "$MARK_BRANCH" "$start_files" "$MARK_PROJECT"
    printf '%s\n' "$REPLY" >> "$TIME_LOG"
    task_mark_line "$now" task_done "$task" "$MARK_BRANCH" "$files_json" "$MARK_PROJECT"
    printf '%s\n' "$REPLY" >> "$TIME_LOG"
  done
  append_checkpoint "$TIME_LOG" "$now" "$DONE_TASKS" "$files_json" "$MARK_BRANCH" "$MARK_PROJECT"
  if [ "$has_joined" = 1 ]; then
    burst_companions "$@"
    BURST_TASKS=$REPLY
    # shellcheck disable=SC2206 — découpage voulu de la liste de tâches
    measured=($BURST_TASKS "$@")
  fi
  for task in "${measured[@]}"; do
    measure_task "$task"
    updates+="$task"$'\t'"$REPLY"$'\n'
  done
  REPLY=$updates
}

# Coches comparées au dernier point d'étape ; « tâche<TAB>réel » des tâches à écrire dans REPLY, vide sinon.
measure_ticks() {
  local task new_tasks=() unit_tasks=() has_new_tick=0 updates
  REPLY=""
  if ! read_last_checkpoint "$TIME_LOG" "$MARK_BRANCH" "$MARK_PROJECT"; then
    current_time_ms || return 0
    local now=$REPLY
    snapshot_files "$ROOT" && json_escape "$REPLY" || REPLY=""
    append_checkpoint "$TIME_LOG" "$now" "$DONE_TASKS" "$REPLY" "$MARK_BRANCH" "$MARK_PROJECT"
    REPLY=""
    return 0
  fi
  HAD_CHECKPOINT=1
  [ "$DONE_TASKS" = "$CHECKPOINT_DONE" ] && return 0
  for task in $DONE_TASKS; do
    is_in_list "$task" "$CHECKPOINT_DONE" && continue
    has_new_tick=1
    is_in_list "$task" "${MEASURABLE_DONE[*]}" && new_tasks+=("$task")
    is_unit_task "$task" && unit_tasks+=("$task")
  done
  if [ "$has_new_tick" = 0 ]; then
    append_checkpoint "$TIME_LOG" "$CHECKPOINT_TS" "$DONE_TASKS" "$CHECKPOINT_FILES" "$MARK_BRANCH" "$MARK_PROJECT"
    return 0
  fi
  mark_new_tasks "${new_tasks[@]}" || { REPLY=""; return 0; }
  updates=$REPLY
  for task in "${unit_tasks[@]}"; do
    measure_unit_task "$task"
    updates+="$task"$'\t'"$REPLY"$'\n'
  done
  REPLY=$updates
}

# Point d'étape avancé à l'entrée d'une tâche au plan, sans tâche en cours ; déjà écrit par une coche ou un premier
# passage de la même écriture → rien.
restart_for_added_task() {
  local now files_json=""
  [ "$HAD_CHECKPOINT" = 1 ] && [ "$HAS_ADDED_TASK" = 1 ] && [ "$DONE_TASKS" = "$CHECKPOINT_DONE" ] || return 0
  snapshot_files "$ROOT" && { json_escape "$REPLY"; files_json=$REPLY; }
  is_code_untouched "$files_json" || return 0
  current_time_ms || return 0
  now=$REPLY
  append_checkpoint "$TIME_LOG" "$now" "$DONE_TASKS" "$files_json" "$MARK_BRANCH" "$MARK_PROJECT"
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
  content=$(awk -v updates="$1" -v forced="$BURST_TASKS" "$ACTUAL_TIME_PROGRAM" "$PLAN" "$PLAN") || return 1
  [ -n "$content" ] || return 1
  printf '%s\n' "$content" > "$PLAN"
}

# Plan de l'unité déléguée de <tâche> dans REPLY, vide sans plan : worktree qui extrait sa branche ; à défaut, pour une
# branche fille fusionnée, son dossier dans le dépôt parent.
unit_plan_of() {
  local directory=$ROOT branch=${CHILD_BRANCHES[$1]:-} unit=${LINKED_UNITS[$1]:-} candidate
  if [ -n "$unit" ]; then
    directory=${unit% @ *}; branch=${unit##* @ }
    [[ $directory == /* || $directory == [A-Za-z]:* ]] || directory="$ROOT/$directory"
  fi
  REPLY=""
  [ -n "$branch" ] || return 0
  worktree_of_branch "$directory" "$branch"
  for candidate in "$REPLY" "${CHILD_BRANCHES[$1]:+$ROOT}"; do
    REPLY="$candidate/.forge/branch/$branch/plan.md"
    [ -n "$candidate" ] && [ -f "$REPLY" ] && return 0
  done
  REPLY=""
}

# Tâche qui en regroupe d'autres : tâche-branche ou tâche liée.
is_unit_task() {
  [ -n "${LINKED_UNITS[$1]:-}${CHILD_BRANCHES[$1]:-}" ]
}

# Estimations indicatives des tâches-branches et liées dont le plan est écrit : somme de ses tâches, une seule fois.
adopt_unit_estimates() {
  local task content
  while IFS= read -r task; do
    is_unit_task "$task" || continue
    read_unit "$task"
    [ -n "$UNIT_ESTIMATE" ] || continue
    content=$(awk -v task="$task" -v files="$UNIT_FILES" -v estimate="$UNIT_ESTIMATE" "$ADOPT_ESTIMATE_PROGRAM" "$PLAN")
    [ -n "$content" ] && printf '%s\n' "$content" > "$PLAN"
  done < <(awk "$INDICATIVE_TASKS_PROGRAM" "$PLAN")
}

# Estimation de chaque tâche, une valeur par tâche : TASK_MINUTES, TASK_LOW, TASK_HIGH (dans l'ordre, vides pour une
# relecture sans estimation) ; INDICATIVE pour un en-tête neuf. Un seul appel ; une liste d'une valeur ne rend que
# « estimate ».
calibrate() {
  local result estimates pattern='(null|\{"files":[0-9]+,"minutes":([0-9]+),"low":([0-9]+),"high":([0-9]+)\})'
  TASK_MINUTES=(); TASK_LOW=(); TASK_HIGH=(); INDICATIVE=0
  result=$(bash "$SCRIPT_DIR/time-calibrate.sh" --root "$ROOT" --files "$1") || return 1
  [[ $result == *'"indicative":true'* ]] && INDICATIVE=1
  [[ ${result#*\"estimate\":} =~ ^$pattern ]] || return 1
  estimates=${result#*\"estimate\":}
  [[ $result == *'"estimates":['* ]] && estimates=${result#*\"estimates\":[}
  while [[ $estimates =~ ^,?$pattern ]]; do
    TASK_MINUTES+=("${BASH_REMATCH[2]}"); TASK_LOW+=("${BASH_REMATCH[3]}"); TASK_HIGH+=("${BASH_REMATCH[4]}")
    estimates=${estimates#"${BASH_REMATCH[0]}"}
    [[ $result == *'"estimates":['* ]] || break
  done
  [ ${#TASK_MINUTES[@]} -gt 0 ]
}

# Inventaire du plan, une case par tâche : TASK_IDS, TASK_FILE_COUNTS, TASK_VALUES (fichiers, ou « review »), TASK_IS_OPEN,
# TASK_IS_MISSING (estimation à écrire : fichiers sans estimation, ou relecture ouverte à « — ») ; HAS_HEADER, HAS_OPEN,
# HAS_MISSING. Une tâche qui en regroupe d'autres n'est jamais une relecture : elle vaut la somme de ses tâches.
read_inventory() {
  local kind id files has_estimate status task_kind bounds
  TASK_IDS=(); TASK_FILE_COUNTS=(); TASK_VALUES=(); TASK_IS_OPEN=(); TASK_IS_MISSING=(); TASK_BOUNDS=()
  HAS_HEADER=1; HAS_OPEN=0; HAS_MISSING=0; HAS_ADDED_TASK=0
  while IFS=$'\t' read -r kind id files has_estimate status task_kind bounds; do
    [ "$kind" = "header" ] && { HAS_HEADER=$id; continue; }
    is_unit_task "$id" && task_kind=code
    TASK_IDS+=("$id"); TASK_FILE_COUNTS+=("$files"); TASK_BOUNDS+=("$bounds")
    if [ "$task_kind" = review ]; then TASK_VALUES+=(review); else TASK_VALUES+=("$files"); fi
    if [ "$status" = "open" ]; then TASK_IS_OPEN+=(1); HAS_OPEN=1; else TASK_IS_OPEN+=(0); fi
    if [ "$has_estimate" = 0 ] && { [ "$files" -gt 0 ] || [ "$task_kind" = review ]; }; then
      TASK_IS_MISSING+=(1); HAS_MISSING=1
      [ "$status" = "open" ] && HAS_ADDED_TASK=1
    elif [ "$task_kind" = review ] && [ -z "$bounds" ] && [ "$status" = "open" ]; then
      TASK_IS_MISSING+=(1); HAS_MISSING=1
    else
      TASK_IS_MISSING+=(0)
    fi
  done < <(awk "$INVENTORY_PROGRAM" "$PLAN")
}

# Estimation à écrire pour la tâche de rang <rang> dans REPLY : « — » pour une relecture sans mesure suffisante, ou déjà
# terminée — une estimation se fige avant la tâche, jamais après.
new_estimate_of() {
  local index=$1
  REPLY=$NO_MEASURE
  [ -n "${TASK_MINUTES[index]}" ] || return 0
  [ "${TASK_VALUES[index]}" = review ] && [ "${TASK_IS_OPEN[index]}" = 0 ] && return 0
  REPLY="≈ ${TASK_MINUTES[index]} min (${TASK_LOW[index]}-${TASK_HIGH[index]})"
  is_unit_task "${TASK_IDS[index]}" && REPLY+=" · indicative"
  return 0
}

# Valeurs de la réécriture : NEW_ESTIMATES, REMAINING, INDICATIVE (en-tête absent). Un seul appel de calibration, une valeur par
# tâche : le reste à faire additionne les tâches ouvertes, chacune avec son coût fixe de vérification ; une relecture sans
# estimation n'y ajoute aucune minute.
compute_estimates() {
  local index minutes low high open_files=0 open_minutes=0 open_low=0 open_high=0
  NEW_ESTIMATES=""; REMAINING=""; INDICATIVE=0
  read_inventory
  [ "$HAS_OPEN" = 1 ] || [ "$HAS_HEADER" = 0 ] || [ "$HAS_MISSING" = 1 ] || return 0
  [ ${#TASK_IDS[@]} -gt 0 ] || return 0
  calibrate "$(IFS=,; echo "${TASK_VALUES[*]}")" || return 0
  for index in "${!TASK_IDS[@]}"; do
    if [ "${TASK_IS_MISSING[index]}" = 1 ]; then
      new_estimate_of "$index"
      NEW_ESTIMATES+="${TASK_IDS[index]}"$'\t'"$REPLY"$'\n'
    fi
    [ "${TASK_IS_OPEN[index]}" = 1 ] || continue
    minutes=${TASK_MINUTES[index]:-0}; low=${TASK_LOW[index]:-0}; high=${TASK_HIGH[index]:-0}
    # BUSINESS_RULE: tâche qui en regroupe d'autres = somme de ses tâches, son estimation écrite, jamais un recalcul sur ses fichiers
    is_unit_task "${TASK_IDS[index]}" && [ -n "${TASK_BOUNDS[index]}" ] && read -r minutes low high <<< "${TASK_BOUNDS[index]}"
    open_files=$((open_files + TASK_FILE_COUNTS[index]))
    open_minutes=$((open_minutes + minutes))
    open_low=$((open_low + low)); open_high=$((open_high + high))
  done
  [ "$HAS_OPEN" = 1 ] || return 0
  REMAINING="$open_files"$'\t'"$NO_MEASURE"
  [ "$open_minutes" -gt 0 ] && REMAINING="$open_files"$'\t'"≈ $open_minutes min ($open_low-$open_high)"
  return 0
}

# Estimations et ## Summary réécrits ; rend 0 seulement si plan.md a changé.
refresh_summary() {
  local current content
  current=$(cat "$PLAN")
  adopt_unit_estimates
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
  restart_for_added_task
  check_deployment_script
  report_to_model "$updates" "$is_rewritten" "$REPLY"
}

main
exit 0
