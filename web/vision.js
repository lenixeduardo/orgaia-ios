// Visual classifier for Foteka Web.
// Downloads an open vision model on first use. Images are processed in the browser
// and NEVER uploaded to Hugging Face, Vercel, or an application backend.
// MobileCLIP model card: https://huggingface.co/Xenova/mobileclip_s0
export const VISION_VERSION='mobileclip-s0-web-v2';

const MODEL_ID='Xenova/mobileclip_s0';
const PACKAGE_URL='https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.8.1';
const PROMPTS=[
  ['pessoal','a portrait photograph of a person'],
  ['pessoal','a group of friends or family together in a personal photo'],
  ['pessoal','a landscape from a vacation or travel photograph'],
  ['pessoal','a photo of a pet or domestic animal'],
  ['pessoal','a casual smartphone photo of daily life'],
  ['projetos','a laptop screen displaying programming source code'],
  ['projetos','a product design mockup or website design project'],
  ['projetos','a workspace with a computer, notebook and tools'],
  ['documentos','a photograph of an official printed paper document'],
  ['documentos','a photograph of a printed invoice, receipt or contract'],
  ['documentos','a handwritten letter or notebook page with writing'],
  ['pokemon','a close up photograph of a Pokémon trading card'],
  ['pokemon','several collectible Pokémon trading cards arranged together'],
  ['pokemon','a trading card collection binder and booster packs'],
  ['compras','a product being sold with its packaging in a store'],
  ['compras','a photograph of clothing, sneakers or shopping items'],
  ['compras','a shopping order confirmation or ecommerce product page'],
  ['capturas','a screenshot of a smartphone mobile application user interface'],
  ['capturas','a screenshot of a chat conversation with text'],
  ['capturas','a computer screenshot of a webpage or app'],
  ['outros','an abstract graphic design illustration or digital wallpaper']
];
const LABELS=PROMPTS.map(([,label])=>label);
let classifierPromise=null;
let readImage=null;
function notify(cb,value){if(typeof cb==='function'){try{cb(value)}catch{}}}
export async function loadVisualClassifier(onProgress){
  if(!classifierPromise){
    classifierPromise=(async()=>{
      notify(onProgress,{phase:'library',detail:'Preparando a biblioteca de IA…'});
      const {pipeline,RawImage}=await import(PACKAGE_URL);
      readImage=RawImage;
      notify(onProgress,{phase:'model',detail:'Baixando o modelo visual para o iPhone…'});
      return pipeline('zero-shot-image-classification',MODEL_ID,{
        device:'wasm',dtype:'q8',
        progress_callback:event=>{
          if(event?.status==='progress' && Number.isFinite(event.progress)){
            notify(onProgress,{phase:'model',progress:Math.round(event.progress),detail:'Baixando o modelo visual…'});
          }
          if(event?.status==='done')notify(onProgress,{phase:'model',detail:'Modelo visual preparado…'});
        }
      });
    })().catch(error=>{classifierPromise=null;readImage=null;throw error});
  }
  return classifierPromise;
}
export async function classifyImageVisual(blob,onProgress){
  if(!(blob instanceof Blob))throw new TypeError('Imagem indisponível para classificação');
  const model=await loadVisualClassifier(onProgress);
  const objectUrl=URL.createObjectURL(blob);
  try{
    const image=await readImage.read(objectUrl);
    const scores=await model(image,LABELS,{hypothesis_template:'{}'});
    const ordered=(Array.isArray(scores)?scores:[scores]).filter(s=>Number.isFinite(s?.score)).sort((a,b)=>b.score-a.score);
    if(!ordered.length)throw new Error('O modelo não retornou uma classificação');
    const byCategory=new Map();
    for(const row of ordered){
      const idx=LABELS.indexOf(row.label);
      if(idx<0)continue;
      const category=PROMPTS[idx][0];
      const previous=byCategory.get(category);
      if(!previous||row.score>previous.score)byCategory.set(category,row);
    }
    const ranking=[...byCategory.entries()].sort((a,b)=>b[1].score-a[1].score);
    if(!ranking.length)throw new Error('Categorias visuais indisponíveis');
    const [[category,best],second]=ranking;
    const nextScore=second?.[1]?.score??0;
    // A CLIP score measures relative similarity, not calibrated accuracy.
    // An uncertain prediction is kept "Aguardando análise", NOT "Outros".
    const reliable=best.score>=0.17 &&
      (best.score-nextScore>=0.055 || best.score>=nextScore*1.6);
    return {category,score:best.score,label:best.label,reliable,
      reason:reliable?'Sugestão visual · revisar':'Análise incerta · escolher categoria'};
  }finally{URL.revokeObjectURL(objectUrl)}
}
export const visualModelInfo={name:'MobileCLIP S0',id:MODEL_ID,version:VISION_VERSION,labels:PROMPTS.length};
