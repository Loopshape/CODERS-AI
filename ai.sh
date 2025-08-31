#!/usr/bin/env bash
# Author: Aris Arjuna Noorsanto <exe.opcode@gmail.com>
# AI Automation - Singlefile (überarbeitet, deutsch)
# -------------------------------------------------
# Unterstützte Modi:
#  ai <file>         -> Einzeldatei
#  ai + <script>     -> Script-Analyse (Inhalt)
#  ai * <glob>       -> Batch per Glob/Pattern
#  ai .              -> Environment scan
#  ai : f1:f2:...    -> Pipeline (Doppelpunkt-getrennt)
#  ai agi + <dir>    -> Watch (agi +), agi - -> screenshot (virtuell), agi ~ -> helper watch
#  ai web <url>      -> Web-Scrape + Snapshot (robots-respekt)
#  ai aim            -> AIM monitoring (MIME-aware placeholder / autonomous)
#
# Strikte Gesetze (Kurz):
#  - Ein-Skript-Prinzip: Alles in ~/bin/ai
#  - UNIVERSAL_LAW ist eingebettet und gilt immer.
#  - MIME-Verantwortung: routines only for matching mime-types.
#  - Ollama: pkill ollama; ollama serve & ; ollama run gemma3:1b (wenn verfügbar)
#  - Keine dauerhaften Nebenprodukte; Backups in $BACKUP_DIR
# -------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# -----------------------
# Pfade & Environment
# -----------------------
HOME_DIR="${HOME:-/root}"
BACKUP_DIR="$HOME_DIR/.ai_backups"
TMP_DIR="$(mktemp -d "${HOME_DIR}/.ai_tmp.XXXX")"
LOG_FILE="$HOME_DIR/.ai_automation.log"
mkdir -p "$BACKUP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

# -----------------------
# Universal Law (Blob)
# -----------------------
read -r -d '' UNIVERSAL_LAW <<'EOF' || true
:bof:
redo complete layout and design an advanced symetrics to proximity accordance for dedicated info-quota alignments, which grant a better adjustment for leading besides subliminal range compliance promisings, that affair any competing content relations into a cognitive intuitition guidance comparison between space and gap implies, that are suggesting the viewer a subcoordinated experience alongside repetitive tasks and stoic context sortings, all cooperational aligned to timed subjects of importance accordingly to random capacity within builds of data statements, that prognose the grid reliability of a mockup as given optically acknowledged for a more robust but also as attractive rulership into golden-ratio item handling
:eof:
EOF

# -----------------------
# Logging (Deutsch)
# -----------------------
log()    { printf '[%s] %s\n' "$(date -Is)" "$*" | tee -a "$LOG_FILE"; }
info()   { log "INFO: $*"; }
warn()   { log "WARN: $*"; }
error()  { log "ERROR: $*" >&2; }
success(){ log "OK: $*"; }

# -----------------------
# Utilities
# -----------------------
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local ts; ts=$(date +%Y%m%d%H%M%S)
        local base; base=$(basename "$file")
        cp -a -- "$file" "$BACKUP_DIR/${base}.${ts}.bak"
        info "Backup erstellt: $BACKUP_DIR/${base}.${ts}.bak"
    else
        warn "Backup: Datei nicht gefunden: $file"
    fi
}

detect_mime() {
    local file="$1"
    if command -v file >/dev/null 2>&1; then
        file --mime-type -b -- "$file" || echo "application/octet-stream"
    else
        echo "application/octet-stream"
    fi
}

fetch_url() {
    local url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$url"
    else
        error "fetch_url: 'curl' oder 'wget' wird benötigt."
        return 1
    fi
}

# -----------------------
# Ollama Helpers
# -----------------------
ollama_available() {
    command -v ollama >/dev/null 2>&1
}

ensure_ollama_server() {
    if ! ollama_available; then
        warn "ollama CLI nicht gefunden. Überspringe ollama-bezogene Schritte."
        return 1
    fi
    info "Stoppe vorhandene ollama Prozesse (falls vorhanden)..."
    pkill -f ollama || true
    info "Starte ollama serve im Hintergrund..."
    # starte server ohne blockieren, leite stdout/stderr ins log
    nohup ollama serve >/dev/null 2>&1 &
    # Warte kurz, prüfe Endpoint
    sleep 1
    if curl -s --max-time 2 http://localhost:11434/ >/dev/null 2>&1; then
        success "Ollama Server erreichbar."
        return 0
    else
        warn "Ollama Server scheint nicht erreichbar (Prüfe ollama serve)."
        return 2
    fi
}

