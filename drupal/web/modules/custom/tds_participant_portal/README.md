# TDS Participant Portal

Area web complementar da Issue #166. O modulo nao possui autoridade academica
e nao persiste copia de turma, progresso ou certificado no banco Drupal.

## Contratos consumidos

- `GET /auth/me`
- `GET /classes?enrolled_only=true`
- `GET /classes/{id}/learning-context`
- `GET /classes/{id}/course`
- `GET /certificates`

O gateway server-side conserva access/refresh tokens no backend da sessao. O
browser recebe apenas campos allowlisted para renderizacao. Um 401 permite uma
rotacao e um replay GET; POST nunca recebe retry automatico.

## Cache privado

O snapshot fica somente na sessao Drupal atual, isolado por usuario, ambiente e
origem FastAPI. Fresh: 60 segundos. Stale maximo: 360 segundos desde a coleta.
Troca de conta, logout ou refresh recusado dispara limpeza imediata.

## Limites

- Drupal nao calcula progresso, frequencia, capacitacao ou gamificacao.
- Turma revogada/negada e removida mesmo que tenha aparecido na listagem.
- Certificado de outro titular ou URL de verificacao insegura falha fechado.
- API offline pode mostrar somente stale privado ainda valido.
- Sem `cartilhas_app/**`, `api/**`, migration, staging ou producao.
