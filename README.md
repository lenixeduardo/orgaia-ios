# Foteka — Visual Collections (MVP iOS)

SwiftUI + PhotoKit + Vision (OCR/classificação) + Share Extension + App Intents/Atalhos.

> **Identidade:** Foteka V2 · Layer / Coleções. O repositório, os bundles e os targets mantêm os identificadores OrgaIA para compatibilidade. Para gerar o ícone do app: `python3 -m pip install cairosvg && python3 scripts/generate_brand_assets.py`. Veja [Brand/BRAND.md](Brand/BRAND.md).

> **Status:** O núcleo Swift, o build para simulador e XCTest passaram no GitHub Actions. O build para iPhone físico sem assinatura é gerado pelo workflow [Foteka — iPhone device IPA](.github/workflows/ios-device-ipa.yml); a instalação exige assinatura para o dispositivo. Consulte [guia de instalação gratuita](Docs/INSTALL_IPHONE_FREE.md).

## Foteka Web — disponível no iPhone sem Mac

**Atualização da classificação (novembro de 2026):** a versão web deixou de inferir categorias a partir de nomes como `IMG_1234.HEIC`. Fotos não analisadas ficam em **Aguardando análise** e só recebem sugestões com o modelo visual executado no navegador (após consentimento) ou por escolha manual. Fotos antigas não confirmadas são migradas para esse estado; seleções confirmadas permanecem preservadas. [Detalhes e limitações](web/README.md).

**Acesse:** https://foteka-web.vercel.app

A versão [Web / PWA](web/README.md) pode ser aberta no Safari e adicionada à Tela de Início sem AltStore nem assinatura Apple Developer. Ela tem Galeria Visual Collections V2, importação manual de imagens, armazenamento local no navegador (IndexedDB), revisão e regras por palavra-chave, e funciona parcialmente offline após a primeira visita.

**Limite importante:** a PWA não obtém acesso global à Fototeca e não cria álbuns no app Fotos. A classificação web atual é por regras, **não por IA visual**, e não sincroniza com a edição nativa. Mantenha as fotos originais no iPhone; dados do navegador podem ser apagados.

---

## Obter o projeto

Repositório: **[lenixeduardo/orgaia-ios](https://github.com/lenixeduardo/orgaia-ios)**. A visibilidade é definida pelo proprietário no GitHub.

Clone o repositório e gere o projeto Xcode com o XcodeGen:

```bash
git clone https://github.com/lenixeduardo/orgaia-ios.git
cd orgaia-ios
xcodegen generate
open OrgaIA.xcodeproj
```

A configuração do SDK Apple acontece no GitHub Actions, nos workflows **Foteka — Swift core + iOS SDK validation** e **Foteka — iPhone device IPA (unsigned)**, e não neste ambiente Linux. Builds nativos dependem da disponibilidade do executor macOS e do Xcode.

## Requisitos

- Mac com Xcode 27.2 ou versão compatível e iOS 17+ (incluindo iOS 27).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), instalável com `brew install xcodegen`.
- Apple Development Team configurado no Xcode e App Group `group.br.com.orgaia.gallery` registrado na conta. Para distribuição, um programa Apple Developer adequado.
- Um iPhone real para validar Fotos, iCloud, Compartilhar e Atalhos.

## Executar

```bash
cd OrgaIA
xcodegen generate
open OrgaIA.xcodeproj
```

No Xcode, abra os targets `OrgaIA` e `OrgaIAShare`, selecione o mesmo Team e confirme que o App Group existe em **Signing & Capabilities** de ambos. Caso `br.com.orgaia.gallery` não esteja disponível, substitua esse prefixo e os dois IDs de bundle no `project.yml` e o App Group em **todos os três** arquivos: `Shared/Config.swift`, `App/OrgaIA.entitlements`, `ShareExtension/OrgaIAShare.entitlements`. Após isso, regenere o projeto. Selecione seu iPhone e pressione Run.

## Funcionamento