ollama_run_prompt() {
    local prompt_file="$1"
    # Erwartet Pfad zu Datei mit Prompt. Liefere stdout von ollama run gemma3:1b
    if ! ollama_available; then
        warn "ollama nicht verfügbar: simulierter Mock-Antwort wird verwendet."
        sed -n '1,200p' "$prompt_file"
        return 0
    fi

    # Versuche mehrere Aufrufvarianten (robust gegenüber verschiedenen ollama-versionen)
    local resp
    if resp="$(ollama run gemma3:1b --no-stream < "$prompt_file" 2>/dev/null)"; then
        printf '%s' "$resp"
        return 0
    fi
    if resp="$(ollama run gemma3:1b "$(cat "$prompt_file")" 2>/dev/null)"; then
        printf '%s' "$resp"
        return 0
    fi
    if resp="$(cat "$prompt_file" | ollama run gemma3:1b 2>/dev/null)"; then
        printf '%s' "$resp"
        return 0
    fi

    warn "ollama_run_prompt: Keine Antwort erhalten (CLI inkompatibel?)"
    return 1
}

# -----------------------
# Kern-Routinen
# -----------------------

# HTML/JS DOM-Enhancement (respektiert UNIVERSAL_LAW)
ai_process_html() {
    local file="$1"
    [[ -f "$file" ]] || { error "Datei nicht gefunden: $file"; return 1; }
    backup_file "$file"
    info "Wende HTML/JS/DOM-Optimierungen an: $file"

    local content tmpf
    tmpf="$TMP_DIR/$(basename "$file").tmp"
    content=$(<"$file")

    # 1) Head-Injektion (neon-theme) nur, wenn <head> existiert
    if [[ "$content" == *"<head>"* && "$content" != *"--main-bg"* ]]; then
        content="${content/<head>/<head><style>:root{--main-bg:#8B0000;--main-fg:#fff;--accent:#00ffff;--link:#ffcc00;}body{margin:10px;padding:15px;background:linear-gradient(135deg,#2b0b0b,#001f3f);color:var(--main-fg);}}</style>}"
    fi

    # 2) JS-Funktion Kommentar-Annotation (Perl falls vorhanden)
    if command -v perl >/dev/null 2>&1; then
        content="$(printf '%s' "$content" | perl -0777 -pe 's|function\s+([A-Za-z0-9_]+)\s*\((.*?)\)\s*\{(?!\s*/\*\s*AI:)|function \1(\2) { /* AI: optimize this function */ |gs')"
    fi

    # 3) Eventlistener-Monitoring (einfache Ersetzung)
    content="$(printf '%s' "$content" | sed -E "s|\.addEventListener\((['\"])([^'\" ]+)\1,([^)]*)\)|.addEventListener(\1\2\1, /* AI: monitored */ \3)|g")"

    # 4) Semantic upgrades & ARIA
    content="$(printf '%s' "$content" | sed -E 's|<div class="section"|<section class="section"|g; s|</div><!-- .section -->|</section>|g')"
    content="$(printf '%s' "$content" | sed -E 's|<nav|<nav role=\"navigation\"|g; s|<header|<header role=\"banner\"|g; s|<main|<main role=\"main\"|g; s|<footer|<footer role=\"contentinfo\"|g')"

    printf '%s' "$content" > "$tmpf"
    mv -f "$tmpf" "$file"
    success "Optimierung abgeschlossen: $file"
    return 0
}

# Fallback: reine Textverarbeitung / placeholder
ai_process_text() {
    local file="$1"
    [[ -f "$file" ]] || { error "Datei nicht gefunden: $file"; return 1; }
    backup_file "$file"
    info "Verarbeite Textdatei (Platzhalter): $file"
    # Schreibe UNIVERSAL_LAW in .processed Datei als Hinweis (keine Nebenprodukte in FS? wir speichern .processed als transient)
    printf '%s\n\n-- UNIVERSAL_LAW --\n%s\n' "$(date -Is)" "$UNIVERSAL_LAW" > "${file}.processed"
    success "Textverarbeitung (mock) abgeschlossen: ${file}.processed"
}

# Pipeline: nutze MIME, um richtige Routine zu wählen
ai_handle_file() {
    local file="$1"
    [[ -f "$file" ]] || { warn "ai_handle_file: Datei nicht vorhanden: $file"; return 1; }
    local mime; mime=$(detect_mime "$file" || echo "application/octet-stream")
    case "$mime" in
        text/html*) ai_process_html "$file" ;;
        text/*)     ai_process_text "$file" ;;
        application/json) ai_process_text "$file" ;;
        image/*)    warn "Bildverarbeitung noch nicht implementiert: $file" ;;
        *)          warn "Kein Handler für MIME '$mime' (Datei: $file)" ;;
    esac
}

# Batch (Glob)
ai_mode_batch() {
    local pattern="$1"
    info "Batch-Pattern: $pattern"
    # Expandiere Pattern sicher: nutze eval mit set -f disabled? Simpler: use globbing
    shopt -s nullglob globstar
    local files=( $pattern )
    shopt -u nullglob globstar
    if [[ ${#files[@]} -eq 0 ]]; then warn "Keine Dateien gefunden für Pattern: $pattern"; return 0; fi
    for f in "${files[@]}"; do
        ai_handle_file "$f"
    done
}

# Script-Analyse (Inhalt via stdin oder als arg)
ai_mode_script() {
    local script_content
    if [[ $# -gt 0 && -f "$1" ]]; then
        script_content=$(<"$1")
        info "Analysiere Script-Datei: $1"
    else
        info "Analysiere Script-Input (stdin)..."
        script_content=$(cat -)
    fi
    # Mock-Analyse: schreibe einen kurzen Bericht
    local out="$TMP_DIR/script_report.txt"
    printf 'Script-Analyse Bericht\nDatum: %s\n\nSnippet:\n%s\n\nUNIVERSAL_LAW:\n%s\n' "$(date -Is)" "${script_content:0:1024}" "$UNIVERSAL_LAW" > "$out"
    success "Script-Analyse abgeschlossen: $out"
    cat "$out"
}

# Environment scan
ai_mode_env() {
    info "Environment-Scan:"
    printf 'User: %s\nHome: %s\nOS: %s\n\n' "$(id -nu)" "$HOME_DIR" "$(uname -a)"
    df -h | sed -n '1,5p'
    printf '\nHome Inhalt (kurz):\n'
    ls -la "$HOME_DIR" | sed -n '1,20p'
    printf '\n/etc (kurz):\n'
    if [[ -d /etc ]]; then ls -la /etc | sed -n '1,20p'; fi
    success "Environment-Scan fertig."
}

# Pipeline mode: files separated by :
ai_mode_pipeline() {
    local arg="$1"
    IFS=':' read -ra files <<< "$arg"
    for f in "${files[@]}"; do
        ai_handle_file "$f"
    done
}

# -----------------------
# AGI: Watch & Screenshot
# -----------------------
agi_watch() {
    local folder="$1"
    local pattern="${2:-*}"
    command -v inotifywait >/dev/null 2>&1 || { error "inotifywait benötigt (inotify-tools)"; return 1; }
    info "AGI Watch: Überwache '$folder' für Pattern '$pattern'"
    inotifywait -m -r -e close_write,create,move --format '%w%f' "$folder" | while read -r file; do
        # Filter mit Pattern (einfache Bash-Match)
        if [[ "${file##*/}" == $pattern || "$pattern" == "*" ]]; then
            info "Änderung erkannt: $file"
            ai_handle_file "$file"
            # Optional: Browser-Refresh Hook hier (not implemented)
        fi
    done
}

