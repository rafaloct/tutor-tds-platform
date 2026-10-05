# WP-5 — adapter server-side da API pública

Status: implementação inicial da Issue #45 sobre a canônica
`57533fe75772c4675a4f0cca0623a0ba8acc30c1`.

## Escopo

Esta fatia liga o WordPress somente à projeção pública FastAPI:

- `GET /public/courses`
- `GET /public/courses/{slug}`

O adapter roda no servidor WordPress. Nenhuma credencial administrativa é enviada
ao browser e nenhum acesso PostgreSQL é feito pelo portal.

## Transporte

- base URL vem de `TDS_Public_Config::validated_base_url()`;
- requisições usam `wp_safe_remote_get`;
- timeout entre 1 e 10 segundos, padrão 5;
- redirects desabilitados;
- header apenas `Accept: application/json` e User-Agent público;
- nenhum Authorization/API key.

## Cache e fallback

- fresh cache: 60 s;
- last-known-good: até 300 s;
- falha de rede/5xx pode reutilizar o último payload já validado;
- resposta 404 de detalhe é autoritativa e remove caches daquele curso;
- resposta 200 vazia/válida do catálogo substitui estado anterior;
- payload inválido falha fechado.

O fallback stale é interno ao adapter. O contrato público do portal continua
expondo somente a projeção canônica, sem inventar campo FastAPI para indicar cache.

## Allowlist

Curso público aceita apenas:

- slug
- title
- status
- published_version_label
- updated_at
- summary, quando presente
- cover_public_url, quando presente e HTTPS seguro
- public_workload_text, quando presente
- public_audience_text, quando presente

Campos como modalidade, área, FAQ, materiais, CTA, user_id, enrollment_id,
progresso, presença, baseline, sections e IDs internos não são inferidos nem
repassados.

## Compatibilidade

`/courses` permanece contrato do Flutter e não é chamado por este adapter.
WordPress não lê banco diretamente.

## Limites

Sem deploy, staging externo, DNS, secrets, autenticação acadêmica, matrícula,
frequência, certificado, Chatwoot ou analytics ativo.
