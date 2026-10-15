# Catálogo público WordPress → FastAPI

## Estado

- **DECISION:** usuário retomou WordPress em 2026-10-15. FastAPI continua como
  autoridade acadêmica; WordPress continua público/editorial.
- **OBSERVED:** bootstrap usa `TDS_HTTP_Courses_Adapter`; o serviço existente
  valida os registros e permite somente campos públicos antes da resposta REST.
- **TESTED:** 65 verificações da fundação e 35 do adapter passaram em PHP 8.3
  com doubles explícitos de WordPress/HTTP, sem rede. Isso não comprova runtime
  WordPress, resolução DNS real ou API implantada.
- **TARGET/UNKNOWN:** homologação com WordPress e API reais antes de habilitar
  o catálogo em produção. Fluxos privados de participante/operador, certificados
  e Chatwoot não são implementados por este adapter.

## Ativação reversível

1. Configurar `tds_public_api_base_url` nas configurações gerais, com a base
   HTTPS aprovada da API (prefixo de caminho permitido; sem query, fragmento,
   credenciais ou porta alternativa).
2. Somente depois da homologação, definir `TDS_PUBLIC_CATALOG_ENABLED` como
   booleano `true` na configuração gerenciada do WordPress (`wp-config.php`).
   A flag não é segredo; não inserir tokens ou senhas nesta configuração.
3. Confirmar `/wp-json/tds-portal/v1/public/courses`: resposta válida é HTTP 200
   e `state=ready`, inclusive quando o catálogo real está vazio. URL configurada
   isoladamente não comprova saúde; `TDS_Public_Config` não declara ready.
4. Remover a flag ou defini-la como `false` reverte para HTTP 503/unavailable,
   sem consulta upstream. Nenhuma alteração de banco acadêmico é necessária.

A única operação upstream é GET `/public/courses?offset=N&limit=N`, com
`page/per_page` convertidos para o contrato FastAPI. Não utiliza `/courses`,
login, banco direto nem credenciais administrativas. A base é configuração de
administrador, nunca entrada do visitante. `wp_http_validate_url` e
`wp_safe_remote_get` aplicam a proteção de destino do WordPress; HTTPS é
obrigatório, redirects são recusados, cookies não são encaminhados, timeout é
5s e corpo limitado a 1MiB. Não desabilitar as proteções nativas de HTTP/DNS com
filtros de terceiros. Não há retry ou cache/transient novo: payload bruto não
é persistido. Falhas, respostas truncadas e contratos inválidos não revelam
resposta upstream ou diagnósticos internos.

## Teste focal

```sh
php wordpress/staging/tests/test-wp-public-api.php
```

Inclui opt-in ausente, destinos inválidos, recusa simulada por DNS, limites do
transporte, paginação, resposta vazia legítima, JSON inválido, códigos de erro,
campos privados inesperados e rejeição de curso draft. O fake segue disponível
exclusivamente para testes determinísticos.
