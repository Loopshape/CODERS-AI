// ==UserScript==
// @name         AI Orchestrator + Editor (Ace) for CODERS-AI
// @namespace    https://example.com/ai-orc-editor
// @version      1.0.0
// @description  Adds an Ace code editor into the orchestrator UI to edit remote index.html or JS live and re-inject it.
// @match        *://*/*
// @grant        GM_xmlhttpRequest
// @grant        GM_addStyle
// @grant        GM_registerMenuCommand
// @run-at       document-idle
// ==/UserScript==

(function(){
  'use strict';

  const REMOTE_URL = 'https://raw.githubusercontent.com/Loopshape/CODERS-AI/refs/heads/main/index.html';
  const ACE_CDN = 'https://cdnjs.cloudflare.com/ajax/libs/ace/1.23.1/ace.js';

  // utility to inject a script
  function injectScript(src) {
    return new Promise((resolve, reject) => {
      const s = document.createElement('script');
      s.src = src;
      s.onload = () => resolve();
      s.onerror = reject;
      document.head.appendChild(s);
    });
  }

  // load Ace
  async function loadAce() {
    if (!window.ace) {
      await injectScript(ACE_CDN);
      // wait a tiny bit
      await new Promise(r => setTimeout(r, 50));
    }
  }

  // fetch remote text
  function fetchRemote() {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method: 'GET',
        url: REMOTE_URL,
        nocache: true,
        onload: (res) => {
          if (res.status === 200) resolve(res.responseText);
          else reject(new Error('Failed to fetch remote: ' + res.status));
        },
        onerror: e => reject(e)
      });
    });
  }

  // Create editor panel
  async function createEditorPanel() {
    await loadAce();
    const panel = document.createElement('div');
    panel.id = 'ai-orc-editor-panel';
    panel.style = `
      position: fixed;
      right: 12px; bottom: 12px;
      width: 600px; height: 400px;
      background: #1e1e1e; border: 1px solid #444;
      z-index: 999999; display: flex; flex-direction: column;
    `;
    document.body.appendChild(panel);

    // toolbar
    const toolbar = document.createElement('div');
    toolbar.style = 'flex: 0 0 auto; padding: 4px; background: #333; color: white; display: flex; gap: 8px;';
    panel.appendChild(toolbar);

    const btnLoad = document.createElement('button');
    btnLoad.textContent = 'Load';
    toolbar.appendChild(btnLoad);

    const btnSave = document.createElement('button');
    btnSave.textContent = 'Apply';
    toolbar.appendChild(btnSave);

    const btnClose = document.createElement('button');
    btnClose.textContent = 'Close';
    toolbar.appendChild(btnClose);

    // editor container
    const editorDiv = document.createElement('div');
    editorDiv.id = 'ai-orc-ace-editor';
    editorDiv.style = 'flex: 1; width: 100%;';
    panel.appendChild(editorDiv);

    // initialize Ace
    const editor = ace.edit(editorDiv);
    editor.setTheme("ace/theme/monokai");
    editor.session.setMode("ace/mode/html");  // assuming editing HTML

    // load remote on click
    btnLoad.addEventListener('click', async () => {
      try {
        const text = await fetchRemote();
        editor.setValue(text, -1);  // -1 moves cursor to top
      } catch(e) {
        alert('Load error: ' + e);
      }
    });

    // apply button: write the code back into DOM (or fallback store)
    btnSave.addEventListener('click', () => {
      const code = editor.getValue();
      // naive injection: wipe <html> or body? depends on your use case
      // Here: overwrite body.innerHTML (dangerous, be careful)
      document.body.innerHTML = code;
      alert('Applied editor content into page’s body (be careful!).');
    });

    // close
    btnClose.addEventListener('click', () => {
      panel.remove();
    });
  }

  // Register in Tampermonkey menu
  if (typeof GM_registerMenuCommand === 'function') {
    GM_registerMenuCommand('AI-Orc: Open Editor', createEditorPanel);
  }

  // Optionally auto-open
  createEditorPanel();

})();
