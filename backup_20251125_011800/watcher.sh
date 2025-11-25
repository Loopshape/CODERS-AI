#!/usr/bin/env bash
source "$(dirname "$0")/core.sh"

SNIPPET_DIR="$HOME/.ai/snippets"

log_info "Starting watcher for $SNIPPET_DIR ..."

# Prüfung, ob inotifywait installiert ist
if ! command -v inotifywait >/dev/null 2>&1; then
  log_error "inotifywait nicht installiert. Bitte installieren (z. B. via inotify-tools)."
  exit 1
fi

while true; do
  inotifywait -e modify,create,delete,move -r "$SNIPPET_DIR"
  log_info "Änderung erkannt, rebuilding..."
  bash "$(dirname "$0")/html_builder.sh"
  bash "$(dirname "$0")/agent_runner.sh"
done

