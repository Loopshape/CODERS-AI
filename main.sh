#!/usr/bin/env bash
set -eu
HOME_AI="$HOME/.ai"
cd "$HOME_AI"

case "${1:-}" in
  init)
    bash installer.sh
    ;;
  build)
    bash html_builder.sh
    ;;
  run)
    bash agent_runner.sh
    ;;
  watch)
    bash watcher.sh
    ;;
  auto)
    # build einmal, dann watcher im Hintergrund
    bash html_builder.sh
    nohup bash watcher.sh > /dev/null 2>&1 &
    log_success "Auto mode: build + watcher gestartet"
    ;;
  *)
    echo "Usage: $0 {init|build|run|watch|auto}"
    exit 1
    ;;
esac

