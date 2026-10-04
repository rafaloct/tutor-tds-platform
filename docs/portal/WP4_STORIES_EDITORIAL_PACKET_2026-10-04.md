# WP-4 — pacote editorial das histórias REALIZADO

Data: 2026-10-04  
Fonte: `WP3B_CURATED_STORIES_2026-10-04.md`  
Status: **STRUCTURED / não publicado em produção**

## Objetivo

Disponibilizar no editor WordPress duas histórias reais e verificáveis como
patterns reutilizáveis, sem criar conteúdo automaticamente no banco.

As histórias continuam usando **posts nativos**, conforme o contrato WP-4.
O slot da Home lê somente posts publicados na categoria com slug
`historias`.

## Fluxo editorial

1. criar uma única vez a categoria WordPress `Histórias`, slug `historias`;
2. criar novo post;
3. inserir um dos patterns `História TDS — ...`;
4. revisar título, excerpt e links;
5. atribuir a categoria `Histórias`;
6. manter sem imagem enquanto a reutilização não estiver confirmada;
7. passar por `draft → pending → publish`;
8. somente posts `publish` da categoria entram no slot da Home.

Nenhum post é criado por ativação do tema, request público ou deploy.

## História 1

Pattern:
`patterns/historia-escuta-territorios-palmas.php`

Estado: `REALIZADO`

Fatos preservados:
- ação em 26/05/2026;
- Centro de Ensino Médio de Taquaralto, Palmas/TO;
- 62 lideranças comunitárias no encontro;
- escuta territorial como orientação para ações posteriores;
- fonte Prefeitura de Palmas, publicação de 27/05/2026.

Imagem: **não utilizada**. Reuso continua `NÃO_CONFIRMADA`.

## História 2

Pattern:
`patterns/historia-associativismo-palmas.php`

Estado: `REALIZADO`

Fatos preservados:
- início em 23/06/2026;
- ETI Santa Bárbara, Palmas/TO;
- 61 inscritos;
- continuidade informada para 25 e 29/06;
- ligação explícita com demanda apresentada na escuta de maio;
- fontes Prefeitura de Palmas e UFT.

Imagem: **não utilizada**. Reuso continua `NÃO_CONFIRMADA`.

## Home

Arquivo:
`inc/story-provider.php`

Contrato:
- usa o filtro já existente `tds_portal_home_stories`;
- lê no máximo três posts nativos publicados;
- exige categoria `historias`;
- não cria categoria, post, meta, CPT ou taxonomia;
- não usa imagem;
- não consulta FastAPI;
- não lê dados acadêmicos;
- retorna envelope WP-3 `success|empty`;
- preserva outro provider se o filtro já tiver sido resolvido.

## Números

`62` e `61` ficam somente no corpo das respectivas histórias.

Nenhum item é adicionado a:
- `tds_portal_public_stats`;
- KPI global;
- contador de capacitados;
- total de certificados;
- impacto agregado.

## Conteúdo PLANEJADO / EM_ANDAMENTO

As duas demais histórias do WP3B não foram convertidas em patterns de resultado:

- Casa da Mulher Brasileira: `PLANEJADO`;
- novas formações com associações: `EM_ANDAMENTO`.

Elas permanecem candidatas a notícia/atualização, não ao slot de resultado
realizado.

## Rollback

Remover:
- o require de `inc/story-provider.php`;
- o provider;
- os dois patterns.

Posts já criados manualmente por editores continuam como conteúdo WordPress e
devem seguir governança editorial própria; este código não os apaga.
