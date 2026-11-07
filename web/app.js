// Foteka Web: private, browser-local Visual Collections.
// No photo content is transmitted to a server. Safari selects images explicitly.
const CATEGORIES=[
  {id:'pendente',name:'Aguardando análise',icon:'review',a:'#91aba5',b:'#567470'},
  {id:'pessoal',name:'Fotos pessoais',icon:'image',a:'#6aa7b0',b:'#315a78'},
  {id:'projetos',name:'Projetos',icon:'folder',a:'#74ad91',b:'#285f58'},
  {id:'documentos',name:'Documentos',icon:'doc',a:'#aaa9ad',b:'#64728a'},
  {id:'pokemon',name:'Pokémon TCG',icon:'grid',a:'#bbaa72',b:'#85734b'},
  {id:'compras',name:'Compras',icon:'folder',a:'#d9b69d',b:'#997663'},
  {id:'capturas',name:'Capturas de tela',icon:'phone',a:'#99a1bd',b:'#596583'},
  {id:'outros',name:'Outros',icon:'image',a:'#a2bdb5',b:'#647b78'}
];
const TABS=[['galeria','Galeria','grid'],['revisao','Revisão','review'],['regras','IA visual','sparkle'],['ajustes','Ajustes','settings']];
const DB_NAME='foteka-local-v1';
const VISION_VERSION='mobileclip-s0-web-v2';
let db;
const state={tab:'galeria',filter:'all',search:'',photos:[],rules:[],processing:false,selected:null,storage:null,visionBusy:false,visionDone:0,visionTotal:0,visionMessage:'',visionError:''};
const urls=new Map();
const el=id=>document.getElementById(id);
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const icon=(name,cls='icon')=>`<svg class="${cls}" aria-hidden="true"><use href="#i-${name}"></use></svg>`;
const cat=id=>CATEGORIES.find(x=>x.id===id)||CATEGORIES[CATEGORIES.length-1];
const count=id=>state.photos.filter(x=>x.category===id).length;
const pending=()=>state.photos.filter(x=>!x.confirmed);
const pendingVisual=()=>state.photos.filter(p=>!p.confirmed&&!p.manualCategory&&p.reason!=='Categoria ajustada manualmente'&&p.visionVersion!==VISION_VERSION);
const photoCount=()=>state.photos.length;
const fmtBytes=v=>v>=1024*1024?`${(v/1024/1024).toFixed(1)} MB`:`${Math.round(v/1024)} KB`;
const dateFmt=x=>new Date(x).toLocaleDateString('pt-BR',{day:'2-digit',month:'short',year:'numeric'});

function openDatabase(){
  return new Promise((resolve,reject)=>{
    const req=indexedDB.open(DB_NAME,1);
    req.onupgradeneeded=()=>{
      const d=req.result;
      d.createObjectStore('photos',{keyPath:'id'});
      d.createObjectStore('rules',{keyPath:'id'});
    };
    req.onsuccess=()=>resolve(req.result);
    req.onerror=()=>reject(req.error);
    req.onblocked=()=>reject(new Error('Feche outras abas do Foteka e tente novamente.'));
  });
}
function storeOp(table,mode,callback){
  return new Promise((resolve,reject)=>{
    const tx=db.transaction(table,mode),store=tx.objectStore(table);
    let req;try{req=callback(store)}catch(error){reject(error);return}
    tx.oncomplete=()=>resolve(req?.result);
    tx.onerror=()=>reject(tx.error||req?.error);
    tx.onabort=()=>reject(tx.error||new Error('Operação interrompida.'));
  });
}
const dbAll=name=>storeOp(name,'readonly',s=>s.getAll());
const dbPut=(name,val)=>storeOp(name,'readwrite',s=>s.put(val));
const dbDelete=(name,id)=>storeOp(name,'readwrite',s=>s.delete(id));
const dbClear=name=>storeOp(name,'readwrite',s=>s.clear());

