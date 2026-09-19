# Fluxo de Deploy

## Atual

```text
build local --> rsync/artefato --> Dokploy --> produção
```

O fluxo atual não demonstra staging, testes obrigatórios ou rollback automatizado.

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
