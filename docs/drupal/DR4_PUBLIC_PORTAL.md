# DR-4 — portal publico/editorial e catalogo FastAPI

Status: **IMPLEMENTED local na Issue #165**. Sem deploy, staging, DNS, provider
externo de analytics ou producao.

## Autoridades preservadas

- Drupal: paginas institucionais, noticias, agenda, materiais publicos, FAQ,
  taxonomia e workflow editorial.
- FastAPI/PostgreSQL: catalogo e curso publicado, consumidos somente por
  `GET /public/courses` e `GET /public/courses/{slug}`.
- Nenhum dado academico, bearer/refresh token, CPF, progresso, presenca ou
  certificado e persistido/renderizado por este recorte.

## Implementacao

O modulo `tds_public_portal` adiciona:

- tipos `tds_institutional_page`, `tds_news`, `tds_event`,
  `tds_public_material` e `tds_faq`;
- vocabulario `tds_public_topics`;
- workflow `tds_editorial`: rascunho → revisao → publicado;
- papeis separados `tds_editor`, `tds_reviewer`, `tds_publisher`;
- rotas publicas institucionais/editoriais, catalogo e sitemap;
- adapter HTTP anonimo, read-only e allowlisted;
- cache por ambiente/origem/path/query: fresh 60 s e stale degradado por mais
  300 s;
- defesa contra draft/private, campos extras, redirect, origem insegura,
  resposta grande/invalida e indisponibilidade;
- canonical e Open Graph minimos;
- estados empty/stale/unavailable sem inventar conteudo;
- sinal de analytics local sanitizado, sem transmissao de rede.

## Acessibilidade e responsividade

- skip link e foco visivel;
- landmarks e navegacao rotulada;
- heading unico por pagina/curso;
- status anunciados com `role=status`;
- capas decorativas com `alt=""` quando a API nao fornece texto alternativo
  aprovado;
- cards fluidos com breakpoints que cobrem 360/390/768/1024/1440;
- `prefers-reduced-motion` respeitado.

## Limites deliberados

- `/public/program` e `/public/materials` continuam BLOCKED (G2); as paginas
  editoriais Drupal nao simulam esses endpoints.
- Importacao WordPress e opcional e nao foi ativada: exige conteudo aprovado e
  uma Issue propria; usuarios, LearnPress, progresso e LMS nunca sao importados.
- O evento `tds:public` nao envia dados. Vincular Google/analytics/provider real
  e decisao de privacidade + configuracao externa, logo HUMAN-GATE separado.
- Staging e producao seguem fora do escopo. O portal nao foi promovido.

## Testes focais

O unit test `PublicCatalogClientTest` cobre:

1. somente curso `published` e campos allowlisted;
2. descarte de draft/private e campo sensivel extra;
3. ausencia de Authorization;
4. stale valido quando a API fica offline;
5. stale expirado → unavailable;
6. detalhe 404 sem fallback;
7. origem HTTP nao local fail-closed;
8. isolamento de cache entre ambientes.

Aceite E2E real do milestone permanece dependente de staging Drupal isolado
(G6), tratado por frente posterior. CI verde nunca autoriza merge ou deploy.

## Rollback

Desabilitar `tds_public_portal` e restaurar `system.site:page.front`. Nenhuma
migration ou escrita foi feita no FastAPI/PostgreSQL. Conteudo editorial Drupal
pode ser preservado/exportado antes da desinstalacao.