async function initialize(){
  try{
    db=await openDatabase();
    state.photos=(await dbAll('photos')).sort((a,b)=>b.importedAt-a.importedAt);
    // Migrate previous filename-based guesses. Keep decisions confirmed by users.
    for(const photo of state.photos){
      if(photo.confirmed||photo.manualCategory||photo.reason==='Categoria ajustada manualmente')continue;
      if(photo.visionVersion!==VISION_VERSION){
        photo.category='pendente';photo.reason='Aguardando análise do conteúdo da imagem';
        photo.visionVersion=null;photo.suggestedCategory=null;
        await dbPut('photos',photo);
      }
    }
    if(navigator.storage?.estimate)state.storage=await navigator.storage.estimate().catch(()=>null);
    setupEvents();render();registerServiceWorker();
  }catch(error){
    el('main').innerHTML=`<div class="empty"><h3>Não foi possível abrir a biblioteca local.</h3><p>${esc(error.message)}. Verifique se o Safari está fora do modo privado e se o armazenamento está liberado.</p><button class="button primary" onclick="location.reload()">Tentar novamente</button></div>`;
  }
}
async function registerServiceWorker(){
  if('serviceWorker' in navigator && location.protocol==='https:'){
    try{await navigator.serviceWorker.register('/sw.js')}catch(e){console.warn('Offline unavailable',e)}
  }
}
function urlFor(photo,original=false){
  const key=photo.id+(original?':original':':thumb');
  if(!urls.has(key))urls.set(key,URL.createObjectURL(original?photo.blob:photo.thumbnail||photo.blob));
  return urls.get(key);
}
function revokeUrls(id){
  for(const key of [id+':original',id+':thumb']){
    if(urls.has(key)){URL.revokeObjectURL(urls.get(key));urls.delete(key)}
  }
}
function classify(){
  // Automated photo filenames (IMG_1234.HEIC) contain no visual semantics.
  return {category:'pendente',reason:'Aguardando análise do conteúdo da imagem'};
}
function buildThumbnail(blob){
  return new Promise((resolve,reject)=>{
    const source=URL.createObjectURL(blob);
    const img=new Image();
    img.onload=()=>{
      try{
        const max=900,scale=Math.min(1,max/Math.max(img.naturalWidth,img.naturalHeight));
        const canvas=document.createElement('canvas');
        canvas.width=Math.max(1,Math.round(img.naturalWidth*scale));
        canvas.height=Math.max(1,Math.round(img.naturalHeight*scale));
        canvas.getContext('2d',{alpha:false}).drawImage(img,0,0,canvas.width,canvas.height);
        canvas.toBlob(data=>{URL.revokeObjectURL(source);data?resolve(data):reject(new Error('Miniatura indisponível'))},'image/jpeg',.83);
      }catch(error){URL.revokeObjectURL(source);reject(error)}
    };
    img.onerror=()=>{URL.revokeObjectURL(source);reject(new Error('Imagem não suportada pelo navegador'))};
    img.src=source;
  });
}
async function importFiles(fileList){
  const chosen=[...fileList];
  if(!chosen.length)return;
  if(state.processing)return;
  state.processing=true;render();let added=0,skipped=0;
  const seen=new Set(state.photos.map(p=>p.fingerprint));
  for(const file of chosen){
    if(!(file.type.startsWith('image/')||/\.(heic|heif)$/i.test(file.name))||file.size>45*1024*1024){
      skipped++;continue;
    }
    const fingerprint=`${file.name}:${file.size}:${file.lastModified}`;
    if(seen.has(fingerprint)){skipped++;continue}
    try{
      const {category,reason}=classify();
      const thumbnail=await buildThumbnail(file).catch(()=>null);
      const item={
        id:crypto.randomUUID?crypto.randomUUID():`p-${Date.now()}-${Math.random().toString(36).slice(2)}`,
        fingerprint,name:file.name,size:file.size,type:file.type,
        importedAt:Date.now(),modifiedAt:file.lastModified||Date.now(),
        category,reason,confirmed:false,visionVersion:null,manualCategory:false,blob:file,thumbnail
      };
      await dbPut('photos',item);
      state.photos.unshift(item);seen.add(fingerprint);added++;
    }catch(error){console.error('Import failed',file.name,error);skipped++}
  }
  state.processing=false;state.tab='galeria';state.filter='all';state.search='';render();
  toast(`${added} imagem(ns) importada(s)${skipped?` · ${skipped} ignorada(s)`:''}`);
  if(added)void startVisualAnalysis(localStorage.getItem('foteka-vision-consent')==='1');
}
function navMarkup(mobile=false){
  return `<div class="${mobile?'bottom-items':'nav-list'}">${TABS.map(([id,label,symbol])=>`<button type="button" class="${mobile?'bottom-item':'nav-item'} ${state.tab===id?'active':''}" data-tab="${id}" aria-current="${state.tab===id?'page':'false'}">${icon(symbol)}<span>${label}</span>${id==='revisao'&&pending().length?`<span class="${mobile?'badge-dot':'count'}">${pending().length}</span>`:''}</button>`).join('')}</div>`;
}
function render(){
  el('desktop-nav').innerHTML=navMarkup();
  el('mobile-nav').innerHTML=navMarkup(true);
  el('main').innerHTML=state.tab==='galeria'?galleryView():state.tab==='revisao'?reviewView():state.tab==='regras'?rulesView():settingsView();
}
function pageHeader(kicker,title,subtitle,action=''){
  return `<header class="page-head"><div><p class="section-eyebrow">${kicker}</p><h1 class="page-title">${title}</h1><p class="page-subtitle">${subtitle}</p></div>${action}</header>`;
}
function collectionCard(category){
  const preview=state.photos.find(x=>x.category===category.id);
  return `<button type="button" class="collection" data-action="category" data-id="${category.id}" style="--tile-a:${category.a};--tile-b:${category.b}" aria-label="${esc(category.name)}, ${count(category.id)} imagens">
    ${preview?`<img alt="" src="${urlFor(preview)}" loading="lazy">`:''}
    <span class="tile-watermark">${icon(category.icon)}</span>
    <span class="tile-icon">${icon(category.icon)}</span>
    <span class="tile-copy"><b>${esc(category.name)}</b><span>${count(category.id)} ${count(category.id)===1?'imagem':'imagens'}</span></span>
  </button>`;
}
function filterPhotos(){
  return state.photos.filter(p=>(state.filter==='all'||p.category===state.filter)&&(!state.search||p.name.toLowerCase().includes(state.search.toLowerCase())));
}
function photoGallery(){
  const filtered=filterPhotos();
  if(!filtered.length)return `<div class="empty"><div class="empty-icon">${icon('image')}</div><h3>${photoCount()?'Nenhuma imagem encontrada':'Sua primeira coleção começa aqui'}</h3><p>${photoCount()?'Experimente outra busca ou selecione outra coleção.':'Escolha fotos no iPhone para começar a organizar suas imagens. Você decide quais arquivos compartilhar com o Foteka.'}</p><button type="button" class="button primary" data-action="import">${icon('plus')} Adicionar imagens</button></div>`;
  return `<div class="photo-grid">${filtered.map(photo=>`<button type="button" class="photo-tile" data-action="detail" data-id="${esc(photo.id)}" aria-label="Abrir ${esc(photo.name)}"><img loading="lazy" src="${urlFor(photo)}" alt=""><span class="photo-label">${esc(photo.name)}</span></button>`).join('')}</div>`;
}

