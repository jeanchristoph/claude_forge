#!/bin/bash
# Calibration de l'estimation : ratios du projet tirés des synthèses metrics.json, valeurs de référence du skill à défaut.
#   Lecture seule : aucune écriture
#   Rend compte en JSON sur une ligne — la mise en page et le report dans project.md reviennent au skill
#   r (minutes par fichier) et t (tokens par fichier) : médiane des 5 branches mesurées les plus récentes
#   Erreur de prévision des fichiers : médiane réel ÷ prévu des 5 dernières, appliquée dès 3 branches si elle s'écarte de plus de 20 % de 1
#   Estimation : 1 minute au moins, bornes de la fourchette comprises
#   Fiabilité : part des 10 dernières branches dont la durée réelle tombe dans la fourchette de l'estimation recalculée
# Usage : time-calibrate.sh [--root <dir>] [--files <n>[,<n>…]]
#   --files : nombre de fichiers à estimer — ajoute un objet "estimate" (minutes, fourchette, tokens) ;
#   liste séparée par des virgules (une valeur par tâche d'un plan) → "estimate" porte sur la somme,
#   "estimates" donne une estimation par valeur, dans l'ordre
# Sortie : 0 JSON écrit · 1 usage, sans JSON

set -u

readonly EXIT_USAGE=1
readonly REFERENCE_FILE="$(dirname "${BASH_SOURCE[0]}")/../references/estimation.json"
readonly RECENT_FOR_RATIOS=5
readonly RECENT_FOR_RELIABILITY=10
readonly FILE_ERROR_TOLERANCE=0.2
readonly FILE_ERROR_MIN_BRANCHES=3
readonly RELIABLE_SHARE=0.7

# Une ligne par synthèse : « date agent_minutes actual_files planned_files tokens mode », null gardé tel quel ;
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
  { printf "%s %s %s %s %s %s\n", field("date"), field("agent_minutes"), field("actual_files"), field("planned_files"), field("tokens"), field("mode") }'

# Calcul sur les synthèses triées de la plus récente à la plus ancienne.
readonly CALIBRATION_PROGRAM='
  function median(values, count,   i, j, swap) {
    for (i = 2; i <= count; i++) for (j = i; j > 1 && values[j - 1] > values[j]; j--) { swap = values[j]; values[j] = values[j - 1]; values[j - 1] = swap }
    return count % 2 ? values[(count + 1) / 2] : (values[count / 2] + values[count / 2 + 1]) / 2
  }
  function estimate_object(files, r, t, correction,   corrected, minutes) {
    corrected = files * correction
    minutes = corrected * r
    return sprintf("{\"files\":%d,\"minutes\":%d,\"low\":%d,\"high\":%d,\"tokens\":%.0f}", files, whole_minutes(minutes), whole_minutes(minutes * low), whole_minutes(minutes * high), corrected * t)
  }
  # Estimation de la somme, puis une par valeur quand la liste en compte plusieurs.
  function render_estimates(files, r, t, correction,   count, values, i, total) {
    count = split(files, values, ",")
    for (i = 1; i <= count; i++) total += values[i]
    printf ",\"estimate\":%s", estimate_object(total, r, t, correction)
    if (count < 2) return
    printf ",\"estimates\":["
    for (i = 1; i <= count; i++) printf "%s%s", (i > 1 ? "," : ""), estimate_object(values[i], r, t, correction)
    printf "]"
  }
  # Minutes entières, au moins une : une estimation à 0 min ne dit rien.
  function whole_minutes(value,   rounded) {
    rounded = sprintf("%.0f", value) + 0
    return rounded < 1 ? 1 : rounded
  }
  $2 != "null" && $3 != "null" && $3 > 0 && minute_count < recent_ratios { minute_ratios[++minute_count] = $2 / $3 }
  # BUSINESS_RULE: tokens des seuls délégués — sur une branche mixte, les fichiers du parent dilueraient le ratio
  $5 != "null" && $6 == "delegated" && $3 != "null" && $3 > 0 && token_count < recent_ratios { token_ratios[++token_count] = $5 / $3 }
  $4 != "null" && $4 > 0 && $3 != "null" && error_count < recent_ratios { file_errors[++error_count] = $3 / $4 }
  $2 != "null" && $4 != "null" && $4 > 0 && checked < recent_reliability { checked++; planned[checked] = $4; actual[checked] = $2 }
  $2 != "null" { measured++ }
  END {
    r = minute_count ? median(minute_ratios, minute_count) : reference_r
    t = token_count ? median(token_ratios, token_count) : reference_t
    file_error = error_count ? median(file_errors, error_count) : 1
    # BUSINESS_RULE: sous 3 branches, une seule prévision ratée corrigerait toutes les suivantes
    apply = (error_count >= min_error_branches && (file_error > 1 + tolerance || file_error < 1 - tolerance)) ? 1 : 0
    for (i = 1; i <= checked; i++) {
      estimate = planned[i] * (apply ? file_error : 1) * r
      if (actual[i] >= estimate * low && actual[i] <= estimate * high) in_range++
    }
    indicative = (measured < recent_ratios || !checked || in_range / checked < reliable_share) ? "true" : "false"
    printf "{\"minutes_per_file\":%.2f,\"tokens_per_file\":%d,", r, t
    printf "\"file_error\":%s,\"apply_file_error\":%s,", (error_count ? sprintf("%.2f", file_error) : "null"), (apply ? "true" : "false")
    printf "\"measured_branches\":%d,\"checked\":%d,\"in_range\":%d,\"indicative\":%s,", measured, checked, in_range, indicative
    printf "\"source\":\"%s\"", (minute_count ? "project" : "reference")
    if (files != "") render_estimates(files, r, t, apply ? file_error : 1)
  }'

