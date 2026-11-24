#!/bin/bash
# Version installée et dernier tag publié de forge, communs à update.sh et au hook update-notice.sh, chargés avec
# `source` après json.sh. INSTALL_DIR : dossier contenant install.json, fixé par l'appelant.
# install.json : {"version","repository","latest","dismissed"}, écrit par les installeurs puis par save_install_file.

readonly DEFAULT_REPOSITORY=${FORGE_UPDATE_REPOSITORY:-"https://github.com/jeanchristoph/claude_forge.git"}
readonly INSTALL_FILE_NAME="install.json"
readonly VERSION_PATTERN='^v([0-9]+)\.([0-9]+)\.([0-9]+)$'

INSTALLED_VERSION=""
REPOSITORY=""
LATEST_VERSION=""
DISMISSED_VERSION=""

nullable_json() {
  REPLY=null
  [ -n "$1" ] && json_escape "$1"
}

# Champ chaîne de install.json dans REPLY, vide s'il est absent ou nul.
read_install_field() {
  REPLY=""
  [[ $1 =~ \"$2\":\"([^\"]*)\" ]] && REPLY=${BASH_REMATCH[1]}
}

# install.json absent ou illisible → version inconnue, dépôt par défaut. Lecture sans sous-processus.
load_install_file() {
  local content="" file="$INSTALL_DIR/$INSTALL_FILE_NAME"
  [ -f "$file" ] && IFS= read -r -d '' content < "$file"
  read_install_field "$content" version;    INSTALLED_VERSION=$REPLY
  read_install_field "$content" repository; REPOSITORY=$REPLY
  read_install_field "$content" latest;     LATEST_VERSION=$REPLY
  read_install_field "$content" dismissed;  DISMISSED_VERSION=$REPLY
  [ -n "$REPOSITORY" ] || REPOSITORY=$DEFAULT_REPOSITORY
}

save_install_file() {
  local version_json latest_json repository_json dismissed_json
  nullable_json "$INSTALLED_VERSION"; version_json=$REPLY
  json_escape "$REPOSITORY"; repository_json=$REPLY
  nullable_json "$LATEST_VERSION"; latest_json=$REPLY
  nullable_json "$DISMISSED_VERSION"; dismissed_json=$REPLY
  printf '{"version":%s,"repository":%s,"latest":%s,"dismissed":%s}\n' \
    "$version_json" "$repository_json" "$latest_json" "$dismissed_json" > "$INSTALL_DIR/$INSTALL_FILE_NAME"
}

# Vrai si la version $1 est strictement plus récente que $2 ; $2 hors format vX.Y.Z → toujours vrai.
is_newer_version() {
  [[ $1 =~ $VERSION_PATTERN ]] || return 1
  local -a candidate=("${BASH_REMATCH[@]:1}")
  [[ $2 =~ $VERSION_PATTERN ]] || return 0
  local -a reference=("${BASH_REMATCH[@]:1}") index
  for index in 0 1 2; do
    [ "$((10#${candidate[index]}))" -gt "$((10#${reference[index]}))" ] && return 0
    [ "$((10#${candidate[index]}))" -lt "$((10#${reference[index]}))" ] && return 1
  done
  return 1
}

# git@host:path → https://host/path : l'https n'exige ni clé ni passphrase, rien n'attend une saisie.
https_repository() {
  local url=$1
  [[ $url =~ ^git@([^:]+):(.+)$ ]] && url="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  printf '%s' "$url"
}

# Dernier tag vX.Y.Z publié dans LATEST_VERSION, retenu dans install.json quand il change (échec d'écriture silencieux) ;
# échec réseau ou aucun tag conforme → retour 1, rien n'est modifié.
refresh_latest_version() {
  local refs line tag latest=""
  refs=$(GIT_TERMINAL_PROMPT=0 git -c http.lowSpeedLimit=1 -c http.lowSpeedTime=10 \
    ls-remote --tags --refs "$(https_repository "$REPOSITORY")" 2>/dev/null) || return 1
  while IFS= read -r line; do
    tag=${line##*refs/tags/}
    [[ $tag =~ $VERSION_PATTERN ]] || continue
    { [ -z "$latest" ] || is_newer_version "$tag" "$latest"; } && latest=$tag
  done <<< "$refs"
  [ -n "$latest" ] || return 1
  [ "$latest" = "$LATEST_VERSION" ] && return 0
  LATEST_VERSION=$latest
  save_install_file 2>/dev/null || true
}