function visualBanner(){
  const left=pendingVisual().length,busy=state.visionBusy;
  if(!left&&!busy&&!state.visionError)return '';
  return `<section class="vision-banner" id="vision-panel" aria-label="Análise visual com IA">
    <div class="vision-heading"><span class="vision-mark">${icon('sparkle')}</span><div>
    <strong>${busy?'IA visual em execução':'Organize pelas próprias imagens'}</strong>
    <small>${busy?`${state.visionDone} de ${state.visionTotal} analisadas`:`${left} fotos aguardam classificação visual`}</small></div></div>
    ${busy?`<p id="vision-message" class="vision-help">${esc(state.visionMessage)}</p><progress class="vision-progress" value="${state.visionDone}" max="${Math.max(1,state.visionTotal)}"></progress>`:
    `<p class="vision-help">A IA examina a imagem no iPhone, não apenas nomes como IMG_1234. Primeiro uso: download do modelo. Suas fotos não são enviadas.</p>
    ${state.visionError?`<p class="vision-error">${esc(state.visionError)}</p>`:''}
    <button type="button" class="button primary" data-action="visual-classify">${icon('sparkle')} Classificar com IA</button>`}
  </section>`;
}
function updateVisionProgress(){
  const message=el('vision-message');if(message)message.textContent=state.visionMessage;
  const progress=el('vision-panel')?.querySelector('progress');
  if(progress)progress.value=state.visionDone;
}
async function startVisualAnalysis(automatic=false){
  if(state.visionBusy)return;
  const items=pendingVisual();
  if(!items.length){toast('Nenhuma foto aguardando IA visual');return}
  if(localStorage.getItem('foteka-vision-consent')!=='1'){
    if(automatic)return;
    const ok=confirm('O Foteka precisa baixar um modelo de visão (pode consumir dezenas de MB) para classificar as fotos localmente, sem enviá-las para a nuvem. Continuar?');
    if(!ok)return;
    localStorage.setItem('foteka-vision-consent','1');
  }
  state.visionBusy=true;state.visionDone=0;state.visionTotal=items.length;
  state.visionMessage='Preparando modelo visual…';state.visionError='';render();
  try{
    const {loadVisualClassifier,classifyImageVisual}=await import('/vision.js');
    await loadVisualClassifier(p=>{state.visionMessage=p.detail||'Baixando modelo…';updateVisionProgress()});
    let changed=0,errors=0;
    for(const photo of items){
      state.visionMessage=`Classificando ${state.visionDone+1}/${state.visionTotal}: ${photo.name}`;updateVisionProgress();
      if(photo.confirmed||photo.manualCategory){state.visionDone++;continue}
      try{
        const result=await classifyImageVisual(photo.thumbnail||photo.blob);
        const old=photo.category;
        photo.category=result.reliable?result.category:'pendente';
        photo.suggestedCategory=result.category;
        photo.reason=result.reliable?'IA visual local · sugestão a confirmar':
          'IA visual incerta · escolha uma categoria na Revisão';
        photo.visionVersion=VISION_VERSION;
        photo.visualScore=Math.round(result.score*1000)/1000;
        if(old!==photo.category)changed++;
        await dbPut('photos',photo);
      }catch(error){
        console.warn('Foteka: unreadable image',photo.name,error);errors++;
        photo.visionVersion=null;photo.category='pendente';
        photo.reason='Imagem não analisada pela IA — revise manualmente';
        await dbPut('photos',photo);
      }
      state.visionDone++;updateVisionProgress();
      await new Promise(resolve=>setTimeout(resolve,0));
    }
    if(errors)state.visionError=`${errors} imagem(ns) não puderam ser analisadas. Revise manualmente.`;
    toast(`IA local concluída: ${changed} categorias atualizadas`);
  }catch(error){
    console.error('Foteka: visual model unavailable',error);
    state.visionError='IA visual indisponível neste iPhone ou conexão. Tente novamente no Wi-Fi ou escolha as categorias na Revisão.';
    toast('Modelo visual indisponível. Fotos preservadas.');
  }finally{state.visionBusy=false;state.visionMessage='';render()}
}

