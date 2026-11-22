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

# Valeur texte du champ <name> d'un JSON de hook dans REPLY, vide si absent. Une clé précédée d'une barre oblique
# inverse appartient à une chaîne échappée (commande, contenu écrit, réponse d'outil), jamais au JSON du hook.
# Usage : json_string_field <name> <json>
json_string_field() {
  local pattern="(^|[^\\])\"$1\":\"(([^\"\\]|\\\\.)*)\""
  REPLY=""
  [[ $2 =~ $pattern ]] && REPLY=${BASH_REMATCH[2]}
}

# Chemin du champ <name> en barres obliques dans REPLY : « C:\\x » (JSON) → « C:/x ».
# Usage : json_path_field <name> <json>
json_path_field() {
  json_string_field "$1" "$2"
  REPLY=${REPLY//\\\\//}
}
