#!/bin/bash
# Calibration de l'estimation : ratios et fourchette tirés des tâches mesurées des plans, valeurs de référence du skill
# à défaut.
#   Lecture seule : aucune écriture
#   Rend compte en JSON sur une ligne — la mise en page revient au skill
#   Échantillon : les 40 dernières tâches mesurées (plan.md des branches, branches filles comprises ; tâche-branche et
#   tâche déléguée écartées), des plus récentes aux plus anciennes
#   r (minutes par fichier) et erreur de prévision des fichiers : médianes des tâches mesurées avec leurs fichiers,
#   dès 20 (source tasks) ; erreur appliquée si elle s'écarte de plus de 20 % de 1 ; référence sinon
#   Fourchette : 20e et 80e centiles du rapport durée réelle ÷ durée estimée, dès 20 tâches (range_source)
#   Coût de vérification par tâche (check_minutes) : 0 au départ, puis médiane de la part « min checks » des réels, dès
#   20 tâches qui la portent (check_source tasks). r se calcule sur le réel moins cette part
#   Tâche de relecture (**Kind:** review, task-files.sh) : absente de tout ce qui précède ; sa durée ne dépend pas de ses
#   fichiers, son estimation est la médiane des 40 dernières tâches de relecture mesurées, fourchette aux mêmes
#   centiles, dès 2 ; « null » avant, hors de la somme
#   Estimation d'une tâche : check_minutes + fichiers × r ; d'une liste : somme des tâches. 1 minute au moins, bornes
#   de la fourchette comprises ; indicative tant que ratios ou fourchette viennent de la référence
# Usage : time-calibrate.sh [--root <dir>] [--files <n|review>[,<n|review>…]] [--groups <n>[/<t>],<n>[/<t>][,…] [--slots <n>] [--parent <n>[/<t>]]]
#   --files : nombre de fichiers à estimer — ajoute un objet "estimate" (minutes et fourchette) ;
#   liste séparée par des virgules (une valeur par tâche d'un plan) → "estimate" porte sur la somme,
#   "estimates" donne une estimation par valeur, dans l'ordre ; valeur « review » : tâche de relecture, 0 fichier
#   --groups : fichiers de chaque groupe retenu pour un plan de branches, suivis de « /<tâches> » (1 à défaut),
#   séparés par des virgules — chaque tâche du groupe paie son coût fixe de vérification — ajoute
#   un objet "swarm" : durée en série et durée en essaim ; --slots : délégués en parallèle (3 à défaut).
#   Essaim = travail seul des branches, réparties sur les délégués (la plus longue d'abord) ; lancement, fusions et
#   dépendances ignorés : estimation optimiste
#   --parent (avec --groups) : fichiers et tâches ordinaires que le parent mène pendant l'essaim — une voie de plus ;
#   série = branches + parent ; essaim = la plus longue des voies ;
#   ajoute "parent_minutes" à l'objet "swarm"
#   branch_minutes : seuil de la règle de branche (référence) ; branch_files : fichiers d'un groupe à ce seuil,
#   branch_minutes ÷ minutes par fichier appliquées, arrondi au-dessus
# Sortie : 0 JSON écrit · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/task-files.sh"

readonly EXIT_USAGE=1
readonly REFERENCE_FILE="$(dirname "${BASH_SOURCE[0]}")/../references/estimation.json"
readonly FILE_ERROR_TOLERANCE=0.2
readonly RECENT_FOR_RANGE=40
readonly MIN_RANGE_TASKS=20
# BUSINESS_RULE: une relecture est estimée dès deux mesures — sans elles, aucune valeur de référence ne la représente
readonly MIN_REVIEW_TASKS=2
readonly RANGE_LOW_PERCENTILE=0.2
readonly RANGE_HIGH_PERCENTILE=0.8
readonly DEFAULT_SLOTS=3

