#!/bin/bash
# Calibration de l'estimation : ratios et fourchette tirés des tâches mesurées des plans, coûts fixes d'un essaim tirés
# des synthèses metrics.json des branches, valeurs de référence du skill à défaut.
#   Lecture seule : aucune écriture
#   Rend compte en JSON sur une ligne — la mise en page revient au skill
#   Échantillon : les 40 dernières tâches mesurées (plan.md des branches, branches filles comprises ; tâche-branche et
#   tâche déléguée écartées), des plus récentes aux plus anciennes
#   r (minutes par fichier) et erreur de prévision des fichiers : médianes des tâches mesurées avec leurs fichiers,
#   dès 20 (source tasks) ; erreur appliquée si elle s'écarte de plus de 20 % de 1 ; référence sinon
#   Fourchette : 20e et 80e centiles du rapport durée réelle ÷ durée estimée, dès 20 tâches (range_source)
#   Coûts fixes d'un essaim (delegate_minutes, merge_minutes) : médiane des 5 dernières mesures des branches
#   Coût fixe de vérification par tâche (check_minutes) : médiane de la part « min checks » des réels, dès 20 tâches qui
#   la portent (check_source tasks) ; référence sinon. r se calcule alors sur le réel moins cette part
#   Estimation d'une tâche : check_minutes + fichiers × r ; d'une liste : somme des tâches. 1 minute au moins, bornes
#   de la fourchette comprises ; indicative tant que ratios ou fourchette viennent de la référence
# Usage : time-calibrate.sh [--root <dir>] [--files <n>[,<n>…]] [--groups <n>[/<t>],<n>[/<t>][,…] [--slots <n>]]
#   --files : nombre de fichiers à estimer — ajoute un objet "estimate" (minutes et fourchette) ;
#   liste séparée par des virgules (une valeur par tâche d'un plan) → "estimate" porte sur la somme,
#   "estimates" donne une estimation par valeur, dans l'ordre
#   --groups : fichiers de chaque groupe retenu pour un plan de branches, suivis de « /<tâches> » (1 à défaut),
#   séparés par des virgules — chaque tâche du groupe paie son coût fixe de vérification — ajoute
#   un objet "swarm" : durée en série, durée en essaim et coût fixe ; --slots : délégués en
#   parallèle (3 à défaut). Essaim = chaque branche dure ses minutes + delegate_minutes, réparties sur les
#   délégués (la plus longue d'abord), puis une fusion de merge_minutes par branche, l'une après l'autre ;
#   dépendances ignorées : estimation optimiste
# Sortie : 0 JSON écrit · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/task-files.sh"

readonly EXIT_USAGE=1
readonly REFERENCE_FILE="$(dirname "${BASH_SOURCE[0]}")/../references/estimation.json"
readonly RECENT_FOR_RATIOS=5
readonly FILE_ERROR_TOLERANCE=0.2
readonly RECENT_FOR_RANGE=40
readonly MIN_RANGE_TASKS=20
readonly RANGE_LOW_PERCENTILE=0.2
readonly RANGE_HIGH_PERCENTILE=0.8
readonly DEFAULT_SLOTS=3

