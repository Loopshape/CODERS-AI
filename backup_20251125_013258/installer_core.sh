#!/usr/bin/env bash
source "$(dirname "$0")/core.sh"

install() {
  log_info "Running installer..."
  mkdir -p ~/.ai/snippets
  mkdir -p ~/.ai/state
  touch ~/.ai/state/hashes.json
  log_success "Created snippet- and state directories."

  # Termux: Boot-Script einrichten, falls nötig
  if command -v termux-wake-lock >/dev/null 2>&1; then
    mkdir -p ~/.termux/boot
    local boot_script=~/.termux/boot/ai_start.sh
    cat > "$boot_script" <<EOF
#!/data/data/com.termux/files/usr/bin/env bash
termux-wake-lock
bash \$HOME/.ai/main.sh auto
EOF
    chmod +x "$boot_script"
    log_success "Installed Termux:Boot startup script at $boot_script"
  else
    log_warn "termux-wake-lock not found; skipping Termux boot script."
  fi

  log_info "Installer done."
}

install

