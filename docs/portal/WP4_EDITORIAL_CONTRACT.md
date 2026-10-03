# WP-4 — contrato editorial público

Status: implementação inicial da Issue #44. Este recorte é somente modelo
editorial e não autoriza migração de conteúdo, staging externo ou produção.

## Fonte de verdade e fronteira

WordPress pode publicar conteúdo público e editorial. Ele não é fonte de
matrícula, frequência, progresso, baseline, mentoria ou certificado.

Este recorte registra somente:

- tds_event: agenda pública;
- tds_material: biblioteca pública;
- tds_material_type: taxonomia de tipo de material;
- tds_topic: temas compartilháveis entre notícias, eventos e materiais.

Notícias continuam usando post. Histórias continuam inicialmente como
categoria editorial de posts; nenhum tds_story é criado.

## Campos públicos

Eventos:

- tds_event_start_at: RFC3339 com timezone;
- tds_event_end_at: RFC3339 com timezone;
- tds_event_location: texto público;
- tds_event_registration_url: HTTPS público validado.

Materiais:

- tds_material_public_url: HTTPS público validado.

Nenhum campo aceita ID acadêmico, storage master ID, token, mensagem de suporte
ou PII. Metadados REST são públicos para leitura, mas escrita exige permissão de
edição do post.

## Workflow editorial

A primeira versão usa estados nativos do WordPress:

1. draft: preparação;
2. pending: revisão;
3. publish: publicação;
4. private: não é conteúdo público do portal.

Não são criados roles ou status paralelos nesta fatia. O owner do portal deve
revisar os administradores legados antes de produção; esta branch não altera
contas.

## URLs, busca e filtros

Os CPTs são públicos, show_in_rest=true, possuem archive e revisions.
Taxonomias usam URLs compartilháveis em /tema/... e /tipo-de-material/....
A UI de filtros pertence ao tema/integração posterior; o modelo não cria query
privada nem acesso ao PostgreSQL.

## Segurança e legado

- não importar automaticamente os posts legados;
- não criar termos ou conteúdo de demonstração em produção;
- não expor referências privadas do Drive/R2;
- não executar analytics com texto pesquisado;
- não alterar LearnPress ou tds-lms-core;
- nenhuma chamada HTTP é feita por este modelo.

## Próximas fatias

- templates/listagens visuais depois da estabilização do child theme;
- fluxo editorial e roles revisados em staging;
- adapter da API pública em WP-5;
- suporte/certificado em WP-6;
- QA, backup e rollback em WP-7.