# Une ligne par synthèse : « date mise_en_route fusion », null gardé tel quel — les branches ne fournissent que les
# coûts fixes d'un essaim, mesurés à cette seule échelle ;
# synthèse « partial » écartée : sa mesure ne couvre pas toute la branche.
readonly METRICS_PROGRAM='
  function field(name,   pattern) {
    pattern = "\"" name "\":(\"[^\"]*\"|[0-9.]+|null)"
    if (!match($0, pattern)) return "null"
    value = substr($0, RSTART + length(name) + 3, RLENGTH - length(name) - 3)
    gsub(/"/, "", value)
    return value
  }
  /"partial":true/ { next }
  { printf "%s %s %s\n", field("date"), field("delegate_setup_minutes"), field("merge_minutes") }'

# Une ligne par tâche mesurée d'un plan : « date<TAB>rang<TAB>réel ÷ estimé<TAB>minutes réelles<TAB>fichiers réels
# (- sans mesure)<TAB>fichiers prévus<TAB>minutes de vérification (- pour un réel antérieur à leur mesure) ». Tâche gardée quand elle porte un **Estimated time:** et un **Actual time:**
# chiffré ; écartées : tâche-branche d'essaim et tâche déléguée à un projet lié, dont le réel additionne plusieurs tâches.
readonly TASK_SAMPLES_PROGRAM="$TASK_FILES_AWK"'
  function minutes_of(line) {
    sub(/^\*\*[A-Za-z ]+:\*\* */, "", line)
    return match(line, /[0-9]+(\.[0-9]+)?/) ? substr(line, RSTART, RLENGTH) + 0 : 0
  }
  function flush(   planned) {
    planned = planned_files_from(estimated_files_line, files_line)
    if (in_task && !is_aggregate && estimated > 0 && actual > 0)
      printf "%s\t%04d\t%s\t%s\t%s\t%d\t%s\n", date, order, actual / estimated, actual, actual_files, planned, checks
    in_task = 0
  }
  FNR == 1 { flush(); date = "0000-00-00"; order = 0 }
  { sub(/\r$/, "") }
  /^\*\*Date:\*\*/ && date == "0000-00-00" { date = $0; sub(/^\*\*Date:\*\* */, "", date); date = substr(date, 1, 10) }
  /^### T[0-9]+/ {
    flush(); in_task = 1; order++; is_aggregate = ($0 ~ / Branch /)
    estimated = 0; actual = 0; actual_files = "-"; checks = "-"; estimated_files_line = ""; files_line = ""; next
  }
  /^## / { flush(); next }
  in_task && /^\*\*Estimated time:\*\*/ { estimated = minutes_of($0) }
  in_task && /^\*\*Actual time:\*\*/ {
    actual = minutes_of($0)
    if (match($0, /[0-9]+ files/)) actual_files = substr($0, RSTART, RLENGTH) + 0
    if (match($0, /[0-9]+(\.[0-9]+)? min checks/)) checks = substr($0, RSTART, RLENGTH) + 0
  }
  in_task && /^\*\*Estimated files:\*\*/ { estimated_files_line = $0 }
  in_task && /^\*\*Files:\*\*/ { files_line = $0 }
  in_task && /delegated to / { is_aggregate = 1 }
  END { flush() }'

# Calibrage par tâche sur les échantillons triés du plus récent au plus ancien, « - » pour une valeur absente :
#   « écarts basse haute tâches_à_fichiers minutes_par_fichier erreur_fichiers vérifications » ; bornes, ratios et
#   vérifications absents sous le minimum. Minutes par fichier sur le réel moins les vérifications quand il les porte.
readonly TASK_CALIBRATION_PROGRAM='
  # Centile p (0 à 1) de valeurs triées en place, interpolé entre les deux rangs voisins.
  function percentile(values, count, p,   i, j, swap, position, below) {
    for (i = 2; i <= count; i++) for (j = i; j > 1 && values[j - 1] > values[j]; j--) { swap = values[j]; values[j] = values[j - 1]; values[j - 1] = swap }
    position = 1 + (count - 1) * p
    below = int(position)
    return below >= count ? values[count] : values[below] + (position - below) * (values[below + 1] - values[below])
  }
  { gaps[++gap_count] = $3 }
  $7 != "-" { check_values[++check_count] = $7 }
  $5 != "-" && $5 > 0 && $6 > 0 && $4 - ($7 != "-" ? $7 : 0) > 0 {
    ++file_count; rates[file_count] = ($4 - ($7 != "-" ? $7 : 0)) / $5; errors[file_count] = $5 / $6
  }
  END {
    low = high = rate = error = check = "-"
    if (gap_count >= min_tasks) { low = percentile(gaps, gap_count, low_percentile); high = percentile(gaps, gap_count, high_percentile) }
    if (file_count >= min_tasks) { rate = percentile(rates, file_count, 0.5); error = percentile(errors, file_count, 0.5) }
    if (check_count >= min_tasks) check = percentile(check_values, check_count, 0.5)
    printf "%d %s %s %d %s %s %s\n", gap_count, low, high, file_count, rate, error, check
  }'

