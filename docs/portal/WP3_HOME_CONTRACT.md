# WP-3 — contrato da Home pública

Status: implementação em branch `windsurf/issue-43-home-20261003`. Este recorte
depende do child theme WP-2 e não autoriza staging, deploy ou produção.

## Fronteira

A Issue #43 pede 14 blocos da especificação UX, mas os documentos canônicos
versionados não enumeram uma lista fechada de 14 nomes. Para não inventar uma
especificação ausente, esta implementação mapeia 14 **slots funcionais** a partir
das famílias explicitamente citadas na Issue #43 e do mapa público em
`PORTAL_AND_CONTENT.md`.

| Ordem | Slot | Fonte atual | Comportamento sem fonte |
| ---: | --- | --- | --- |
| 1 | hero | página/Home WordPress | texto institucional configurado no site |
| 2 | jornada | contrato de separação portal/plataforma | conteúdo explicativo estático |
| 3 | áreas | filtro editorial futuro | unavailable |
| 4 | cursos | `tds-portal-core` / catálogo público | unavailable/empty/error |
| 5 | ferramentas | filtro editorial futuro | unavailable |
| 6 | resultados/stats | `TDS_Theme_Portal_Stats_Provider` | **slot oculto** |
| 7 | histórias | filtro editorial futuro | unavailable |
| 8 | notícias | posts WordPress publicados | empty |
| 9 | agenda | filtro editorial futuro | unavailable |
| 10 | biblioteca | filtro editorial futuro | unavailable |
| 11 | parceiros | filtro editorial futuro | unavailable |
| 12 | acesso ao app | `TDS_Public_Config` | unavailable |
| 13 | certificado | verificador oficial futuro | unavailable |
| 14 | suporte | configuração/adaptador futuro | unavailable |

O slot 6 é condicional por requisito da própria Issue #43: número sem
proveniência não aparece. Assim, uma Home sem estatística comprovada possui 13
seções visíveis e nenhum placeholder numérico.

## Conteúdo editorial futuro

WP-3 **não registra CPT, taxonomia ou metadado**. WP-4 (#44) continua dono de
notícias/agenda/biblioteca/histórias e de sua governança editorial. Para permitir
composição sem acoplamento antecipado, o tema expõe filtros fail-closed:

- `tds_portal_home_areas`
- `tds_portal_home_tools`
- `tds_portal_home_stories`
- `tds_portal_home_events`
- `tds_portal_home_materials`
- `tds_portal_home_partners`

Sem provider, nenhum conteúdo fictício é criado.

Os providers de coleção podem devolver a forma explícita:

```text
{ state: loading|success|empty|stale|unavailable, items: [...] }
```

Para compatibilidade durante o WP-3, uma lista simples ainda é aceita e equivale
a `success`; lista vazia sem envelope equivale a `unavailable`. O estado
`stale` pode renderizar a última lista válida junto ao aviso de desatualização.

## Estados

Estados remotos de apresentação suportados:

- `loading`
- `success`
- `empty`
- `stale`
- `unavailable`

`error` e `disabled` permanecem compatíveis com a fundação WP-2.

Itens de ferramenta aceitam apenas:

- `available`
- `coming_soon`
- `restricted`
- `hidden`

`hidden` não gera HTML.

## Estatísticas públicas

`TDS_Theme_Portal_Stats_Provider` recebe somente dados fornecidos pelo filtro
`tds_portal_public_stats`. Cada item precisa ter `label`, `value` e
`source_label`. URL de fonte, quando fornecida, precisa ser HTTPS. Itens
incompletos ou com URL insegura são descartados. Não há valor default.

Essa validação de forma não transforma qualquer fonte em autoridade. O
publicador continua responsável por aprovar conteúdo e proveniência.

## Analytics

O tema **não carrega GA4 nem envia requisição de analytics**. Ele só marca
interações elegíveis com atributos `data-tds-event` de uma allowlist fechada:

- `portal_home_view`
- `course_card_click`
- `app_access_click`
- `tool_card_click`
- `news_click`
- `event_click`
- `material_click`
- `support_cta_click`
- `certificate_verify_cta_click`

Somente slug público opcional pode acompanhar o evento. Nome, e-mail, telefone,
texto livre, IDs acadêmicos, progresso, presença, baseline e código/hash de
certificado não entram nesses atributos.

## Branding

A identidade segue os assets já versionados no WP-2, provenientes do kit oficial
indicado na Issue #42. A pasta Drive confirmada contém, entre outros,
`logo-tds-fundo-branco.png`, `logo-tds-fundo-transparente.png`,
`logo-tds-monocromatico.png` e `marca-isolada-tds.png`. WP-3 não recria nem
reinterpretará a marca.

## Fora de escopo

- CPTs/taxonomias WP-4;
- provider HTTP real do catálogo WP-5;
- Chatwoot e verificador de certificado WP-6;
- analytics ativo;
- dados ou métricas institucionais não aprovados;
- login, matrícula, frequência, progresso ou emissão de certificado;
- staging/DNS/Dokploy/produção.
