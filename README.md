#!/usr/bin/env bash
# Author: Aris Arjuna Noorsanto <exe.opcode@gmail.com>
# AI / AGI / AIM Unified Processing Tool - README generator

generate_readme() {
cat > README.md <<'EOF'
# 🧠 AI / AGI / AIM Unified Processing Tool

**Author:** Aris Arjuna Noorsanto `<exe.opcode@gmail.com>`  
**License:** Private / Inhouse Use Only  

---

## 📜 Overview

This project provides a **single-file automation tool** (`~/bin/ai`) for unified AI processing.  
All functionality is embedded in one script. No additional files are required.

---

## ⚙️ Core Modes

| Mode | Function |
|------|---------|
| `ai` | Single-file analysis & optimization (JS/DOM, HTML, CSS, ARIA, etc.) |
| `agi` | Multi-file pipeline, folder watch, recursive web scraping, screenshots |
| `aim` | MIME-aware autonomous monitoring (work in progress) |

---

## 📜 Universal Law

A string embedded in the script (`:BOF:` … `:EOF:`) defines:

- Symmetries, layout, and golden ratio handling  
- Subliminal guidance for repetitive and context-aware structures  
- Robust and visually attractive content organization  

All AI enhancements respect this law.

---

## 🛠 Features

- **Single-file processing:** `ai - file`  
- **Script-aware optimization:** `ai + script`  
- **Regex batch processing:** `ai * pattern`  
- **Environment scanning:** `ai .`  
- **Pipeline processing:** `ai : file1:file2:...`  
- **Backup system:** `$HOME/.ai_backups` (hidden, timestamped)  
- **JS/DOM enhancements:** CSS themes, AI comments on functions, semantic HTML upgrades  
- **Event listener monitoring** with comments  
- **Accessibility:** automatic ARIA roles  
- **Web scraping:** recursive, respecting `robots.txt`  
- **Screenshots:** portrait, landscape, square, custom virtual ratios  
- **Watch mode:** `agi + folder` triggers automatic processing on file changes  
- **Prompt processing:** URLs, local files, or direct strings, integrated with `ollama run gemma3:1b`  

---

## 📝 Rules & Guidelines

- All logic resides in a **single script file** (`~/bin/ai`)  
- Backups are stored externally but hidden  
- All commands **follow the Universal Law** guidance  
- Recursive, modular, and reusable routines prevent repeated processing  
- AI calls are **aware of file type, environment, and context**  
- Fallback behaviors exist for missing tools (`curl`, `wget`, `chromium`, `inotifywait`)  

---

## 🚀 Usage Examples

```bash
~/bin/ai - index.html            # Single file enhancement
~/bin/ai + script.js             # Script-aware processing
~/bin/ai * "*.html"              # Batch processing
~/bin/ai : index.html:style.css  # Pipeline
~/bin/ai .                       # Environment scan
~/bin/ai agi + ./project         # Watch folder
~/bin/ai agi - index.html        # Screenshot
~/bin/ai https://example.com     # Fetch URL and process