function galleryView(){
  if(state.filter!=='all'){
    const c=cat(state.filter);
    return `<div class="page-head"><div><button class="text-link" type="button" data-action="back">${icon('back')} Todas as coleções</button><p class="section-eyebrow" style="margin-top:16px">Coleção</p><h1 class="page-title">${esc(c.name)}</h1><p class="page-subtitle">${count(c.id)} imagens na coleção</p></div></div>
    <div class="photo-toolbar"><label class="search">${icon('search')}<input id="photo-search" value="${esc(state.search)}" autocomplete="off" placeholder="Buscar nesta coleção" aria-label="Buscar imagens"></label><button class="button primary" data-action="import">${icon('plus')} Adicionar</button></div><div id="gallery-results">${photoGallery()}</div>`;
  }
  return `${pageHeader('Sua biblioteca','Suas coleções','Uma galeria que acompanha o seu jeito de guardar memórias.')}
  <section class="hero" aria-label="Organização de fotografias">
    <div class="hero-content"><div class="hero-kicker">Visual Collections</div><h2>Guarde o que<br>realmente importa.</h2><p>Escolha suas fotos, organize em coleções e mantenha tudo sob seu controle.</p><button class="hero-cta" type="button" data-action="import">${icon('plus')} Adicionar fotos ${icon('arrow')}</button></div>
    <div class="hero-art" aria-hidden="true"><div class="art-card a"></div><div class="art-card b"></div><div class="art-card c"></div></div>
  </section>
  ${visualBanner()}
  <section class="stats-row" aria-label="Resumo da biblioteca">
    <div class="stat"><div class="stat-icon">${icon('image')}</div><div class="stat-copy"><strong>${photoCount()}</strong><small>Imagens</small></div></div>
    <div class="stat"><div class="stat-icon">${icon('review')}</div><div class="stat-copy"><strong>${pending().length}</strong><small>Revisar</small></div></div>
    <div class="stat"><div class="stat-icon">${icon('folder')}</div><div class="stat-copy"><strong>${CATEGORIES.filter(c=>c.id!=='pendente'&&count(c.id)).length}</strong><small>Coleções ativas</small></div></div>
  </section>
  <div class="section-heading"><h2>Suas coleções</h2><span class="hint">Organizadas por assunto</span></div>
  <section class="collections">${CATEGORIES.map(collectionCard).join('')}</section>
  <div class="section-heading"><h2>Imagens recentes</h2><span class="hint">${photoCount()} imagens</span></div>
  <div class="photo-toolbar"><label class="search">${icon('search')}<input id="photo-search" value="${esc(state.search)}" autocomplete="off" placeholder="Buscar por nome" aria-label="Buscar imagens"></label></div>
  <section id="gallery-results">${photoGallery()}</section>
  <p class="note" style="margin-top:18px">A versão web acessa apenas as imagens que você selecionar. Ela não lê sua Fototeca inteira nem cria álbuns no app Fotos.</p>`;
}
function categoryOptions(active){
  return CATEGORIES.map(c=>`<option value="${c.id}" ${c.id===active?'selected':''}>${esc(c.name)}</option>`).join('');
}
function reviewView(){
  const items=pending();
  return `${pageHeader('Organização local','Revisão','Confirme ou ajuste as sugestões antes de considerar as imagens organizadas.')}${visualBanner()}${items.length?`
  <div class="privacy-strip" style="margin-bottom:20px">${icon('sparkle')}<span>Categorias vêm apenas da análise dos pixels, nunca do nome automático. Imagens incertas ficam aguardando sua escolha.</span></div>
  <div class="review-grid">${items.map(p=>`<article class="review-card">
    <div class="review-media"><img loading="lazy" src="${urlFor(p)}" alt="${esc(p.name)}"></div>
    <div class="review-body"><h3 title="${esc(p.name)}">${esc(p.name)}</h3><small>${esc(p.reason)}</small>
    ${p.suggestedCategory&&p.category==='pendente'?`<p class="vision-help">Possível: ${esc(cat(p.suggestedCategory).name)} · confira antes de escolher.</p>`:''}
    <label class="form-label" for="cat-${esc(p.id)}">Categoria</label>
    <select id="cat-${esc(p.id)}" class="select" data-select-category="${esc(p.id)}">${categoryOptions(p.category)}</select>
    <div class="review-actions"><button type="button" class="button" data-action="detail" data-id="${esc(p.id)}">Visualizar</button><button type="button" class="button primary" data-action="confirm" data-id="${esc(p.id)}" ${p.category==='pendente'?'disabled title="Selecione uma categoria"':''}>${icon('check')} Confirmar</button></div>
    </div></article>`).join('')}</div>`:
    `<div class="empty"><div class="empty-icon">${icon('check')}</div><h3>Tudo revisado</h3><p>Quando novas imagens forem importadas, as sugestões aparecerão aqui para conferência.</p><button type="button" class="button primary" data-action="import">${icon('plus')} Adicionar imagens</button></div>`}`;
}
function rulesView(){
  const needs=pendingVisual().length;
  const uncertain=state.photos.filter(p=>!p.confirmed&&p.category==='pendente'&&p.visionVersion===VISION_VERSION).length;
  const ready=state.photos.filter(p=>p.visionVersion===VISION_VERSION&&p.category!=='pendente').length;
  return `${pageHeader('Organização inteligente','IA visual','As fotos são classificadas pelo conteúdo, não por nomes como IMG_1234.HEIC.')}
  ${visualBanner()}
  <section class="panel"><h3>Reconhecimento de conteúdo</h3>
  <p>O Foteka compara o que aparece na foto com exemplos visuais de pessoas, documentos, cartas Pokémon, projetos, compras e capturas de tela. O modelo é executado no próprio navegador e os resultados precisam ser conferidos.</p>
  <div class="stats-row">
    <div class="stat"><div class="stat-copy"><strong>${needs}</strong><small>A analisar</small></div></div>
    <div class="stat"><div class="stat-copy"><strong>${ready}</strong><small>Sugestões da IA</small></div></div>
    <div class="stat"><div class="stat-copy"><strong>${uncertain}</strong><small>Incertas</small></div></div>
  </div>
  <button class="button primary" type="button" data-action="reclassify" ${state.visionBusy?'disabled':''}>${icon('sparkle')} Reanalisar imagens não confirmadas</button>
  </section>
  <div class="privacy-strip">${icon('lock')}<span>Na primeira análise, um modelo é baixado. As fotos não são enviadas a servidor. Categorias confirmadas ou escolhidas manualmente não são substituídas.</span></div>`;
}
function settingsView(){
  const inStandalone=matchMedia('(display-mode: standalone)').matches||navigator.standalone;
  const used=state.storage?.usage;
  const storageText=used!=null?`Uso estimado pelo navegador: ${fmtBytes(used)}`:'Armazenamento local do navegador';
  return `${pageHeader('Seu espaço','Ajustes','Controle seus arquivos e a instalação do Foteka no iPhone.')}
  <div class="privacy-strip" style="margin-bottom:17px">${icon('lock')}<span><strong>Privacidade primeiro.</strong> As fotos importadas são armazenadas no navegador deste aparelho. O Foteka não envia imagens a servidores e não exige login.</span></div>
  <section class="panel">
    <h3>Classificação com IA visual</h3>
    <p>Baixe um modelo MobileCLIP para analisar imagens no próprio iPhone. Fotos não são enviadas ao servidor. Pode exigir Wi-Fi e memória disponível.</p>
    <button type="button" class="button primary" data-action="visual-classify" ${state.visionBusy?'disabled':''}>${icon('sparkle')} Analisar fotos pendentes</button>
    ${state.visionError?`<p class="vision-error">${esc(state.visionError)}</p>`:''}
  </section>
  <section class="panel">
    <h3>Biblioteca e privacidade</h3>
    <div class="setting-row"><span class="setting-icon">${icon('image')}</span><div><h3>Importar fotografias</h3><p>Selecione fotos ou imagens salvas no iPhone.</p></div><button class="button" data-action="import" type="button">Importar</button></div>
    <div class="setting-row"><span class="setting-icon">${icon('download')}</span><div><h3>Exportar índice</h3><p>Baixa um JSON com nomes e categorias, sem cópia das fotos.</p></div><button class="button" data-action="export" type="button">Exportar</button></div>
    <div class="setting-row"><span class="setting-icon">${icon('folder')}</span><div><h3>Armazenamento</h3><p>${esc(storageText)}. O Safari pode apagar dados locais se faltar espaço.</p></div><button class="button" data-action="persist" type="button">Proteger</button></div>
    <div class="setting-row"><span class="setting-icon">${icon('trash')}</span><div><h3>Apagar biblioteca web</h3><p>Remove deste navegador as cópias importadas. Não exclui as fotos originais do iPhone.</p></div><button class="button danger" data-action="clear" type="button">Limpar</button></div>
  </section>
  <section class="panel"><h3>Instalar na Tela de Início</h3>
    <p>${inStandalone?'O Foteka já está aberto como aplicativo da Tela de Início.':'No Safari do iPhone: toque no botão Compartilhar → Adicionar à Tela de Início → Adicionar. A primeira abertura precisa de conexão; depois a interface pode funcionar offline.'}</p>
    <div class="privacy-strip">${icon('phone')}<span>Não precisa de AltStore, conta de desenvolvedor nem assinatura Apple. Esta versão web não substitui a instalação do Foteka nativo em SwiftUI.</span></div>
  </section>
  <p class="note">Versão web 1.1 · Visual Collections V2. Após ativação, o modelo visual analisa as fotos no navegador. Não há leitura da Fototeca inteira, OCR ou sincronização com iCloud; resultados são sugestões. Para preservar imagens, mantenha os arquivos originais no Fotos ou Arquivos.</p>`;
}
function renderDetail(photo){
  if(!photo)return;
  state.selected=photo.id;
  const dialog=el('photo-dialog');
  el('dialog-content').innerHTML=`<div class="detail-grid">
    <div class="detail-image"><img alt="${esc(photo.name)}" src="${urlFor(photo,true)}"></div>
    <div class="detail-content"><div class="detail-heading"><h2>${esc(photo.name)}</h2><button class="icon-btn" data-action="close-detail" aria-label="Fechar">${icon('close')}</button></div>
    <span class="detail-meta">Importada em ${dateFmt(photo.importedAt)} · ${fmtBytes(photo.size)}<br>${esc(photo.reason||'Categoria ajustada manualmente')}</span>
    <label class="form-label" for="detail-category">Coleção atual</label>
    <select class="select" id="detail-category" data-select-category="${esc(photo.id)}">${categoryOptions(photo.category)}</select>
    <span class="detail-meta">${photo.confirmed?'Categoria confirmada':photo.category==='pendente'?'Escolha uma categoria acima':'Aguardando sua confirmação'}</span>
    <div class="detail-actions"><button class="button primary" data-action="confirm" data-id="${esc(photo.id)}">${icon('check')} Confirmar</button><button class="button" data-action="download" data-id="${esc(photo.id)}">${icon('download')} Original</button><button class="button danger" data-action="delete" data-id="${esc(photo.id)}">${icon('trash')} Apagar cópia</button></div>
    </div></div>`;
  if(!dialog.open)dialog.showModal();
}
function closeDetail(){
  el('photo-dialog').close();state.selected=null;
}
function toast(message){
  const area=el('toast-region');
  area.innerHTML=`<div class="toast">${esc(message)}</div>`;
  clearTimeout(toast.timer);
  toast.timer=setTimeout(()=>{area.innerHTML=''},3400);
}
async function saveCategory(id,category){
  const photo=state.photos.find(p=>p.id===id);
  if(!photo||!CATEGORIES.some(c=>c.id===category))return;
  photo.category=category;photo.confirmed=false;photo.manualCategory=category!=='pendente';photo.suggestedCategory=null;photo.reason=category==='pendente'?'Aguardando decisão':'Categoria ajustada manualmente';
  await dbPut('photos',photo);
  render();
  if(el('photo-dialog').open)renderDetail(photo);
}
async function confirmPhoto(id){
  const p=state.photos.find(p=>p.id===id);if(!p)return;
  if(p.category==='pendente'){toast('Escolha uma categoria antes de confirmar');return}
  p.confirmed=true;await dbPut('photos',p);if(el('photo-dialog').open)closeDetail();render();toast('Categoria confirmada');
}
async function deletePhoto(id){
  const p=state.photos.find(p=>p.id===id);if(!p)return;
  if(!confirm('Apagar a cópia desta foto do Foteka Web? A original no iPhone permanece intacta.'))return;
  await dbDelete('photos',id);
  state.photos=state.photos.filter(x=>x.id!==id);
  revokeUrls(id);if(el('photo-dialog').open)closeDetail();
  render();toast('Cópia local removida');
}
function downloadPhoto(id){
  const p=state.photos.find(p=>p.id===id);if(!p)return;
  const a=document.createElement('a');a.href=urlFor(p,true);a.download=p.name;a.click();
  toast('Abrindo arquivo original');
}
function exportIndex(){
  const data={
    application:'Foteka Web',version:1,exportedAt:new Date().toISOString(),
    reminder:'Metadados apenas; este arquivo não contém fotos',
    photos:state.photos.map(({name,category,confirmed,importedAt,reason,size})=>({name,category,confirmed,importedAt,reason,size}))
  };
  const blob=new Blob([JSON.stringify(data,null,2)],{type:'application/json'});
  const u=URL.createObjectURL(blob);
  const a=document.createElement('a');a.href=u;a.download='foteka-backup-metadados.json';a.click();
  setTimeout(()=>URL.revokeObjectURL(u),10_000);toast('Índice exportado, sem fotografias');
}
async function reclassifyPending(){
  for(const photo of state.photos){
    if(photo.confirmed||photo.manualCategory||photo.reason==='Categoria ajustada manualmente')continue;
    photo.category='pendente';photo.reason='Aguardando nova análise visual';
    photo.visionVersion=null;photo.suggestedCategory=null;
    await dbPut('photos',photo);
  }
  render();await startVisualAnalysis(false);
}
function setupEvents(){
  el('file-input').addEventListener('change',async e=>{
    await importFiles(e.target.files);
    e.target.value='';
  });
  document.addEventListener('click',async e=>{
    const nav=e.target.closest('[data-tab]');
    if(nav){state.tab=nav.dataset.tab;state.filter='all';state.search='';closeDetailIfOpen();render();window.scrollTo(0,0);return}
    const btn=e.target.closest('[data-action]');if(!btn)return;
    const action=btn.dataset.action,id=btn.dataset.id;
    try{
      switch(action){
        case 'import':el('file-input').click();break;
        case 'category':state.filter=id;state.search='';render();window.scrollTo(0,0);break;
        case 'back':state.filter='all';state.search='';render();break;
        case 'detail':renderDetail(state.photos.find(p=>p.id===id));break;
        case 'close-detail':closeDetail();break;
        case 'confirm':await confirmPhoto(id);break;
        case 'delete':await deletePhoto(id);break;
        case 'download':downloadPhoto(id);break;
        case 'export':exportIndex();break;
        case 'clear':
          if(confirm('Apagar todas as imagens importadas neste navegador? Suas fotos originais não serão afetadas.')){
            await dbClear('photos');for(const p of state.photos)revokeUrls(p.id);
            state.photos=[];closeDetailIfOpen();render();toast('Biblioteca local apagada');
          }
          break;
        case 'persist':
          if(navigator.storage?.persist){const ok=await navigator.storage.persist();toast(ok?'Armazenamento persistente concedido':'O Safari gerencia automaticamente o espaço local');}
          else toast('Esta opção não está disponível neste navegador');
          break;
        case 'reclassify':await reclassifyPending();break;
        case 'visual-classify':await startVisualAnalysis(false);break;
      }
    }catch(error){console.error(error);toast(`Não foi possível concluir: ${error.message}`)}
  });
  document.addEventListener('change',async e=>{
    const select=e.target.closest('[data-select-category]');
    if(select){
      try{await saveCategory(select.dataset.selectCategory,select.value)}
      catch(error){toast(`Falha ao salvar: ${error.message}`)}
    }
  });
  document.addEventListener('input',e=>{
    if(e.target.id!=='photo-search')return;
    state.search=e.target.value;
    const list=el('gallery-results');if(list)list.innerHTML=photoGallery();
  });
  el('photo-dialog').addEventListener('click',e=>{
    if(e.target===el('photo-dialog'))closeDetail();
  });
  el('photo-dialog').addEventListener('close',()=>{state.selected=null});
  el('brand-link').addEventListener('click',e=>{e.preventDefault();state.tab='galeria';state.filter='all';state.search='';closeDetailIfOpen();render();scrollTo(0,0)});
}
function closeDetailIfOpen(){if(el('photo-dialog').open)closeDetail()}
initialize();