# Calcul sur les synthèses triées de la plus récente à la plus ancienne.
readonly CALIBRATION_PROGRAM='
  function median(values, count,   i, j, swap) {
    for (i = 2; i <= count; i++) for (j = i; j > 1 && values[j - 1] > values[j]; j--) { swap = values[j]; values[j] = values[j - 1]; values[j - 1] = swap }
    return count % 2 ? values[(count + 1) / 2] : (values[count / 2] + values[count / 2 + 1]) / 2
  }
  # BUSINESS_RULE: chaque tâche paie ses vérifications, quel que soit son nombre de fichiers
  function estimate_object(files, r, correction, tasks,   minutes) {
    minutes = tasks * check_minutes + files * correction * r
    return sprintf("{\"files\":%d,\"minutes\":%d,\"low\":%d,\"high\":%d}", files, whole_minutes(minutes), whole_minutes(minutes * low), whole_minutes(minutes * high))
  }
  # Estimation de la somme, puis une par valeur quand la liste en compte plusieurs.
  function render_estimates(files, r, correction,   count, values, i, total) {
    count = split(files, values, ",")
    for (i = 1; i <= count; i++) total += values[i]
    printf ",\"estimate\":%s", estimate_object(total, r, correction, count)
    if (count < 2) return
    printf ",\"estimates\":["
    for (i = 1; i <= count; i++) printf "%s%s", (i > 1 ? "," : ""), estimate_object(values[i], r, correction, 1)
    printf "]"
  }
  # Gain estimé de tout essaim : groupes triés du plus long au plus court, chacun confié au délégué le moins chargé.
  function render_swarm(groups, r, correction,   count, values, i, j, swap, load, slot, best, serial, parallel, fixed, parts) {
    count = split(groups, values, ",")
    for (i = 1; i <= count; i++) {
      if (split(values[i], parts, "/") < 2) parts[2] = 1
      values[i] = parts[2] * check_minutes + parts[1] * correction * r; serial += values[i]
    }
    for (i = 2; i <= count; i++) for (j = i; j > 1 && values[j - 1] < values[j]; j--) { swap = values[j]; values[j] = values[j - 1]; values[j - 1] = swap }
    for (slot = 1; slot <= slots; slot++) load[slot] = 0
    for (i = 1; i <= count; i++) {
      best = 1
      for (slot = 2; slot <= slots; slot++) if (load[slot] < load[best]) best = slot
      load[best] += values[i] + delegate_minutes
    }
    for (slot = 1; slot <= slots; slot++) if (load[slot] > parallel) parallel = load[slot]
    parallel += count * merge_minutes
    fixed = count * (delegate_minutes + merge_minutes)
    printf ",\"swarm\":{\"branches\":%d,\"slots\":%d,\"serial_minutes\":%d,\"swarm_minutes\":%d,\"fixed_minutes\":%d}", count, slots, whole_minutes(serial), whole_minutes(parallel), fixed
  }
  # Minutes entières, au moins une : une estimation à 0 min ne dit rien.
  function whole_minutes(value,   rounded) {
    rounded = sprintf("%.0f", value) + 0
    return rounded < 1 ? 1 : rounded
  }
  $2 != "null" && setup_count < recent_ratios { setups[++setup_count] = $2 }
  $3 != "null" && merge_count < recent_ratios { merge_costs[++merge_count] = $3 }
  END {
    # BUSINESS_RULE: ratios et fourchette viennent des seules tâches, unité du plan — prévu et réel y sont comptés de la
    # même façon ; sous 10 tâches mesurées, valeurs de référence, sans repli sur les branches
    r = reference_r; file_error = 1; has_rates = (task_rate != "-")
    if (has_rates) { r = task_rate; file_error = task_error }
    if (task_low != "-") { low = task_low; high = task_high }
    if (setup_count) delegate_minutes = median(setups, setup_count)
    if (merge_count) merge_minutes = median(merge_costs, merge_count)
    apply = (has_rates && (file_error > 1 + tolerance || file_error < 1 - tolerance)) ? 1 : 0
    indicative = (has_rates && task_low != "-") ? "false" : "true"
    printf "{\"minutes_per_file\":%.2f,", r
    printf "\"file_error\":%s,\"apply_file_error\":%s,", (has_rates ? sprintf("%.2f", file_error) : "null"), (apply ? "true" : "false")
    printf "\"indicative\":%s,", indicative
    printf "\"source\":\"%s\",\"range_source\":\"%s\",", (has_rates ? "tasks" : "reference"), (task_low != "-" ? "tasks" : "reference")
    printf "\"delegate_minutes\":%s,\"merge_minutes\":%s,", delegate_minutes + 0, merge_minutes + 0
    printf "\"fixed_costs_source\":\"%s\",", ((setup_count || merge_count) ? "project" : "reference")
    if (task_check != "-") check_minutes = task_check
    printf "\"check_minutes\":%.1f,\"check_source\":\"%s\"", check_minutes, (task_check != "-" ? "tasks" : "reference")
    if (files != "") render_estimates(files, r, apply ? file_error : 1)
    if (groups != "") render_swarm(groups, r, apply ? file_error : 1)
  }'

ROOT="."
FILES=""
BRANCH_GROUPS=""
SLOTS=$DEFAULT_SLOTS

