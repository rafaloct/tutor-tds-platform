# DR-3 — gateway de sessão web TDS

Status: candidato técnico da Issue #164. Sem staging, produção ou secret real.

## OBSERVED

- A FastAPI expõe POST /auth/login, POST /auth/refresh e GET /auth/me.
- TokenResponse contém access token, refresh token rotativo, expiração e
  PublicUser com id, name e role.
- O refresh é de uso único.
- Não existe /auth/logout; o contrato canônico já registra esse gap.
- O scaffold Drupal possui TUTOR_API_BASE_URL por ambiente.

## IMPLEMENTED

O módulo tds_tutor_gateway cria uma fronteira BFF:

1. login e logout web exigem CSRF Drupal;
2. a origem upstream é a URL exata do ambiente, HTTPS fora de loopback local;
3. tokens ficam no backend da sessão Drupal, isolados pelo cookie do browser;
4. somente PublicUser chega ao browser;
5. respostas são no-store, private;
6. GET seguro pode repetir uma vez; POST não é repetido automaticamente;
7. um 401 em contexto faz no máximo uma rotação e um replay de GET;
8. refresh recusado limpa a sessão; indisponibilidade transitória a preserva;
9. erros públicos são códigos constantes e não incluem corpo upstream.

## Estados cobertos por testes sintéticos

- login válido;
- login inválido e resposta sanitizada;
- token perto da expiração;
- rotação de refresh;
- logout;
- troca de usuário;
- API offline;
- resposta inválida;
- retry somente para GET;
- sessão isolada pelo store privado.

Sessões concorrentes entre browsers têm namespaces distintos no backend de
sessão Drupal. Dentro da mesma sessão, um novo login substitui o contexto
anterior antes de autenticar, evitando reassociação acidental.

## BLOCKED / fora de escopo

- revogação upstream no logout depende de nova rota/Issue FastAPI;
- staging real depende de URL e secrets autorizados;
- cadastro acadêmico Drupal é proibido;
- Drupal não concede matrícula, frequência, certificado ou papel acadêmico.

MERGE_ALLOWED=NO
PRODUCTION_ALLOWED=NO
