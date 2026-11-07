# Foteka — Visual Collections

Status: **direção visual aprovada; especificação v1.1, identidade Foteka V2 · Layer / Coleções**. Os mockups são conceituais, não capturas da aplicação compilada. A implementação SwiftUI ainda utiliza a interface anterior.

## Objetivo

A interface do Foteka deve organizar a galeria por assunto com mosaicos de fotografias, sem comprometer o fluxo existente de classificação local, revisão das sugestões, regras persistentes e importação por Compartilhar/Atalhos.

## Paleta

| Token | Valor | Uso |
| --- | --- | --- |
| `background` | `#F8F7F3` | Base da tela |
| `surface` | `#FFFEFC` | Listas, formulários e cartões |
| `primary` | `#007B6E` | CTA, seleção e ícones ativos |
| `primaryDark` | `#005750` | Títulos e destaques |
| `mint` | `#E9F3F0` | Área de sugestão e feedback |
| `textPrimary` | `#18333B` | Texto principal |
| `textSecondary` | `#647678` | Metadados; contraste superior a 4,5:1 em superfície clara |
| `sand` | `#F4EBDD` | Acentos suaves |

Não usar fundo escuro/roxo como padrão: a direção selecionada é **clara, com verde-petróleo e fotografia em destaque**.

## Tipografia e espaçamento

- Tipografia **.system** (San Francisco), compatível com Dynamic Type.
- Título da tela: 28–34 pt, peso semibold/bold; seções: 20–22 pt; corpo: 15–17 pt; legenda: 12–13 pt.
- Escala: 4, 8, 12, 16, 24, 32 pt; margem lateral: 18 pt.
- Cartão: cantos de 16–20 pt; botão principal: altura mínima 52 pt; área tocável: mínimo 44×44 pt.
- Mosaico da Galeria: duas colunas adaptativas. Preserve a proporção da foto; não estique miniaturas nem ilustrações de cartas colecionáveis. Use `scaledToFill` apenas com recorte, jamais distorção.
- Priorize contraste AA, VoiceOver, labels, redimensionamento de texto e Safe Area.

## Telas

1. **Galeria** — hero fotográfico, grade 2 colunas para Fotos pessoais, Projetos, Documentos, Pokémon TCG, Compras, Capturas e acesso a Outros. A ação `Analisar novas` mantém os limites de análise já presentes no MVP.
2. **Revisão** — foto grande, categoria sugerida, opções `Confirmar categoria` e `Escolher outra categoria`; apenas imagens de baixa confiança ou aguardando revisão.
3. **Regras** — palavra-chave, categoria de destino e lista de regras/aprendizado locais; não sugerir que regras exemplificativas são dados reais.
4. **Ajustes** — toggles existentes de análise ao abrir e aplicação automática; importação de arquivos recebidos; texto claro de privacidade.
5. **Onboarding** (a implementar) — mensagem curta sobre classificação local, álbuns e aprendizado.
6. **Permissões** (a implementar como tela dedicada) — acesso completo ou limitado à Fototeca, incluindo caminho para continuar sem conceder acesso.
7. **Estado vazio** — quando não há fotos analisadas; CTA `Analisar novas fotos`.
8. **Progresso** — etapas de análise com estados reais provenientes do ViewModel; não mostrar porcentagens inventadas.

### Navegação

Manter as quatro abas já implementadas: **Galeria · Revisão · Regras · Ajustes**. Categorias visuais ficam dentro da Galeria, não como novas abas.

## Componentes SwiftUI planejados

- `OrgaColors` e `OrgaSpacing`: tokens de tema.
- `CollectionTile`: fotografia real do usuário, título e contagem somente quando conhecida.
- `CollectionGrid`: LazyVGrid com 2 colunas.
- `SuggestionCard`: imagem, categoria sugerida e decisão.
- `OrgaPrimaryButton` e `OrgaSecondaryButton`.
- `EmptyLibraryState` e `ScanProgressState`.

## Privacidade e limites da plataforma

- Manter a execução do Vision no iPhone e a preservação dos originais.
- Criar/atualizar álbuns via PhotoKit com autorização do usuário.
- Compartilhar/Atalhos podem colocar imagens em fila e importar quando o aplicativo estiver ativo. **Não prometer interceptar universalmente todos os downloads**.
- Evitar números fictícios nos protótipos. Fotos mostradas no estudo são amostras visuais, não conteúdo da galeria do usuário.

## Etapas para implementar no código

- [ ] PR 1 — tokens SwiftUI + nova Galeria em mosaico, preservando o fluxo de análise.
- [ ] PR 2 — revisão e regras redesenhadas, mantendo persistência e regras de confiança.
- [ ] PR 3 — onboarding, permissões e estados vazios/de processamento, com acessibilidade.
- [ ] Validar `swift test`, `xcodebuild`, XCTest e capturas de simulador em 375/390/430 pt.
- [ ] Auditoria visual contra os mockups e correção de divergências antes de aprovar o novo layout.

Artefatos: mockups de oito telas e prancha de tokens disponíveis na conversa original de aprovação Visual Collections.
