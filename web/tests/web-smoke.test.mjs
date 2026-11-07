import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';
const root=new URL('../',import.meta.url);
const get=path=>readFileSync(new URL(path,root),'utf8');
test('JavaScript compila',()=>{
  assert.doesNotThrow(()=>new vm.Script(get('app.js'),{filename:'web/app.js'}));
  assert.doesNotThrow(()=>new vm.Script(get('sw.js'),{filename:'web/sw.js'}));
});
test('PWA contém arquivos e ícones',()=>{
  const manifest=JSON.parse(get('manifest.webmanifest'));
  assert.equal(manifest.short_name,'Foteka');
  assert.equal(manifest.display,'standalone');
  for(const path of ['index.html','styles.css','app.js','sw.js','icon.svg','favicon.svg','apple-touch-icon.png']){
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