# Une ligne par tâche mesurée d'un plan : « date<TAB>rang<TAB>réel ÷ estimé<TAB>minutes réelles<TAB>fichiers réels
# (- sans mesure)<TAB>fichiers prévus<TAB>minutes de vérification (- pour un réel antérieur à leur mesure)<TAB>code ou
# review ». Tâche gardée quand elle porte un **Estimated time:** et un **Actual time:** chiffrés, le seul réel pour une
# relecture (son estimation peut être « — », rapport « - ») ; écartées : tâche-branche d'essaim et tâche déléguée à un projet lié, dont le réel additionne plusieurs tâches.
readonly TASK_SAMPLES_PROGRAM="$TASK_FILES_AWK$TASK_STATUS_AWK"'
  function minutes_of(line) {
    sub(/^\*\*[A-Za-z ]+:\*\* */, "", line)
    return match(line, /[0-9]+(\.[0-9]+)?/) ? substr(line, RSTART, RLENGTH) + 0 : 0
  }
  function flush(   planned) {
    planned = planned_files_from(estimated_files_line, files_line)
    if (in_task && !is_aggregate && actual > 0 && (is_review || estimated > 0))
      printf "%s\t%04d\t%s\t%s\t%s\t%d\t%s\t%s\n", date, order, (estimated > 0 ? actual / estimated : "-"), actual, actual_files, planned, checks, (is_review ? "review" : "code")
    in_task = 0
  }
  FNR == 1 { flush(); date = "0000-00-00"; order = 0 }
  { sub(/\r$/, "") }
  /^\*\*Date:\*\*/ && date == "0000-00-00" { date = $0; sub(/^\*\*Date:\*\* */, "", date); date = substr(date, 1, 10) }
  /^### T[0-9]+/ {
    flush(); in_task = 1; order++; is_aggregate = ($0 ~ / Branch /); is_review = 0
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
  in_task && is_review_kind($0) { is_review = 1 }
  in_task && linked_unit($0) != "" { is_aggregate = 1 }
  END { flush() }'

readonly PERCENTILE_AWK='
  # Centile p (0 à 1) de valeurs triées en place, interpolé entre les deux rangs voisins.
  function percentile(values, count, p,   i, j, swap, position, below) {
    for (i = 2; i <= count; i++) for (j = i; j > 1 && values[j - 1] > values[j]; j--) { swap = values[j]; values[j] = values[j - 1]; values[j - 1] = swap }
    position = 1 + (count - 1) * p
    below = int(position)
    return below >= count ? values[count] : values[below] + (position - below) * (values[below + 1] - values[below])
  }'

# Estimation d'une relecture sur ses échantillons : « médiane basse haute », « - - - » sous le minimum.
readonly REVIEW_CALIBRATION_PROGRAM="$PERCENTILE_AWK"'
  { values[++count] = $4 }
  END {
    if (count < min_tasks) { print "- - -"; exit }
    printf "%s %s %s\n", percentile(values, count, 0.5), percentile(values, count, low_percentile), percentile(values, count, high_percentile)
  }'

# Calibrage par tâche sur les échantillons triés du plus récent au plus ancien, « - » pour une valeur absente :
#   « écarts basse haute tâches_à_fichiers minutes_par_fichier erreur_fichiers vérifications » ; bornes, ratios et
#   vérifications absents sous le minimum. Minutes par fichier sur le réel moins les vérifications quand il les porte.
readonly TASK_CALIBRATION_PROGRAM="$PERCENTILE_AWK"'
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

