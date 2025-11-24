#!/usr/bin/env node
// unified-orchestrator.mjs
import express from 'express';
import { WebSocketServer } from 'ws';
import fs from 'fs/promises';
import { existsSync, copyFileSync } from 'fs';
import path from 'path';
import os from 'os';
import { spawn, execSync } from 'child_process';

const HOME_ROOT = process.env.HOME || (os.platform()==='win32'?process.env.USERPROFILE:'/home/node');
const BACKUP_DIR = path.join(HOME_ROOT,'.ai_backups');
await fs.mkdir(BACKUP_DIR,{recursive:true});
const PORT = 3000;
const LOCAL_MODELS = ['cube','core','loop','wave','coin','code'];

// ----------------------- Logging -----------------------
const log = (...args)=>console.log('\x1b[34m[*]\x1b[0m',...args);
const logSuccess = (...args)=>console.log('\x1b[32m[+]\x1b[0m',...args);
const logWarn = (...args)=>console.warn('\x1b[33m[!]\x1b[0m',...args);
const logError = (...args)=>console.error('\x1b[31m[-]\x1b[0m',...args);

// ----------------------- File Utilities -----------------------
async function backupFile(file){
    if(!existsSync(file)) return;
    const ts = new Date().toISOString().replace(/[:.-]/g,'');
    const dest = path.join(BACKUP_DIR, path.basename(file)+'.'+ts+'.bak');
    copyFileSync(file,dest);
    log('Backup created for', file,'->',dest);
}
async function readFile(file){ return existsSync(file)?await fs.readFile(file,'utf8'):''; }
async function writeFile(file,content){ await backupFile(file); await fs.writeFile(file,content,'utf8'); logSuccess(file+' saved'); }

// ----------------------- HTML/JS Enhancer -----------------------
async function htmlEnhance(file){
    if(!existsSync(file)) { logWarn('HTML not found:',file); return; }
    await backupFile(file);
    let content = await fs.readFile(file,'utf8');

    // Neon theme injection
    if(content.includes('<head>') && !content.includes('--main-bg')){
        content = content.replace(/<head>/i,'<head><style>:root{--main-bg:#0f0f2a;--main-fg:#fff;--btn-color:#ff00ff;--link-color:#ffff00;}</style>');
    }

    // AI comment to JS functions
    content = content.replace(/function\s+([a-zA-Z0-9_]+)\s*\(([^)]*)\)\s*\{/g,'function $1($2) { /* AI: optimize this function */');

    // Event listener monitoring
    content = content.replace(/\.addEventListener\((['"])(.*?)\1,(.*)\)/g,'.addEventListener($1$2$1, /* AI: monitored */$3)');

    // div.section -> <section>
    content = content.replace(/<div class="section"/gi,'<section class="section"');
    content = content.replace(/<\/div><!-- .section -->/gi,'</section>');

    // Accessibility roles
    content = content.replace(/<nav/gi,'<nav role="navigation"');
    content = content.replace(/<header/gi,'<header role="banner"');
    content = content.replace(/<main/gi,'<main role="main"');
    content = content.replace(/<footer/gi,'<footer role="contentinfo"');

    await fs.writeFile(file+'.processed',content,'utf8');
    logSuccess('Enhanced HTML saved as '+file+'.processed');
    return content;
}

// ----------------------- Ollama / Simulation -----------------------
async function runOllamaPrompt(prompt, ws){
    log('[PROMPT]', prompt);
    try{
        execSync('ollama --version',{stdio:'ignore'});
        log('[OLLAMA] Running real models');
        LOCAL_MODELS.forEach(model=>{
            const run = spawn('ollama',['run',model+':latest'],{stdio:['pipe','pipe','pipe']});
            run.stdin.write(prompt); run.stdin.end();
            run.stdout.on('data',data=>ws.send(JSON.stringify({type:'modelProgress',model,progress:data.toString()})));
        });
        setTimeout(()=>ws.send(JSON.stringify({type:'final',result:'[OLLAMA FINAL RESULT]'})),2000);
    }catch(e){
        logWarn('Ollama not found — simulated mode');
        LOCAL_MODELS.forEach(model=>{
            let progress=0;
            const interval=setInterval(()=>{
                progress+=Math.floor(Math.random()*10)+1;
                if(progress>100) progress=100;
                ws.send(JSON.stringify({type:'modelProgress',model,progress}));
                if(progress>=100){
                    clearInterval(interval);
                    ws.send(JSON.stringify({type:'modelDone',model,result:`[SIM ${model.toUpperCase()}] final chunk`}));
                }
            },100+Math.random()*150);
        });
        setTimeout(()=>ws.send(JSON.stringify({type:'final',result:LOCAL_MODELS.map(m=>`[SIM ${m}]`).join('\n')}),2500);
    }
}

// ----------------------- Batch / CRUD / SOAP / REST -----------------------
async function processFileOperation({op,file,data}){
    switch(op){
        case 'read': return await readFile(file);
        case 'write': await writeFile(file,data); return 'OK';
        case 'append': await writeFile(file,(await readFile(file))+data); return 'OK';
        case 'delete': await fs.unlink(file); return 'OK';
        default: throw new Error('Unsupported operation: '+op);
    }
}

// ----------------------- Express + WebSocket -----------------------
const app = express();
app.use(express.json());
app.use(express.static(path.join(process.cwd())));

const server = app.listen(PORT,()=>logSuccess('Cockpit at http://localhost:'+PORT));
const wss = new WebSocketServer({server});

wss.on('connection', ws=>{
    log('[WS] Client connected');

    ws.on('message', async msg=>{
        try{
            const data = JSON.parse(msg);
            switch(data.type){
                case 'prompt':
                    // Optionally enhance HTML first
                    if(data.file) await htmlEnhance(data.file);
                    await runOllamaPrompt(data.prompt, ws);
                    break;
                case 'fileOp':
                    const result = await processFileOperation(data);
                    ws.send(JSON.stringify({type:'fileOpResult',id:data.id,result}));
                    break;
            }
        }catch(e){ ws.send(JSON.stringify({type:'error',message:e.message})); }
    });

    ws.on('close',()=>log('[WS] Client disconnected'));
});

