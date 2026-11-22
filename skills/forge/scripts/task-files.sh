#!/bin/bash
# Fonctions awk communes de lecture d'un plan, chargées avec `source` par time-aggregate.sh, time-calibrate.sh,
# status.sh et plan-hook.sh.

# Fichiers prévus d'une tâche de plan (« Fichiers d'une tâche », phases/p4-plan.md), depuis ses lignes de champ :
#   **Estimated files:** <n> (ancien plan) prime ; sinon « (≈ n) » en fin de **Files:** ; sinon nombre de chemins
#   entre accents graves de **Files:**.
#   planned_files_from(estimated_files_line, files_line) → nombre, 0 sans information.
# Empreintes de time-mark.sh : « chemin<TAB>hash » par fichier, lignes séparées par « \n » dans la chaîne JSON.
#   raw_string_field(name) → contenu brut de la chaîne, échappements gardés ; « <none> » si le champ manque.
#   changed_files(before, after) → fichiers apparus, changés ou disparus entre deux empreintes.
readonly TASK_FILES_AWK='
  function planned_files_from(estimated_line, files_line,   rest, count) {
    if (estimated_line != "" && match(estimated_line, /[0-9]+/)) return substr(estimated_line, RSTART, RLENGTH) + 0
    if (match(files_line, /\(≈ *[0-9]+\)[[:space:]]*$/)) { rest = substr(files_line, RSTART); match(rest, /[0-9]+/); return substr(rest, RSTART, RLENGTH) + 0 }
    count = gsub(/`/, "`", files_line)
    return int(count / 2)
  }
  function raw_string_field(name,   key, start, i, character, value) {
    key = "\"" name "\":\""
    start = index($0, key)
    if (!start) return "<none>"
    value = ""
    for (i = start + length(key); i <= length($0); i++) {
      character = substr($0, i, 1)
      if (character == "\\") { value = value character substr($0, i + 1, 1); i++; continue }
      if (character == "\"") break
      value = value character
    }
    return value
  }
  function changed_files(before, after,   entries, count, i, separator, path, previous, seen, changed) {
    count = split(before, entries, /\\n/)
    for (i = 1; i <= count; i++) if (entries[i] != "") { separator = index(entries[i], "\\t"); previous[substr(entries[i], 1, separator - 1)] = substr(entries[i], separator + 2) }
    count = split(after, entries, /\\n/)
    for (i = 1; i <= count; i++) if (entries[i] != "") {
      separator = index(entries[i], "\\t"); path = substr(entries[i], 1, separator - 1); seen[path] = 1
      if (!(path in previous) || previous[path] != substr(entries[i], separator + 2)) changed++
    }
    for (path in previous) if (!(path in seen)) changed++
    return changed + 0
  }'

# Statut d'une tâche de plan : ligne [ ] / [x] / [!] / [-] sous son titre « ### Tn », micro-étapes [ ] T1.1 exclues ;
# tâche sans ligne de statut → ouverte. Seule règle de lecture des coches, partagée par status.sh et plan-hook.sh.
#   is_task_heading(line) · is_status_line(line) · status_of(status_line) → open, done, blocked ou dropped.
readonly TASK_STATUS_AWK='
  function is_task_heading(line) { return line ~ /^### T[0-9]+/ }
  function is_status_line(line) { return line ~ /^\[[ x!-]\]/ && line !~ /^\[.\] T[0-9]+\.[0-9]+/ }
  function status_of(line,   mark) {
    mark = substr(line, 2, 1)
    return (mark == "x") ? "done" : (mark == "!") ? "blocked" : (mark == "-") ? "dropped" : "open"
  }'

# Une ligne « fichier<TAB>statut<TAB>titre » par tâche, pour un ou plusieurs plans lus en un seul passage.
readonly TASKS_PROGRAM="$TASK_STATUS_AWK"'
  function flush() { if (title != "") printf "%s\t%s\t%s\n", plan, status, title; title = "" }
  FNR == 1                          { flush(); plan = FILENAME }
                                    { sub(/\r$/, "") }
  is_task_heading($0)               { flush(); title = substr($0, 5); status = "open"; next }
  /^## /                            { flush(); next }
  title != "" && is_status_line($0) { status = status_of($0) }
  END { flush() }'
