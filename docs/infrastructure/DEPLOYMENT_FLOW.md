# Fluxo de Deploy

## Atual da API Tutor TDS

```text
testes locais --> cópia controlada para /opt/tutor-tds-api
  --> docker compose build --> migration Alembic --> health check
  --> smoke test externo --> backup lógico diário
```

O deploy de 2026-09-20 usa compose isolado e Traefik/Dokploy como proxy, mas
ainda não possui promoção por imagem imutável nem staging automatizado. O
rollback de código é reconstruir a revisão anterior; migrations destrutivas
continuam proibidas sem backup e autorização.

## Alvo

```text
branch
  --> testes Flutter + Worker + API
  --> imagem imutável
  --> Dokploy staging
  --> migrations não destrutivas
  --> health/smoke tests
  --> aprovação
  --> promoção da mesma imagem para produção
  --> health check e rollback automático
```

Produção não deve receber migrations destrutivas nem alteração de rede sem backup e autorização.
