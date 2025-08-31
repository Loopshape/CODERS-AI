# 🧠 AI / AGI / AIM Unified Processing Tool branched

**Autor:** Aris Arjuna Noorsanto `<exe.opcode@gmail.com>`  
**Lizenz:** Privat / Inhouse Use Only  

---

## 📜 Agenda & Regeln

Dieses Projekt basiert auf einem **einzigen Skript** (`~/bin/ai`).  
Alle Funktionen werden direkt in dieser Datei gepflegt.  
Es werden **keine weiteren Dateien** angelegt oder benötigt.  

### 1. Grundidee
- `ai` → Standardmodus, Einzeldatei-Analyse und Optimierung.  
- `agi` → Multifile-Input, zusammengeführt in **Singlefile-Output**.  
- `aim` → Monitoring & MIME-bewusstes Verhalten.  

### 2. Universalgesetz
Im Skript ist ein String `UNIVERSAL_LAW` eingebettet (`:BOF:` … `:EOF:`).  
Dieses bestimmt:
- Symmetrien & Layout (goldener Schnitt, Proximität).  
- Subliminale Führung für Wiederholung und Kontexte.  
- Robuste & attraktive Strukturen.  

### 3. Features
- **JS/DOM-Optimierung** für HTML-Dateien.  
- **CSS-Theme-Injektion** mit Neon-Design.  
- **Barrierefreiheit** durch ARIA-Rollen.  
- **Eventlistener-Monitoring** (mit AI-Kommentaren).  
- **Webscraping** (inkl. robots.txt, Rootfolder, Screenshot).  
- **Monitoring** von Dateien/Verzeichnissen (`inotifywait`).  

### 4. Workflow
Beim Start wird sichergestellt, dass `ollama` läuft:
```bash
pkill ollama
ollama serve &