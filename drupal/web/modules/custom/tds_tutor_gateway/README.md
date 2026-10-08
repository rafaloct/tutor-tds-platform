# TDS Tutor Gateway (DR-3)

BFF mínimo de autenticação do Tutor TDS para o portal Drupal.

## Fronteira

- O browser mantém apenas o cookie de sessão Drupal e obtém o CSRF token pelo
  mecanismo padrão do Drupal.
- CPF/senha seguem por POST ao Drupal e são encaminhados uma vez à FastAPI.
- Access token e refresh token são validados e guardados no backend da própria
  sessão Drupal, isolada por cookie de navegador; nunca são serializados em
  resposta, Twig, JavaScript, URL, cache público ou log.
- A FastAPI continua sendo a autoridade de identidade e RBAC.
- A conta editorial Drupal continua separada da identidade acadêmica TDS.

## Rotas web

| Método | Rota | Proteção | Resposta |
|---|---|---|---|
| POST | /tds/session/login | CSRF | authenticated + PublicUser |
| GET | /tds/session/context | cookie Drupal | PublicUser ou erro sanitizado |
| POST | /tds/session/logout | CSRF | invalidação local imediata |

Todas as respostas usam Cache-Control: no-store, private.

## API upstream tipada

- POST /auth/login
- POST /auth/refresh
- GET /auth/me

Somente GET seguro pode repetir uma vez em falha transitória. Login e refresh
nunca têm retry automático. Um 401 em /auth/me permite uma única rotação do
refresh de uso único e um único replay de GET.

## Configuração

O settings.php já lê TUTOR_API_BASE_URL para
$settings['tutor_api_base_url']. A URL exata do ambiente é a única origem
permitida pelo cliente:

- fora de local, exige HTTPS;
- em local, HTTP é aceito apenas em loopback;
- userinfo, query e fragment são recusados;
- redirects estão desligados.

Não há segredo neste módulo. QA desta Issue usa somente MockHandler e valores
sintéticos.

## Limite observado

A FastAPI não possui /auth/logout. O logout desta fatia apaga imediatamente
tokens e contexto do Drupal, mas não revoga antecipadamente o refresh upstream.
Adicionar revogação server-side exige Issue própria no domínio da API.

## Testes

Executar no diretório drupal:

    composer test-unit -- --filter tds_tutor_gateway
    bash scripts/lint.sh
