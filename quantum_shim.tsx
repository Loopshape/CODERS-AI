/*
  quantum_shim.js
  Shim to hook into EnhancedQuantumOrchestrator to:
   - generate secure SHA-256 genesis
   - derive per-agent origin hashes
   - rehash with genesis (memory staging)
   - compute SHA-128 (first 128 bits of SHA-256) and MD5 for backtrace fingerprints
   - collect candidate fragments from agents, score by entropy, sort, assemble final HTML/code
   - persist streams into localStorage (quantum_realstream / quantum_final_assembly)
   - exposes initQuantumShim(orchestrator, opts) and runQuantumCycle(prompt, context)
*/

(function(global){
  "use strict";

  // --- Helpers: SHA-256, SHA-128 (first 128 bits), MD5 (inline) --- //
  async function sha256Hex(message) {
    const enc = new TextEncoder();
    const data = enc.encode(message);
    const digest = await crypto.subtle.digest('SHA-256', data);
    return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2,'0')).join('');
  }

  async function sha128Hex(message) {
    const full = await sha256Hex(message);
    return full.slice(0,32);
  }

  // Minimal MD5 implementation (compact derivation)
  function md5cycle(x, k) {
    var a = x[0], b = x[1], c = x[2], d = x[3];

    a = ff(a, b, c, d, k[0], 7, -680876936);
    d = ff(d, a, b, c, k[1], 12, -389564586);
    c = ff(c, d, a, b, k[2], 17, 606105819);
    b = ff(b, c, d, a, k[3], 22, -1044525330);
    a = ff(a, b, c, d, k[4], 7, -176418897);
    d = ff(d, a, b, c, k[5], 12, 1200080426);
    c = ff(c, d, a, b, k[6], 17, -1473231341);
    b = ff(b, c, d, a, k[7], 22, -45705983);
    a = ff(a, b, c, d, k[8], 7, 1770035416);
    d = ff(d, a, b, c, k[9], 12, -1958414417);
    c = ff(c, d, a, b, k[10], 17, -42063);
    b = ff(b, c, d, a, k[11], 22, -1990404162);
    a = ff(a, b, c, d, k[12], 7, 1804603682);
    d = ff(d, a, b, c, k[13], 12, -40341101);
    c = ff(c, d, a, b, k[14], 17, -1502002290);
    b = ff(b, c, d, a, k[15], 22, 1236535329);

    a = gg(a, b, c, d, k[1], 5, -165796510);
    d = gg(d, a, b, c, k[6], 9, -1069501632);
    c = gg(c, d, a, b, k[11], 14, 643717713);
    b = gg(b, c, d, a, k[0], 20, -373897302);
    a = gg(a, b, c, d, k[5], 5, -701558691);
    d = gg(d, a, b, c, k[10], 9, 38016083);
    c = gg(c, d, a, b, k[15], 14, -660478335);
    b = gg(b, c, d, a, k[4], 20, -405537848);
    a = gg(a, b, c, d, k[9], 5, 568446438);
    d = gg(d, a, b, c, k[14], 9, -1019803690);
    c = gg(c, d, a, b, k[3], 14, -187363961);
    b = gg(b, c, d, a, k[8], 20, 1163531501);
    a = gg(a, b, c, d, k[13], 5, -1444681467);
    d = gg(d, a, b, c, k[2], 9, -51403784);
    c = gg(c, d, a, b, k[7], 14, 1735328473);
    b = gg(b, c, d, a, k[12], 20, -1926607734);

    a = hh(a, b, c, d, k[5], 4, -378558);
    d = hh(d, a, b, c, k[8], 11, -2022574463);
    c = hh(c, d, a, b, k[11], 16, 1839030562);
    b = hh(b, c, d, a, k[14], 23, -35309556);
    a = hh(a, b, c, d, k[1], 4, -1530992060);
    d = hh(d, a, b, c, k[4], 11, 1272893353);
    c = hh(c, d, a, b, k[7], 16, -155497632);
    b = hh(b, c, d, a, k[10], 23, -1094730640);
    a = hh(a, b, c, d, k[13], 4, 681279174);
    d = hh(d, a, b, c, k[0], 11, -358537222);
    c = hh(c, d, a, b, k[3], 16, -722521979);
    b = hh(b, c, d, a, k[6], 23, 76029189);
    a = hh(a, b, c, d, k[9], 4, -640364487);
    d = hh(d, a, b, c, k[12], 11, -421815835);
    c = hh(c, d, a, b, k[15], 16, 530742520);
    b = hh(b, c, d, a, k[2], 23, -995338651);

    a = ii(a, b, c, d, k[0], 6, -198630844);
    d = ii(d, a, b, c, k[7], 10, 1126891415);
    c = ii(c, d, a, b, k[14], 15, -1416354905);
    b = ii(b, c, d, a, k[5], 21, -57434055);
    a = ii(a, b, c, d, k[12], 6, 1700485571);
    d = ii(d, a, b, c, k[3], 10, -1894986606);
    c = ii(c, d, a, b, k[10], 15, -1051523);
    b = ii(b, c, d, a, k[1], 21, -2054922799);
    a = ii(a, b, c, d, k[8], 6, 1873313359);
    d = ii(d, a, b, c, k[15], 10, -30611744);
    c = ii(c, d, a, b, k[6], 15, -1560198380);
    b = ii(b, c, d, a, k[13], 21, 1309151649);
    a = ii(a, b, c, d, k[4], 6, -145523070);
    d = ii(d, a, b, c, k[11], 10, -1120210379);
    c = ii(c, d, a, b, k[2], 15, 718787259);
    b = ii(b, c, d, a, k[9], 21, -343485551);

    x[0] = (x[0] + a) & 0xffffffff;
    x[1] = (x[1] + b) & 0xffffffff;
    x[2] = (x[2] + c) & 0xffffffff;
    x[3] = (x[3] + d) & 0xffffffff;
  }

  function cmn(q, a, b, x, s, t) {
    a = (a + q + x + t) & 0xffffffff;
    return ((a << s) | (a >>> (32 - s))) + b & 0xffffffff;
  }
  function ff(a,b,c,d,x,s,t){ return cmn((b & c) | ((~b) & d), a, b, x, s, t); }
  function gg(a,b,c,d,x,s,t){ return cmn((b & d) | (c & (~d)), a, b, x, s, t); }
  function hh(a,b,c,d,x,s,t){ return cmn(b ^ c ^ d, a, b, x, s, t); }
  function ii(a,b,c,d,x,s,t){ return cmn(c ^ (b | (~d)), a, b, x, s, t); }

  function md5blk(s) {
    var md5blks = [], i;
    for (i = 0; i < 64; i += 4) {
      md5blks[i>>2] = s.charCodeAt(i) + (s.charCodeAt(i+1) << 8) + (s.charCodeAt(i+2) << 16) + (s.charCodeAt(i+3) << 24);
    }
    return md5blks;
  }

  function md51(s) {
    var n = s.length,
        state = [1732584193, -271733879, -1732584194, 271733878],
        i, tail;

    for (i = 64; i <= n; i += 64) {
      md5cycle(state, md5blk(s.substring(i-64, i)));
    }
    s = s.substring(i-64);
    tail = new Array(16).fill(0);
    for (i = 0; i < s.length; i++) tail[i>>2] |= s.charCodeAt(i) << ((i%4) << 3);
    tail[i>>2] |= 0x80 << ((i%4) << 3);
    if (i > 55) {
      md5cycle(state, tail);
      tail = new Array(16).fill(0);
    }
    var bitLen = n * 8;
    tail[14] = bitLen & 0xffffffff;
    tail[15] = (bitLen / Math.pow(2,32)) & 0xffffffff;
    md5cycle(state, tail);
    return state;
  }

  function rhex(n) {
    var s='', j=0;
    for (; j < 4; j++) s += ('0' + ((n >> (j*8+4)) & 0x0F).toString(16)).slice(-1) + ('0' + ((n >> (j*8)) & 0x0F).toString(16)).slice(-1);
    return s;
  }

  function hex(x) {
    for (var i = 0; i < x.length; i++) x[i] = rhex(x[i]);
    return x.join('');
  }

  function md5(s) { return hex(md51(s)); }

  // --- entropy approximator: popcount of sha256 bytes normalized --- //
  function entropyFromHex(hex) {
    let bits = 0;
    for (let i = 0; i < hex.length; i += 2) {
      const byte = parseInt(hex.slice(i, i+2), 16) || 0;
      let x = byte;
      x = x - ((x >> 1) & 0x55);
      x = (x & 0x33) + ((x >> 2) & 0x33);
      bits += (((x + (x >> 4)) & 0x0F) * 1);
    }
    const maxBits = (hex.length/2) * 8;
    return bits / maxBits;
  }

  // --- Shim core: wiring into an existing orchestrator object --- //
  function initQuantumShim(orchestrator, opts = {}) {
    if (!orchestrator) throw new Error('initQuantumShim requires an orchestrator object reference');
    const config = Object.assign({
      maxRounds: 3,
      modelPool: ['core','loop','2244','coin','code'],
      persistKeys: {
        realstream: 'quantum_realstream',
        final: 'quantum_final_assembly',
        origins: 'quantum_origin_fragments'
      },
      ollamaMode: 'simulate'
    }, opts);

    const state = {
      orchestrator,
      config,
      genesis: null,
      agents: {},
      running: false
    };

    function persistFragment(fragment) {
      const k = config.persistKeys.realstream;
      const arr = JSON.parse(localStorage.getItem(k) || '[]');
      arr.push(fragment);
      localStorage.setItem(k, JSON.stringify(arr));
    }

    async function generateGenesis(prompt, context) {
      const ts = Date.now().toString();
      const body = `GENESIS|${ts}|${prompt}|${(context||'').slice(0,1000)}`;
      const g = await sha256Hex(body);
      state.genesis = g;
      localStorage.setItem('quantum_genesisHash', g);
      if (typeof orchestrator.onGenesis === 'function') try { orchestrator.onGenesis(g); } catch(e){}
      return g;
    }

    async function registerAgents(agentList) {
      for (const a of agentList) {
        const spec = { role: a.role || 'relay', expertise: a.expertise || [] };
        const originInput = `${state.genesis}|${a.id}|${spec.role}|${(spec.expertise||[]).join(',')}`;
        const originHash = await sha256Hex(originInput);
        state.agents[a.id] = { id: a.id, role: spec.role, expertise: spec.expertise, hash: originHash, model: mapRoleToModel(spec.role, config.modelPool) };
        const idx = JSON.parse(localStorage.getItem(config.persistKeys.origins) || '{}');
        idx[a.id] = { hash: originHash, role: spec.role, ts: Date.now() };
        localStorage.setItem(config.persistKeys.origins, JSON.stringify(idx));
      }
      return Object.values(state.agents);
    }

    function mapRoleToModel(role, pool) {
      const normalized = (role||'').toLowerCase();
      if (pool.includes(normalized)) return normalized;
      const sum = (normalized.split('').reduce((s,ch)=>s+ch.charCodeAt(0),0) || Date.now()) >>> 0;
      return pool[ sum % pool.length ];
    }

    async function agentRound(agent, prompt, context, roundIndex) {
      const hist = JSON.stringify((orchestrator.getHistory && orchestrator.getHistory()) || []).slice(-200);
      const rehashInput = `${agent.hash}|${state.genesis}|R${roundIndex}|${hist}`;
      const rehash = await sha256Hex(rehashInput);
      const sha128 = await sha128Hex(rehashInput);
      const md5sum = md5(rehashInput);

      const instruction = [
        `GENESIS:${state.genesis}`,
        `ORIGIN:${agent.hash}`,
        `MODEL:${agent.model}`,
        `ROUND:${roundIndex}`,
        `REHASH:${rehash}`,
        `SHA128:${sha128}`,
        `MD5:${md5sum}`,
        `PROMPT:`,
        prompt,
        `CONTEXT:`,
        (context||'').slice(0,1000)
      ].join('\n');

      let responseText = null;
      if (config.ollamaMode === 'local' && typeof orchestrator.ollamaCall === 'function') {
        try {
          const resp = await orchestrator.ollamaCall(agent.model, instruction, { max_tokens: 512 });
          responseText = (resp && (resp.text || resp.output || resp)) || String(resp || '');
        } catch(e) {
          console.warn('orchestrator.ollamaCall failed, falling back to simulate', e);
          config.ollamaMode = 'simulate';
        }
      }
      if (!responseText) {
        const seed = await sha256Hex(agent.model + '|' + instruction);
        responseText = `// simulated fragment from ${agent.id} (${agent.model})\n// seed:${seed.slice(0,24)}\n// role:${agent.role}\n\n` + `/* BEGIN FRAGMENT */\nfunction frag_${agent.id.replace(/[^a-z0-9]/gi,'_')}_r${roundIndex}(){\n  return ${JSON.stringify('// seed: '+seed)};\n}\n/* END FRAGMENT */\n`;
      }

      const candidateHash = await sha256Hex(responseText);
      const entropy = entropyFromHex(candidateHash);

      const fragment = {
        agent: agent.id,
        role: agent.role,
        model: agent.model,
        round: roundIndex,
        rehash,
        sha128,
        md5: md5sum,
        candidate: responseText,
        candidateHash,
        entropy,
        ts: Date.now()
      };

      persistFragment(fragment);
      if (typeof orchestrator.onFragment === 'function') try { orchestrator.onFragment(fragment); } catch(e){}
      return fragment;
    }

    async function runQuantumCycle(prompt, context) {
      if (!state.genesis) await generateGenesis(prompt, context);
      state.running = true;
      const agentList = Object.values(state.agents);
      const rounds = config.maxRounds || 3;
      const collected = [];

      for (let r=0; r<rounds; r++) {
        const promises = agentList.map(a => agentRound(a, prompt, context, r));
        const results = await Promise.all(promises);
        collected.push(...results);
        if (typeof orchestrator.onRoundComplete === 'function') {
          try { orchestrator.onRoundComplete(r, results); } catch(e) {}
        }
      }

      collected.sort((a,b)=> (b.entropy - a.entropy) || (b.ts - a.ts));
      const assembled = [];
      let cum = 0;
      const target = Math.max(0.7, (collected[0] ? collected[0].entropy*0.5 : 0.7));
      for (const f of collected) {
        assembled.push(f);
        cum += f.entropy;
        if (assembled.length >= 6 || cum >= target) break;
      }

      const finalHtml = buildFinalHTML(prompt, context || '', assembled);
      localStorage.setItem(config.persistKeys.final, JSON.stringify({ assembled, finalHtml, ts: Date.now() }));
      if (typeof orchestrator.onFinalAssembly === 'function') {
        try { orchestrator.onFinalAssembly({ assembled, finalHtml }); } catch(e){}
      }

      state.running = false;
      return { assembled, finalHtml };
    }

    function buildFinalHTML(prompt, context, assembledFragments) {
      const meta = `<!-- Generated by Quantum Shim — prompt: ${escapeHtml(prompt).slice(0,140)} — fragments: ${assembledFragments.length} -->`;
      const head = `
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="generator" content="quantum_shim"/>
<meta name="prompt" content="${escapeHtml(prompt).slice(0,200)}"/>
<title>Quantum Assembled Result</title>
<style>
  body{font-family:system-ui,Segoe UI,Roboto,Helvetica,Arial,sans-serif;padding:18px;background:#0f172a;color:#e6eef6}
  pre{background:#031024;padding:10px;border-radius:6px;overflow:auto}
  .frag-meta{font-size:11px;color:#8aa0c8;margin-bottom:6px}
</style>
</head>
<body>
${meta}
<h1>Assembled Result</h1>
<p><strong>Prompt:</strong> ${escapeHtml(prompt)}</p>
<div id="fragments">
`;
      const fragsHtml = assembledFragments.map((f, i) => {
        return `<section class="fragment" id="frag-${i}">
  <div class="frag-meta">#${i+1} • agent: ${escapeHtml(f.agent)} • model: ${escapeHtml(f.model)} • entropy: ${f.entropy.toFixed(3)}</div>
  <pre>${escapeHtml(f.candidate)}</pre>
</section>`;
      }).join("\n\n");

      const scripts = `</div>
<script>
  console.log('Quantum assembled fragments:', ${JSON.stringify(assembledFragments.map(f=>({agent:f.agent,model:f.model,entropy:f.entropy})))});
</script>
</body>
</html>`;
      return head + fragsHtml + scripts;
    }

    function escapeHtml(s){ return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

    const api = {
      state,
      generateGenesis,
      registerAgents,
      runQuantumCycle,
      agentRound,
      buildFinalHTML,
      async autoRegisterFromOrchestrator() {
        if (!orchestrator.getAgentList) return [];
        const list = orchestrator.getAgentList();
        const mapped = list.map(x => ({ id: x.id || x.name || ('agent-'+Math.random().toString(36).slice(2,8)), role: x.role || x.model || 'relay', expertise: x.expertise || [] }));
        return registerAgents(mapped);
      }
    };

    return api;
  }

  global.initQuantumShim = initQuantumShim;

})(this);

