#!/bin/bash
# Rendu JSON sans jq (absent de Git Bash), chargé par les scripts du skill avec `source`.

# Chaîne JSON dans REPLY, sans sous-processus : barre oblique inverse, guillemet et contrôles échappés.
json_escape() {
  local text=${1//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  REPLY="\"$text\""
}

json_string() {
  json_escape "$1"
  printf '%s' "$REPLY"
}