fail_usage() {
  echo "time-calibrate: $1" >&2
  echo "usage: time-calibrate.sh [--root <dir>] [--files <n>[,<n>…]] [--groups <n>[/<t>],<n>[/<t>][,…] [--slots <n>]]" >&2
  exit $EXIT_USAGE
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root)  [ $# -ge 2 ] || fail_usage "$1 needs a value"; ROOT=$2; shift 2 ;;
      --files) [ $# -ge 2 ] || fail_usage "$1 needs a value"; FILES=$2; shift 2 ;;
      --groups) [ $# -ge 2 ] || fail_usage "$1 needs a value"; BRANCH_GROUPS=$2; shift 2 ;;
      --slots) [ $# -ge 2 ] || fail_usage "$1 needs a value"; SLOTS=$2; shift 2 ;;
      *)       fail_usage "unknown argument $1" ;;
    esac
  done
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
  [[ -z $FILES || $FILES =~ ^[0-9]+(,[0-9]+)*$ ]] || fail_usage "--files needs whole numbers separated by commas"
  [[ -z $BRANCH_GROUPS || $BRANCH_GROUPS =~ ^[0-9]+(/[1-9][0-9]*)?(,[0-9]+(/[1-9][0-9]*)?)*$ ]] \
    || fail_usage "--groups needs <files>[/<tasks>] values separated by commas"
  [[ $SLOTS =~ ^[1-9][0-9]*$ ]] || fail_usage "--slots needs a positive whole number"
}

# Valeur numérique d'un champ du fichier de référence, dans REPLY.
read_reference() {
  local content pattern="\"$1\": *([0-9.]+)"
  content=$(<"$REFERENCE_FILE")
  [[ $content =~ $pattern ]] && REPLY=${BASH_REMATCH[1]}
}

# Calibrage par tâche, sortie de TASK_CALIBRATION_PROGRAM dans REPLY ; « 0 - - 0 - - - » sans plan.
read_task_calibration() {
  local branch_dir="$ROOT/.forge/branch"
  REPLY="0 - - 0 - - -"
  [ -d "$branch_dir" ] || return 0
  REPLY=$(find "$branch_dir" -name plan.md -exec awk "$TASK_SAMPLES_PROGRAM" {} + \
    | LC_ALL=C sort -t$'\t' -k1,1r -k2,2r | head -n "$RECENT_FOR_RANGE" \
    | awk -F '\t' -v min_tasks=$MIN_RANGE_TASKS -v low_percentile=$RANGE_LOW_PERCENTILE \
        -v high_percentile=$RANGE_HIGH_PERCENTILE "$TASK_CALIBRATION_PROGRAM")
}

# Synthèses du projet, de la plus récente à la plus ancienne (date AAAA-MM-JJ, tri lexical).
list_metrics() {
  local branch_dir="$ROOT/.forge/branch"
  [ -d "$branch_dir" ] || return 0
  find "$branch_dir" -name metrics.json -exec awk "$METRICS_PROGRAM" {} + | sort -r
}

main() {
  local reference_r low high delegate_minutes merge_minutes check_minutes task_count task_low task_high file_count task_rate task_error task_check
  parse_arguments "$@"
  read_reference minutes_per_file; reference_r=$REPLY
  read_reference delegate_minutes; delegate_minutes=$REPLY
  read_reference merge_minutes; merge_minutes=$REPLY
  read_reference check_minutes; check_minutes=$REPLY
  read_reference range_low; low=$REPLY
  read_reference range_high; high=$REPLY
  read_task_calibration
  read -r task_count task_low task_high file_count task_rate task_error task_check <<< "$REPLY"
  list_metrics | awk -v reference_r="$reference_r" -v low="$low" -v high="$high" \
    -v files="$FILES" -v groups="$BRANCH_GROUPS" -v slots="$SLOTS" -v delegate_minutes="$delegate_minutes" \
    -v merge_minutes="$merge_minutes" -v recent_ratios=$RECENT_FOR_RATIOS -v task_low="$task_low" -v task_high="$task_high" \
    -v task_rate="$task_rate" -v task_error="$task_error" -v check_minutes="$check_minutes" -v task_check="$task_check" \
    -v tolerance=$FILE_ERROR_TOLERANCE "$CALIBRATION_PROGRAM"
  # Seuil de la règle de branche, recopié tel quel : les bornes de la fourchette servent au calcul, jamais recopiées
  read_reference branch_minutes
  printf ',"branch_minutes":%s}\n' "$REPLY"
}

main "$@"
