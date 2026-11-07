# Foteka Web — Visual Collections

A versão PWA do Foteka funciona no Safari e pode ser adicionada à Tela de Início do iPhone sem AltStore, sem Mac e sem Apple Developer.

**Endereço:** https://foteka-web.vercel.app

## Funcionalidades implementadas

- Importação manual de imagens pelo seletor de arquivos e Fototeca do Safari.
- Galeria Visual Collections com mosaicos, miniaturas reais, busca e coleções.
- Revisão de cada imagem com confirmação/edição da categoria.
- **IA visual opcional no próprio navegador**, com MobileCLIP S0 via Transformers.js para sugerir categorias analisando os pixels. Primeiro uso baixa um modelo; no iPhone pode consumir dezenas de MB e memória. Se o modelo falhar, classificação por regras e revisão manual continuam disponíveis.
- Regras de nome de arquivo personalizáveis como complemento e prioridade para nomes explícitos.
- Armazenamento IndexedDB **no próprio navegador** de arquivos e miniaturas.
- Download individual do original importado, exclusão de cópias, exportação dos metadados (JSON), tentativa de armazenamento persistente.
- PWA com service worker e interface utilizável offline após o primeiro carregamento, sujeito às políticas de armazenamento e cache do Safari.
- Foteka V2 Layer · Coleções; layout iPhone e desktop.

## Limitações

- Safari não fornece acesso irrestrito à Fototeca; somente fotos escolhidas manualmente.
- Web não pode criar ou organizar álbuns nativos no aplicativo Fotos do iPhone.
- A IA visual exige consentimento para baixar o modelo e pode não carregar em todos os navegadores iPhone; o resultado não é garantido e deve ser revisado. Não existe OCR nesta versão.
- A versão web não sincroniza automaticamente com o app SwiftUI. Sem backend ou login, cada navegador mantém seu próprio catálogo.
- Arquivos guardados em IndexedDB podem ser eliminados pelo sistema/navegador; mantenha os originais em Fotos ou Arquivos. Exportar índice JSON **não** exporta imagens.
- O código não faz requisições de envio das imagens. A hospedagem Vercel serve somente HTML, JS, CSS e ícones. As imagens selecionadas não são transmitidas a servidor.
- Armazenamento e execução podem variar no Safari privado e com pouca capacidade no aparelho.

## Instalação no iPhone

1. Abra **https://foteka-web.vercel.app** pelo Safari (não pelo navegador embutido de outros apps).
2. No Safari, toque em Compartilhar → **Adicionar à Tela de Início** (no iOS algumas versões mostram o item em um menu de opções).
3. Confirme **Adicionar**. Abra **Foteka** pelo ícone na Tela de Início.
4. Toque em **Adicionar fotos**, escolha imagens. Na Galeria, toque em **Classificar com IA** para analisar as fotos já importadas.
5. Autorize o download do modelo na primeira execução, preferencialmente via Wi-Fi. Depois disso, novos uploads são analisados automaticamente enquanto o navegador e o modelo estiverem disponíveis. Confirme os resultados em **Revisão**.

## Organização

Não há dependências de runtime nem coleta de dados. Os arquivos estáticos são publicados pela Vercel com o diretório raiz configurado para `web/`.

- `index.html`: marca, navegação e ícones SVG inline;
- `styles.css`: layout responsivo;
- `app.js`: importação, IndexedDB, regras e UI;
- `vision.js`: carregamento sob demanda de modelo de IA visual e classificação local;
- `manifest.webmanifest`: instalação PWA;
- `sw.js`: cache offline do shell;
- `apple-touch-icon.png`: ícone V2.
