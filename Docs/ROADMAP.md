# Fluxos e backlog técnico

## Fluxo A — Biblioteca existente
Permissão explícita -> fetch PhotoKit -> miniatura local -> Vision/OCR -> heurística -> sugestão -> revisão humana (se incerta) -> escrita em álbum próprio -> registro local.

## Fluxo B — Nova imagem via Safari/Arquivos
Compartilhar -> Share Extension valida UTType e limita 100 MB -> cópia temporária no App Group -> app abre -> PhotoKit importa com metadados do arquivo -> scan da biblioteca -> revisão/aplicação.

## Fluxo C — Atalhos
Ação `Enviar imagem para OrgaIA` recebe `IntentFile` -> fila local -> mesmo fluxo B. Não há interceptação universal de downloads do sistema.

## Fluxo D — Aprendizado
Usuário escolhe categoria -> atualizar resultado manual -> adicionar pesos locais para palavras reconhecidas -> scans seguintes consultam os pesos. Não é atualização de pesos do Vision nem treinamento neural.

## Versão 0.2 — Confiabilidade
- Identidade idempotente de importações por hash SHA-256 e journal transacional para evitar duplicatas.
- Histórico de classificação e trilha de auditoria por imagem.
- Varredura incremental paginada e observador PhotoKit em app ativo.
- Download sob demanda do iCloud com controle explícito.
- SwiftData/SQLite + migração.
- Identificação de GIF/WebP + conversão opcional de cópias para formatos PhotoKit aceitos.
- Melhor revisão em lote e desvinculação/reversão de álbuns criados pelo app.

## Versão 0.3 — IA avançada
- Embeddings locais com Core ML/embedding multimodal para pesquisa semântica e categorias do usuário.
- Detecção de fotos duplicadas, mantendo metadados sem exclusão automática.
- Categorização de recibos/contratos/documentos via OCR + regras estruturadas.
- OCR especializado TCG com catálogo local de referência e correção manual.
- Pipeline para vídeos e Live Photos, mediante consentimento separado.

## Segurança e auditoria
- A fila fica isolada no App Group; a extensão apenas enfileira e não exige acesso amplo ao Fotos.
- Limiar configurável, modo padrão requer confirmação de aplicação aos álbuns.
- Nunca remover imagens do rolo da câmera.
- Tratar dados OCR como conteúdo não confiável; nunca executar comandos extraídos de imagens.
