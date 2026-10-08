# TDS Public Portal (DR-4)

Modulo publico/editorial do Drupal. O Drupal e autoridade apenas para paginas,
noticias, agenda, materiais, FAQ e taxonomia editoriais. O catalogo continua
autoritativo na FastAPI, consumido anonimamente por `GET /public/courses` e
`GET /public/courses/{slug}`.

## Seguranca e cache

- nenhum bearer/refresh token e enviado pelo cliente;
- a origem vem exclusivamente de `TUTOR_API_BASE_URL`/settings, nunca da URL do
  visitante;
- HTTPS e obrigatorio fora de loopback local;
- redirects e corpos fora do contrato sao rejeitados;
- somente a allowlist de `PUBLIC_API_PORTAL_V1.md` chega ao Twig;
- respostas draft/private sao descartadas defensivamente;
- cache fresh = 60 s, stale degradado = mais 300 s;
- chave de cache inclui ambiente, origem, path e query;
- indisponibilidade sem stale valido exibe estado neutro, sem inventar curso.

## Editorial

O workflow `Editorial TDS` separa rascunho, revisao e publicacao. Os papeis
`tds_editor`, `tds_reviewer` e `tds_publisher` nao concedem permissao academica.
Somente nodes publicados aparecem nas rotas e no sitemap.

Tipos:

- Pagina institucional (chaves fixas programa/privacidade/direitos/
  acessibilidade/contato);
- Noticia;
- Evento;
- Material publico;
- Pergunta frequente;
- taxonomia `Topicos publicos`.

## Rotas

`/portal`, `/programa`, `/noticias`, `/agenda`, `/materiais`, `/faq`,
`/privacidade`, `/direitos-e-exclusao`, `/acessibilidade`, `/contato`,
`/cursos`, `/cursos/{slug}` e `/sitemap.xml`.

## Analytics

O JS apenas emite `CustomEvent('tds:public')` local com duas strings allowlisted:
`event` e `view`. Nao ha request de rede, URL, texto, ID ou PII. Ligar um provider
real exige Issue e revisao de privacidade separadas.

## Validacao focal

```bash
composer test-unit -- --filter tds_public_portal
bash scripts/lint.sh
bash scripts/reset.sh
bash scripts/bootstrap.sh
bash scripts/smoke.sh
git diff --check
```

Staging, DNS, provider de analytics, importacao WordPress e producao permanecem
fora deste modulo e exigem gates proprios.
