import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';
const root=new URL('../',import.meta.url);
const get=path=>readFileSync(new URL(path,root),'utf8');
test('JavaScript compila',()=>{
  assert.doesNotThrow(()=>new vm.Script(get('app.js'),{filename:'web/app.js'}));
  assert.doesNotThrow(()=>new vm.Script(get('sw.js'),{filename:'web/sw.js'}));
  // ESM model loader: parse after replacing module export declarations.
  const model=get('vision.js').replace(/export (const|async function)/g,'$1');
  assert.doesNotThrow(()=>new vm.Script(model,{filename:'web/vision.js'}));
});
test('PWA contém arquivos e ícones',()=>{
  const manifest=JSON.parse(get('manifest.webmanifest'));
  assert.equal(manifest.short_name,'Foteka');
  assert.equal(manifest.display,'standalone');
  for(const path of ['index.html','styles.css','app.js','vision.js','sw.js','icon.svg','favicon.svg','apple-touch-icon.png']){
    assert.ok(existsSync(new URL(path,root)),path);
  }
  assert.ok(get('index.html').includes('id="file-input"'));
});
test('As funções principais são locais e não enviam imagens',()=>{
  const app=get('app.js');
  for(const term of ['indexedDB.open','function importFiles','function classify','function galleryView','function reviewView','function rulesView','function settingsView','function exportIndex','function deletePhoto']){
    assert.ok(app.includes(term),term);
  }
  assert.ok(!/fetch\(|XMLHttpRequest|sendBeacon/.test(app),'nenhuma rede de upload');
});
test('Navegação mobile ocupa as quatro abas',()=>{
  const css=get('styles.css');
  assert.ok(css.includes('.bottom-items{display:grid;grid-template-columns:repeat(4,minmax(0,1fr))'));
});

test('A classificação visual não substitui revisão manual',()=>{
  const app=get('app.js'),model=get('vision.js');
  for(const term of ['startVisualAnalysis','Classificar com IA','visionVersion','manualCategory','Xenova/mobileclip_s0']){
    assert.ok((app+model).includes(term),term);
  }
  assert.ok(model.includes('classifyImageVisual'));
  assert.ok(model.includes("device:'wasm'"));
  assert.ok(!/fetch\((?:['"`]|photo)/.test(model),'no photo uploads');
});

test('Arquivos IMG_ do iPhone não caem automaticamente em Outros',()=>{
  const code=get('app.js');
  const begin=code.indexOf('function classify(filename){');
  const end=code.indexOf('function buildThumbnail',begin);
  const fn=begin>=0 && end>begin ? code.slice(begin,end) : '';
  assert.ok(fn,'função classify deve existir');
  const rules=[
    {keyword:'screenshot',category:'capturas'},
    {keyword:'pikachu',category:'pokemon'}
  ];
  const classify=vm.runInNewContext(`${fn}; classify`,{state:{rules}});
  const camera=classify('IMG_1234.HEIC');
  assert.equal(camera.category,'pessoal');
  assert.match(camera.reason,/provisória/);
  assert.equal(classify('Screenshot_2026.png').category,'capturas');
  assert.equal(classify('Pikachu_NM.png').category,'pokemon');
  assert.equal(classify('arquivo-desconhecido.png').category,'outros');
});
test('Modelo de visão tem rótulos para todas as coleções',()=>{
  const model=get('vision.js');
  for(const label of ['pessoal','projetos','documentos','pokemon','compras','capturas','outros']){
    assert.ok(model.includes(`['${label}',`),label);
  }
});
