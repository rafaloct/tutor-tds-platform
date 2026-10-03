# WP-1 — Auditoria do WordPress/Dokploy

Data: 2026-10-03. Escopo: somente leitura no ambiente instalado e cópia sanitizada fora da VPS. Produção não foi alterada.

## Resumo executivo

O portal `ead.ipexdesenvolvimento.cloud` está operacional, mas hoje combina portal público e LMS legado. A primeira versão nova deve preservar o WordPress como camada editorial e remover dele a autoridade acadêmica. O ambiente atual não deve ser usado como bancada de desenvolvimento: não há staging WordPress separado nem backup nativo identificado para o compose, há forte drift de código em relação ao Git local e o banco contém conteúdo legado alheio ao TDS.

## Ambiente observado

- WordPress 6.7.2 / PHP 8.2.28 / Apache.
- Astra 4.13.1 + `tds-child-theme` 2.0.0 ativo.
- LearnPress 4.3.6 ativo.
- MU-plugin `tds-lms-core` próprio.
- MySQL 8.0 e Redis 7.
- Dokploy compose `ead-wordpress-stack`, app `compose-program-open-source-monitor-szkpni`, sourceType `raw`.
- Traefik publica `ead.ipexdesenvolvimento.cloud` com TLS Let's Encrypt.
- Código customizado é bind-mounted de `/root/tds-wordpress`.

## Origem e drift de código

`/root/tds-wordpress` é um Git local sem remote configurado. Branch `master`, HEAD `5311fd7b65c0e6891660b234e9f47b5ff91b5635`.

O runtime contém 8 arquivos tracked modificados e 8 caminhos não rastreados. O diff tracked relevante soma aproximadamente 1.408 inserções e 304 remoções em sete arquivos de tema; portanto o HEAD histórico não representa o runtime atual.

O debrief de 04/05/2026 registra uma recuperação manual após o Dokploy recriar o container com arquivos ausentes. O script legado usa compose `raw`: envia compose/env e dispara deploy, mas não versiona/sincroniza de forma determinística os bind mounts.

## Conteúdo e contas

Foram observados 283 posts publicados: 277 possuem datas 2021–2022 e 6 são de 2026. Os posts antigos estão atribuídos ao usuário 1, cuja conta foi criada em abril de 2026. Isso prova que o conteúdo antigo não foi produzido nessa instalação nas datas registradas; é compatível com importação/contaminação histórica, mas não determina sozinho a causa. Não apagar até triagem de proveniência.

Existem 13 usuários WordPress: 9 administradores, 1 editor e 3 subscribers. WP-1 não remove nem rebaixa contas; WP-7 deve validar owners necessários e reduzir privilégio antes da promoção.

## Superfície pública

- `/wp-json/`: 200.
- `/wp-json/wp/v2/users`: 200 e expõe campos públicos de perfil, permitindo enumeração.
- namespace `/tds/v1`: público no índice REST.
- rotas do legado incluem progresso por usuário, matrícula, busca por telefone, download/verificação de certificado e cursos.
- as rotas sensíveis do TDS usam `X-API-Key`, mas o verificador de certificado é público.
- a Home não apresentou, na amostra de headers, HSTS/CSP/X-Frame-Options/X-Content-Type-Options/Referrer-Policy/Permissions-Policy.

## Integrações atuais

O child theme possui GA4 hardcoded, sem eventos customizados identificados além do `config`.

O formulário de contato sanitiza campos e envia e-mail para duas caixas, porém:
- não cria caso operacional estruturado;
- redireciona como sucesso sem verificar o retorno de `wp_mail`;
- transporta nome/e-mail/telefone/mensagem por e-mail;
- não é contrato adequado de métricas.

O `tds-lms-core` envia eventos LearnPress ao n8n (`enrolled`, `lesson_complete`, `quiz_complete`, `course_finish`) com user_id, nome, e-mail e telefone. Esse fluxo é legado operacional, não contrato futuro de analytics.

Chatwoot, n8n e serviços de RAG existem na VPS. O novo portal deve integrar suporte por adapter e nunca replicar transcrições para BI.

## Persistência e backup

Volumes declarados: `wp_uploads`, `mysql_data`, `redis_data`. A imagem WordPress também usa o volume de `/var/www/html`; Astra/LearnPress instalados via WP-CLI não são hoje um artefato Git determinístico.

Não foram encontrados registros Dokploy `backup` ou `volume_backup` associados ao compose `FqZH-VdtYO9aO4e9EPD47`. Antes de qualquer mudança de produção, banco, uploads e configuração precisam de backup e restauração demonstrável.

## Decisão arquitetural para a primeira versão

1. Manter Astra + child theme para acelerar a entrega.
2. `tds-child-theme`: apresentação, templates, estilos, patterns e markup acessível.
3. Criar em WP-2 um `tds-portal-core`: opções, CPTs editoriais, taxonomias, adapters, cache, analytics e suporte.
4. Usar Gutenberg nativo/patterns; evitar build React/custom blocks na primeira versão.
5. `tds-lms-core` passa a legado congelado. Não adicionar novas regras acadêmicas nele.
6. Staging novo inicia limpo e sem LearnPress/tds-lms-core ativos por padrão; catálogo vem da FastAPI pública.
7. WordPress nunca acessa PostgreSQL diretamente.

## Versionamento canônico

O monorepo `rafaloct/tutor-tds-platform` passa a ser a fonte canônica da evolução do portal. Esta branch inclui `wordpress/legacy-runtime/` como snapshot sanitizado do runtime atual, acompanhado de manifesto SHA-256. O snapshot não deve ser implantado automaticamente.

A cópia exclui `.env`, `.git`, `vendor` e caches; URLs tokenizadas de convites/formulários e valores de teste foram sanitizados. O arquivo original copiado para análise teve SHA-256 `0F79F21FBEC37A2E21EB3A076CEE684E13D4107818CBBDC34D3A70C4E43DBB09`.

## Gates para WP-2

WP-2 pode começar em branch própria somente após este PR ser revisado, com:
- staging definido conforme o plano adjacente;
- snapshot/versionamento canônico aceito;
- conteúdo legado antigo não importado automaticamente;
- funções acadêmicas legadas classificadas como decommission/compatibilidade;
- produção preservada.