ROOT="."
FILES=""

fail_usage() {
  echo "time-calibrate: $1" >&2
  echo "usage: time-calibrate.sh [--root <dir>] [--files <n>[,<n>…]]" >&2
  exit $EXIT_USAGE
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root)  [ $# -ge 2 ] || fail_usage "$1 needs a value"; ROOT=$2; shift 2 ;;
      --files) [ $# -ge 2 ] || fail_usage "$1 needs a value"; FILES=$2; shift 2 ;;
      *)       fail_usage "unknown argument $1" ;;
    esac
  done
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
  [[ -z $FILES || $FILES =~ ^[0-9]+(,[0-9]+)*$ ]] || fail_usage "--files needs whole numbers separated by commas"
}

# Valeur numérique d'un champ du fichier de référence, dans REPLY.
read_reference() {
  local content pattern="\"$1\": *([0-9.]+)"
  content=$(<"$REFERENCE_FILE")
  [[ $content =~ $pattern ]] && REPLY=${BASH_REMATCH[1]}
}

# Synthèses du projet, de la plus récente à la plus ancienne (date AAAA-MM-JJ, tri lexical).
list_metrics() {
  local branch_dir="$ROOT/.forge/branch"
  [ -d "$branch_dir" ] || return 0
  find "$branch_dir" -name metrics.json -exec awk "$METRICS_PROGRAM" {} + | sort -r
}

# Fixes de référence, seuils de la règle de branche et coûts fixes, recopiés tels quels dans la sortie.
render_reference_values() {
  local name
  for name in range_low range_high delegate_minutes merge_minutes delegate_tokens \
              branch_criteria_required branch_minutes branch_tokens branch_layers; do
    read_reference "$name"
    printf ',"%s":%s' "$name" "$REPLY"
  done
}

main() {
  local reference_r reference_t low high
  parse_arguments "$@"
  read_reference minutes_per_file; reference_r=$REPLY
  read_reference tokens_per_file; reference_t=$REPLY
  read_reference range_low; low=$REPLY
  read_reference range_high; high=$REPLY
  list_metrics | awk -v reference_r="$reference_r" -v reference_t="$reference_t" -v low="$low" -v high="$high" \
    -v files="$FILES" -v recent_ratios=$RECENT_FOR_RATIOS -v recent_reliability=$RECENT_FOR_RELIABILITY \
    -v tolerance=$FILE_ERROR_TOLERANCE -v min_error_branches=$FILE_ERROR_MIN_BRANCHES -v reliable_share=$RELIABLE_SHARE "$CALIBRATION_PROGRAM"
  render_reference_values
  printf '}\n'
}

main "$@"