```
Fotos (PhotoKit) ──> Vision (imagem + OCR) ──> RuleEngine
                                                │
                                                ▼
                                            CatalogStore
                                        categoria + confiança
                                                │
                        ┌───────────────────────┴───────────────────┐
                        ▼                                           ▼
                 Revisão manual                        Sugestões >= 80%
                        │                                           │
                        └───────────────────────┬───────────────────┘
                                                ▼
                                    PhotoKit: álbuns OrgaIA
                                   sem modificar os originais

Safari / Arquivos / Fotos ── Compartilhar ──> Share Extension ──┐
Atalhos (IntentFile) ── App Intent ─────────────────────────────┤
                                                                ▼
                                                    App Group / Inbox
                                                                ▼
                                             App em primeiro plano
                                                                ▼
                                           Importar Fotos + classificar
```

### Inicialização
1. Abrir o app e conceder acesso `Leitura e gravação` a Fotos. Acesso limitado implica um universo limitado de fotos.
2. Em **Galeria**, escolher 100, 500, 2.000 ou Tudo; tocar **Analisar novas**.
3. Em **Revisão**, corrigir a categoria de itens incertos.
4. Tocar **Criar / atualizar álbuns** para adicionar as fotos aos álbuns `OrgaIA · ...` no app Fotos.
5. Em **Ajustes**, ativar autoaplicação somente depois de validar as primeiras sugestões. A análise de novas imagens ao abrir vem ativada.

### Safari, Downloads, Arquivos
- No Safari ou Arquivos, use **Compartilhar → OrgaIA** no arquivo de imagem.
- A extensão copia o arquivo para a fila privada compartilhada (App Group), **sem** salvá-lo instantaneamente em Fotos.
- Na próxima abertura do OrgaIA, a fila é importada para Fotos; o app analisa novas imagens e permite aplicar seus álbuns.
- A fila preserva arquivos que falharem na importação para posterior tentativa. Não remova o app antes de processar a fila.

### Atalhos
1. Abra **Atalhos** → `+` e crie um atalho chamado `Classificar downloads`.
2. Adicione `Receber Arquivos e Imagens do menu Compartilhar`, ou use `Selecionar Arquivo` / `Selecionar Fotos`.
3. Adicione a ação de app **OrgaIA → Enviar imagem para OrgaIA** e vincule a variável de entrada ao parâmetro de imagem.
4. Compartilhe uma imagem pelo Atalhos, execute o fluxo e abra o OrgaIA para organizar.
5. Opcional: associe esse atalho a um botão, widget, automação suportada do Atalhos ou Siri.

**Limitação do sistema:** apps comuns iOS não podem interceptar todo download de outros apps nem alterar a pasta padrão do Safari dinamicamente com base no conteúdo. Acesso a Downloads no app Arquivos também não é uma permissão universal de monitoramento em segundo plano. O fluxo acima é acionado pelo compartilhamento/atalho do usuário; a leitura da galeria ocorre durante uso ativo. Não há promessa de processamento permanente com o app encerrado.

## Política de classificação

Categorias: `Fotos pessoais`, `Projetos`, `Documentos`, `Pokémon TCG`, `Compras`, `Capturas de tela`, `Outros`.

- OCR e rótulos da imagem alimentam um mecanismo de palavras-chave inicial.
- Sugestões incertas (confiança abaixo de 80%) entram na fila de revisão.
- Confirmação/correção incrementa pesos de palavras-chave **localmente**.
- Regras explícitas podem ser adicionadas em **Regras**; nenhuma inferência remota é feita.
- Sem confiança suficiente, vai a `Outros` e fica pendente de revisão.
- As porcentagens são heurísticas do motor, **não probabilidades calibradas** estatisticamente.

## Privacidade e dados

- Sem SDK de analytics, anúncios, serviços externos ou chamadas de rede deliberadas.
- `VNClassifyImageRequest` e `VNRecognizeTextRequest` executam no dispositivo.
- Regras e registros ficam em `UserDefaults` no container App Group. Para volume muito grande, migrar para SwiftData/SQLite.
- Nenhuma foto original é apagada. Em correções de categoria, apenas associações a álbuns `OrgaIA · ...` são ajustadas.
- Os arquivos importados preservam o arquivo-fonte quando PhotoKit aceita o formato; sempre validar suporte a WebP/GIF/HEIF no dispositivo usado.
- O iCloud pode não ter a imagem disponível localmente: a análise a ignora com aviso até um próximo scan.
- `PrivacyInfo.xcprivacy` declara acesso a `UserDefaults`; uma publicação exigirá revisar o manifesto e as respostas no App Store Connect.

