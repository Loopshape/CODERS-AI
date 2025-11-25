#!/usr/bin/env bash
set -eu
IFS=$'\n\t'

# Logging-Funktionen
log_info()    { echo -e "\033[1;34m[INFO]\033[0m $*"; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }

# Backup: Datei mit Zeitstempel sichern
backup_file() {
  local file="$1"
  local backup_dir="$2"
  mkdir -p "$backup_dir"
  local ts=$(date +%Y%m%d_%H%M%S)
  cp "$file" "$backup_dir/$(basename "$file").bak.$ts"
  log_info "Backed up $file → $backup_dir/$(basename "$file").bak.$ts"
}

# Prompt laden: URL, Datei oder roher String
get_prompt() {
  local src="$1"
  if [[ "$src" =~ ^https?:// ]]; then
    curl -fsSL "$src"
  elif [[ -f "$src" ]]; then
    cat "$src"
  else
    printf "%s" "$src"
  fi
}

# Directory-Hash (sha256 aller Dateien im Ordner)
sha256sum_dir() {
  local dir="$1"
  # find, sort, dann jeweils sha256sum, dann gesamtes Ergebnis nochmal hashen
  local all
  all=$(cd "$dir" && find . -type f -print0 | sort -z | xargs -0 sha256sum)
  printf "%s" "$all" | sha256sum | awk '{print $1}'
}

# Generiere einen neuen Root-Hash (Zeit + Zufall)
new_root_hash() {
  local ts=$(date +%s%N)
  # /dev/urandom kann helfen
  local rand=$(head -c 32 /dev/urandom | sha256sum | awk '{print $1}')
  printf "%s" "$ts$rand" | sha256sum | awk '{print $1}'
}