# Ratios, fourchette et estimations demandées, en JSON.
readonly CALIBRATION_PROGRAM='
  # BUSINESS_RULE: chaque tâche paie ses vérifications, quel que soit son nombre de fichiers
  # Objet d une estimation de « tasks » tâches de code et « reviews » relectures ; null quand rien n y est estimable.
  # BUSINESS_RULE: la durée d une relecture vient de ce qu elle lit, jamais de ses fichiers écrits — médiane, sans taux
  function estimate_object(files, r, correction, tasks, reviews,   code, minutes) {
    if (review_minutes == "-") reviews = 0
    if (!tasks && !reviews) return "null"
    code = tasks * check_minutes + files * correction * r
    minutes = code + reviews * review_minutes
    return sprintf("{\"files\":%d,\"minutes\":%d,\"low\":%d,\"high\":%d}", files, whole_minutes(minutes), whole_minutes(code * low + reviews * review_low), whole_minutes(code * high + reviews * review_high))
  }
  # Estimation de la somme, puis une par valeur quand la liste en compte plusieurs.
  function render_estimates(files, r, correction,   count, values, i, total, reviews) {
    count = split(files, values, ",")
    for (i = 1; i <= count; i++) if (values[i] == "review") reviews++; else total += values[i]
    printf ",\"estimate\":%s", estimate_object(total, r, correction, count - reviews, reviews)
    if (count < 2) return
    printf ",\"estimates\":["
    for (i = 1; i <= count; i++) printf "%s%s", (i > 1 ? "," : ""), (values[i] == "review" ? estimate_object(0, r, correction, 0, 1) : estimate_object(values[i], r, correction, 1, 0))
    printf "]"
  }
  # Gain estimé de tout essaim : groupes triés du plus long au plus court, chacun confié au délégué le moins chargé.
  # Travail ordinaire du parent : une voie de plus, menée pendant que les délégués travaillent.
  function render_swarm(groups, parent, r, correction,   count, values, i, j, swap, load, slot, best, serial, parallel, parent_load) {
    count = split(groups, values, ",")
    for (i = 1; i <= count; i++) values[i] = group_minutes(values[i], r, correction)
    for (i = 1; i <= count; i++) serial += values[i]
    if (parent != "") { parent_load = group_minutes(parent, r, correction); serial += parent_load }
    for (i = 2; i <= count; i++) for (j = i; j > 1 && values[j - 1] < values[j]; j--) { swap = values[j]; values[j] = values[j - 1]; values[j - 1] = swap }
    for (slot = 1; slot <= slots; slot++) load[slot] = 0
    for (i = 1; i <= count; i++) {
      best = 1
      for (slot = 2; slot <= slots; slot++) if (load[slot] < load[best]) best = slot
      load[best] += values[i]
    }
    parallel = parent_load
    for (slot = 1; slot <= slots; slot++) if (load[slot] > parallel) parallel = load[slot]
    printf ",\"swarm\":{\"branches\":%d,\"slots\":%d,\"serial_minutes\":%d,\"swarm_minutes\":%d", count, slots, whole_minutes(serial), whole_minutes(parallel)
    if (parent != "") printf ",\"parent_minutes\":%d", whole_minutes(parent_load)
    printf "}"
  }
  # Minutes par groupe « fichiers[/tâches] » : coût fixe de vérification de chaque tâche, plus ses fichiers.
  function group_minutes(group, r, correction,   parts) {
    if (split(group, parts, "/") < 2) parts[2] = 1
    return parts[2] * check_minutes + parts[1] * correction * r
  }
  # Fichiers par groupe au seuil de la règle de branche, arrondis au-dessus : le modèle ne refait jamais ce calcul.
  function branch_files(threshold, rate,   count) {
    count = int(threshold / rate)
    return count * rate < threshold ? count + 1 : count
  }
  # Minutes entières, au moins une : une estimation à 0 min ne dit rien.
  function whole_minutes(value,   rounded) {
    rounded = sprintf("%.0f", value) + 0
    return rounded < 1 ? 1 : rounded
  }
  BEGIN {
    # BUSINESS_RULE: ratios et fourchette viennent des seules tâches, unité du plan — prévu et réel y sont comptés de la
    # même façon ; sous 10 tâches mesurées, valeurs de référence, sans repli sur les branches
    r = reference_r; file_error = 1; has_rates = (task_rate != "-")
    if (has_rates) { r = task_rate; file_error = task_error }
    if (task_low != "-") { low = task_low; high = task_high }
    apply = (has_rates && (file_error > 1 + tolerance || file_error < 1 - tolerance)) ? 1 : 0
    indicative = (has_rates && task_low != "-") ? "false" : "true"
    printf "{\"minutes_per_file\":%.2f,", r
    printf "\"file_error\":%s,\"apply_file_error\":%s,", (has_rates ? sprintf("%.2f", file_error) : "null"), (apply ? "true" : "false")
    printf "\"indicative\":%s,", indicative
    printf "\"source\":\"%s\",\"range_source\":\"%s\",", (has_rates ? "tasks" : "reference"), (task_low != "-" ? "tasks" : "reference")
    if (task_check != "-") check_minutes = task_check
    printf "\"check_minutes\":%.1f,\"check_source\":\"%s\"", check_minutes, (task_check != "-" ? "tasks" : "reference")
    if (files != "") render_estimates(files, r, apply ? file_error : 1)
    if (groups != "") render_swarm(groups, parent, r, apply ? file_error : 1)
    # Seuil de la règle de branche recopié tel quel, et son équivalent en fichiers aux minutes par fichier appliquées
    printf ",\"branch_minutes\":%s,\"branch_files\":%d}\n", branch_minutes + 0, branch_files(branch_minutes, r * (apply ? file_error : 1))
  }'

ROOT="."
FILES=""
BRANCH_GROUPS=""
PARENT_WORK=""
SLOTS=$DEFAULT_SLOTS