# Virtuelle Screenshot-Generierung (versucht Chromium, sonst mock)
agi_screenshot() {
    local target="${1:-index.html}"
    local ratio="${2:-portrait}" # portrait, landscape, square, or WxH
    info "Erzeuge Screenshot (virtuell) von $target im Format $ratio"
    local width=800 height=1200
    case "$ratio" in
        portrait) width=800; height=1200;;
        landscape) width=1200; height=800;;
        square) width=1000; height=1000;;
        *) if [[ "$ratio" =~ ^[0-9]+x[0-9]+$ ]]; then width=${ratio%x*}; height=${ratio#*x}; fi;;
    esac
    local out="$BACKUP_DIR/$(basename "${target%.*}").screenshot.png"
    if command -v chromium-browser >/dev/null 2>&1 || command -v chromium >/dev/null 2>&1; then
        local bin=chromium-browser
        command -v chromium >/dev/null 2>&1 && bin=chromium
        info "Benutze $bin für Headless Screenshot..."
        "$bin" --headless --disable-gpu --screenshot="$out" --window-size="${width},${height}" "file://$(realpath "$target")" >/dev/null 2>&1 || warn "Screenshot-Erstellung schlug fehl."
        success "Screenshot: $out"
    elif command -v node >/dev/null 2>&1 && node -e "process.exit(0)" >/dev/null 2>&1; then
        warn "Node vorhanden, aber kein puppeteer installiert. Screenshot übersprungen."
        printf '%s\n' "MOCK-SCREENSHOT: $target ($width x $height)" > "${out}.txt"
        success "Mock-Screenshot (Text) gespeichert: ${out}.txt"
    else
        warn "Keine Methode für Screenshots verfügbar."
    fi
}