## Limitações conhecidas do MVP

- **Somente imagens.** Vídeos, Live Photo em movimento, PDFs e reconhecimento semântico avançado não fazem parte da primeira versão.
- A análise é limitada pela disponibilidade da imagem no dispositivo; não faz download de originais do iCloud automaticamente.
- O modo `Tudo` pode consumir tempo, memória e bateria em bibliotecas grandes; prefira lotes menores.
- A leitura incremental considera os **N arquivos mais novos** e os registros salvos; importações antigas não são detectadas até uma busca mais abrangente.
- Associações de álbuns são mantidas no PhotoKit; apagar app/regras não remove nem reorganiza fotos existentes.
- A classificação de categorias específicas não é um modelo treinado personalizado: é Vision + OCR + regras + feedback. Substituir por modelo Core ML especializado é o passo para precisão maior.
- Para evitar duplicações em caso de encerramento inesperado entre a gravação no Fotos e a remoção da fila, o processamento deve evoluir para um registro transacional de importação.
- `Share Extension` não garante a disponibilidade de todas as variações de imagem em todos os apps de origem; testar Safari, Fotos e Arquivos.

## Checklist de QA em iPhone

- [ ] Concessão de acesso completo, limitado, e negado.
- [ ] Scan de 100 imagens e criação dos álbuns.
- [ ] OCR detecta cartão Pokémon e imagem de código.
- [ ] Captura comum vai para `Capturas`; captura do GitHub com texto vai para `Projetos`.
- [ ] Corrigir sugestão, aplicar, confirmar que álbuns criados pelo app foram atualizados sem apagar foto.
- [ ] Compartilhar JPEG e PNG pelo Safari/Arquivos e abrir OrgaIA.
- [ ] Executar Atalho com IntentFile e depois importar fila.
- [ ] Simular arquivo indisponível/iCloud, falta de espaço, permissão limitada.
- [ ] Validar rotação, modo escuro e VoiceOver.
- [ ] Inspecionar ausência de duplicações após falha simulada da importação.

## Pastas

- `Shared/`: App Group, caixa de entrada compartilhada.
- `App/`: UI, PhotoKit, Vision, motor de regras e App Intent.
- `ShareExtension/`: entrada via menu Compartilhar.
- `Tests/`: testes unitários da classificação.
- `Docs/`: arquitetura e roteiro de evolução.

## Aviso sobre execução

Nesta entrega foi validada a sintaxe Swift e o núcleo de regras em Linux; a confirmação do fluxo de permissões, build, entitlements, extensão, intenção e importação no iOS precisa ser feita em um Mac com Xcode. Compilar para iPhone não é possível neste contêiner Linux.

## Validação automatizada (GitHub Actions, SDK Apple real)

Esta versão inclui `.github/workflows/ios-validate.yml` com dois jobs:

- `core-linux`: executa os testes SwiftPM sobre os **mesmos arquivos Swift de produção** (`Validation/Core` usa links simbólicos), sem frameworks exclusivos do iOS.
- `ios-simulator`: usa runner oficial `xcode-27` com macOS/Xcode/SDK Apple; instala XcodeGen, gera o projeto, compila para iOS Simulator sem assinatura e executa os testes XCTest em um iPhone 17 virtual. Salva `.xcresult` como artifact.

**Como executar:** envie o conteúdo desta pasta `OrgaIA/` para um repositório GitHub com Actions habilitado. Na aba **Actions**, escolha **OrgaIA — Swift core + iOS SDK validation** → **Run workflow**. A execução real no GitHub ainda não foi disparada a partir deste pacote.

Para testar **sem Mac local**, essa é a abordagem recomendada. Os executores GitHub-hosted já têm o SDK Apple no macOS remoto — ele não é instalável neste Debian Linux. Um resultado verde em CI confirma build e testes simulados, mas não valida acesso à galeria de um iPhone físico, permissão de Fotos, importação real ou assinatura/distribuição.

Localmente, o núcleo portátil pode ser testado com:

```bash
swift test --package-path Validation/Core
```

Em 2026-11-06, foram executados 6 testes SwiftPM sobre os arquivos originais (`6 passed, 0 failed`) usando Swift 6.2.1 no Linux. **O build nativo iOS ainda não foi executado**.