fail_usage() {
  echo "time-calibrate: $1" >&2
  echo "usage: time-calibrate.sh [--root <dir>] [--files <n|review>[,<n|review>…]] [--groups <n>[/<t>],<n>[/<t>][,…] [--slots <n>] [--parent <n>[/<t>]]]" >&2
  exit $EXIT_USAGE
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root)  [ $# -ge 2 ] || fail_usage "$1 needs a value"; ROOT=$2; shift 2 ;;
      --files) [ $# -ge 2 ] || fail_usage "$1 needs a value"; FILES=$2; shift 2 ;;
      --groups) [ $# -ge 2 ] || fail_usage "$1 needs a value"; BRANCH_GROUPS=$2; shift 2 ;;
      --slots) [ $# -ge 2 ] || fail_usage "$1 needs a value"; SLOTS=$2; shift 2 ;;
      --parent) [ $# -ge 2 ] || fail_usage "$1 needs a value"; PARENT_WORK=$2; shift 2 ;;
      *)       fail_usage "unknown argument $1" ;;
    esac
  done
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
  [[ -z $FILES || $FILES =~ ^([0-9]+|review)(,([0-9]+|review))*$ ]] \
    || fail_usage "--files needs whole numbers or review separated by commas"
  [[ -z $BRANCH_GROUPS || $BRANCH_GROUPS =~ ^[0-9]+(/[1-9][0-9]*)?(,[0-9]+(/[1-9][0-9]*)?)*$ ]] \
    || fail_usage "--groups needs <files>[/<tasks>] values separated by commas"
  [[ $SLOTS =~ ^[1-9][0-9]*$ ]] || fail_usage "--slots needs a positive whole number"
  [[ -z $PARENT_WORK || $PARENT_WORK =~ ^[0-9]+(/[1-9][0-9]*)?$ ]] || fail_usage "--parent needs <files>[/<tasks>]"
  [[ -z $PARENT_WORK || -n $BRANCH_GROUPS ]] || fail_usage "--parent needs --groups"
}

# Valeur numérique d'un champ du fichier de référence, dans REPLY.
read_reference() {
  local content pattern="\"$1\": *([0-9.]+)"
  content=$(<"$REFERENCE_FILE")
  [[ $content =~ $pattern ]] && REPLY=${BASH_REMATCH[1]}
}

# Échantillons de tous les plans dans REPLY, du plus récent au plus ancien ; vide sans plan.
read_samples() {
  local branch_dir="$ROOT/.forge/branch"
  REPLY=""
  [ -d "$branch_dir" ] || return 0
  REPLY=$(find "$branch_dir" -name plan.md -exec awk "$TASK_SAMPLES_PROGRAM" {} + | LC_ALL=C sort -t$'\t' -k1,1r -k2,2r)
}

# Sortie de <programme> dans REPLY sur les échantillons récents <échantillons> d'un type — les relectures ne prennent
# jamais la place d'une tâche de code, ni l'inverse.
# Usage : calibrate_kind <code|review> <minimum de tâches> <programme> <échantillons>
calibrate_kind() {
  REPLY=$(awk -F '\t' -v kind="$1" -v limit=$RECENT_FOR_RANGE '$8 == kind && ++count <= limit' <<< "$4" \
    | awk -F '\t' -v min_tasks="$2" -v low_percentile=$RANGE_LOW_PERCENTILE \
        -v high_percentile=$RANGE_HIGH_PERCENTILE "$3")
}

main() {
  local reference_r low high branch_minutes check_minutes task_count task_low task_high file_count task_rate task_error task_check
  local samples review_minutes review_low review_high
  parse_arguments "$@"
  read_reference minutes_per_file; reference_r=$REPLY
  read_reference check_minutes; check_minutes=$REPLY
  read_reference range_low; low=$REPLY
  read_reference range_high; high=$REPLY
  read_reference branch_minutes; branch_minutes=$REPLY
  read_samples; samples=$REPLY
  calibrate_kind review $MIN_REVIEW_TASKS "$REVIEW_CALIBRATION_PROGRAM" "$samples"
  read -r review_minutes review_low review_high <<< "$REPLY"
  calibrate_kind code $MIN_RANGE_TASKS "$TASK_CALIBRATION_PROGRAM" "$samples"
  read -r task_count task_low task_high file_count task_rate task_error task_check <<< "$REPLY"
  awk -v reference_r="$reference_r" -v low="$low" -v high="$high" \
    -v files="$FILES" -v groups="$BRANCH_GROUPS" -v parent="$PARENT_WORK" -v slots="$SLOTS" \
    -v task_low="$task_low" -v task_high="$task_high" \
    -v review_minutes="$review_minutes" -v review_low="$review_low" -v review_high="$review_high" \
    -v task_rate="$task_rate" -v task_error="$task_error" -v check_minutes="$check_minutes" -v task_check="$task_check" \
    -v tolerance=$FILE_ERROR_TOLERANCE -v branch_minutes="$branch_minutes" "$CALIBRATION_PROGRAM"
}

main "$@"