# -----------------------
# Web Scraper (robots.txt respect)
# -----------------------
web_scrape() {
    local url="$1"
    if [[ -z "$url" ]]; then error "web_scrape: Keine URL"; return 1; fi
    info "Webscrape: $url"
    local host; host=$(echo "$url" | awk -F/ '{print $3}')
    # Prüfe robots
    if command -v curl >/dev/null 2>&1; then
        local robots; robots=$(curl -fsSL --max-time 5 "https://${host}/robots.txt" 2>/dev/null || echo "")
        if [[ "$robots" == *"Disallow: /"* ]]; then
            warn "robots.txt verbietet Zugriff auf Root von $host -> Abbruch"
            return 1
        fi
        # sichere HTML
        mkdir -p "$BACKUP_DIR/server_snaps"
        local out="$BACKUP_DIR/server_snaps/${host}.html"
        curl -fsSL "$url" -o "$out" || { warn "HTML Download fehlgeschlagen"; return 1; }
        success "HTML gespeichert: $out"
        # Screenshot optional
        agi_screenshot "$out" "landscape"
    else
        error "curl fehlt; web_scrape nicht möglich."
        return 1
    fi
}

# -----------------------
# AIM Monitoring (Autonom)
# -----------------------
aim_monitor() {
    info "AIM Monitoring (autonom, MIME-aware) startet..."
    # Beispiel: scan /home und /etc grob, entscheide anhand MIME
    local scan_paths=( "$HOME_DIR" "/etc" )
    for p in "${scan_paths[@]}"; do
        if [[ -d "$p" ]]; then
            while IFS= read -r -d '' f; do
                local mime; mime=$(detect_mime "$f")
                # vereinfachte Policy: nur bestimmte MIME behandeln
                case "$mime" in
                    text/html*|text/*) ai_handle_file "$f" ;;
                    *) ;; # ignore
                esac
            done < <(find "$p" -type f -print0 2>/dev/null)
        fi
    done
    success "AIM Monitoring-Durchlauf fertig."
}

# -----------------------
# Prompt / Blog Feed -> ollama
# -----------------------
feed_blog_and_request_project() {
    local source="$1"; local outdir="${2:-./ai_generated}"
    mkdir -p "$outdir"
    local blog
    if [[ "$source" =~ ^https?:// ]]; then
        blog="$(fetch_url "$source")" || { error "Blog-Download fehlgeschlagen"; return 1; }
    elif [[ -f "$source" ]]; then
        blog="$(<"$source")"
    else
        error "feed: Quelle nicht gefunden: $source"; return 1
    fi

    # Baue Prompt-Datei
    local pf="$TMP_DIR/ollama_prompt.txt"
    {
        printf 'Du bist ein erfahrener Entwickler. Antwort auf Deutsch.\n\n'
        printf 'UNIVERSAL_LAW:\n%s\n\n' "$UNIVERSAL_LAW"
        printf 'Blog-Inhalt:\n-----BEGIN-BLOG-----\n%s\n-----END-BLOG-----\n\n' "$blog"
        printf 'Aufgabe: Erzeuge ein Harp+Express Node.js Projekt mit Google-ähnlicher Prompt-UI.\n'
        printf 'Ausgabeformat: Liefere ein Base64-kodiertes tar.gz (nur der Blob, keine Erklärungen).\n'
    } > "$pf"

    ensure_ollama_server || warn "Ollama-Server nicht bestätigt; versuche dennoch."

    if ollama_run_prompt "$pf" > "$TMP_DIR/model_out.txt"; then
        # Versuche Base64 zu extrahieren (rudimentär)
        sed -n '1,${p;}' "$TMP_DIR/model_out.txt" | sed 's/^```.*$//g' > "$TMP_DIR/model_b64.txt" || true
        if base64 -d "$TMP_DIR/model_b64.txt" > "$outdir/project.tgz" 2>/dev/null; then
            mkdir -p "$outdir/project"
            tar -xzf "$outdir/project.tgz" -C "$outdir/project"
            success "Projekt extrahiert nach: $outdir/project"
            return 0
        else
            warn "Base64-Dekodierung fehlgeschlagen. Modell-Antwort in $TMP_DIR/model_out.txt prüfen."
            return 2
        fi
    else
        error "ollama_run_prompt schlug fehl."
        return 3
    fi
}

# -----------------------
# CLI Parsing (Symbol-Modi)
# -----------------------
if [[ $# -eq 0 ]]; then
    cat <<USAGE
Usage: $(basename "$0") <mode> [args...]

Modi:
  <file>            -> ai <file>
  + <scriptfile|->  -> ai + script (datei oder stdin)
  * <glob>          -> ai * "*.html"
  .                 -> ai . (env scan)
  : <f1:f2:...>     -> ai : f1:f2 (pipeline)
  agi + <dir>       -> watch dir
  agi - <target>    -> screenshot target
  agi ~ <dir>       -> helper watch
  web <url>         -> web scrape + snapshot
  aim               -> AIM monitoring (autonom)
  feed <source> [outdir] -> feed blog file|url und generiere projekt via ollama

Beispiel:
  $(basename "$0") index.html
  $(basename "$0") + script.sh
  $(basename "$0") '*' "*.html"
  $(basename "$0") : index.html:style.css
  $(basename "$0") agi + ./public
USAGE
    exit 0
fi

mode="$1"
shift || true

case "$mode" in
    +) # Script analysis: either file given or read stdin
        if [[ $# -ge 1 && -f "$1" ]]; then
            ai_mode_script "$1"
        else
            ai_mode_script
        fi
        ;;

    \*) # batch by glob/pattern - pass quoted pattern
        if [[ $# -lt 1 ]]; then error "Pattern fehlt"; exit 1; fi
        ai_mode_batch "$1"
        ;;

    .) ai_mode_env ;;
    :) # pipeline
        if [[ $# -lt 1 ]]; then error "Pipeline-Argument fehlt (f1:f2:...)"; exit 1; fi
        ai_mode_pipeline "$1"
        ;;

    agi)
        if [[ $# -lt 1 ]]; then error "agi sub-mode fehlt"; exit 1; fi
        sub="$1"; shift
        case "$sub" in
            +) agi_watch "${1:-.}" "${2:-*}" ;;
            -) agi_screenshot "${1:-index.html}" "${2:-portrait}" ;;
            ~) agi_watch "${1:-.}" "${2:-*}" ;;
            *) agi_watch "${sub}" "${1:-*}" ;;
        esac
        ;;

    web)
        if [[ $# -lt 1 ]]; then error "web <url> erwartet"; exit 1; fi
        web_scrape "$1"
        ;;

    aim)
        aim_monitor
        ;;

    feed)
        if [[ $# -lt 1 ]]; then error "feed <source> [outdir]"; exit 1; fi
        feed_blog_and_request_project "$1" "${2:-./ai_generated}"
        ;;

    *) # default: treat as file(s) or prompt/url
        # if multiple args, treat as files
        if [[ $# -ge 0 ]]; then
            # if first arg looks like URL or file, get its prompt
            if [[ "$mode" =~ ^https?:// ]]; then
                info "Prompt ist URL: $mode"
                fetch_url "$mode"
            elif [[ -f "$mode" ]]; then
                ai_handle_file "$mode"
            else
                # treat entire args as inline prompt
                prompt_text="$mode $*"
                info "Inline-Prompt verarbeitet (keine Modell-Aufruf in dieser CLI-Default):"
                printf '%s\n' "$prompt_text"
            fi
        fi
        ;;
esac

# Ende Skript