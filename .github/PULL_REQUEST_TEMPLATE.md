## Issue / objetivo único

Closes/Refs #

Explique em 1–3 frases o resultado único deste PR.

## Classificação

- Status antes: OBSERVED / UNKNOWN / BLOCKED
- Status após este PR: IMPLEMENTED / TESTED-LOCAL / TESTED-STAGING
- Área:
- Ambiente:
- Risco:
- Human Gate:
- Base SHA:
- Head SHA:

## Contrato e fonte de verdade

Qual domínio é autoridade? Quais documentos canônicos foram lidos?

## Mudanças

- 
- 

## Arquivos alterados

- 

## Banco / migrations

- [ ] Não há migration.
- [ ] Há migration aditiva.
- Upgrade base vazia:
- Upgrade snapshot/staging:
- Downgrade/forward recovery:

## Segurança e privacidade

- Secrets lidos/expostos? **Não** / justificar gate
- PII nova?
- Logs sanitizados?
- RBAC/negative tests?
- Staging e production separados?

## Offline / idempotência / troca de usuário

Quando aplicável:
- cache:
- outbox:
- replay:
- revogação:
- A→B/logout:

## Testes executados

```text
comando
resultado
```

Quantidade PASS/FAIL:

## Evidências

Links/arquivos sanitizados:

## O que NÃO foi testado

Não declarar implicitamente produção, dispositivo físico, restore, provider real ou CI se não ocorreu.

## Rollback / forward recovery

Como reverter comportamento sem apagar dado legítimo?

## Dependências e colisões

Issues/PRs/contratos que não podem ser alterados em paralelo:

## HUMAN-GATE

Se houver:
- Reason:
- Exact human action:
- What remains unblocked:
- Evidence needed to resume:

## Fora de escopo

- 

## Checklist

- [ ] li `AGENTS.md`;
- [ ] li os contratos canônicos do recorte;
- [ ] não dupliquei entidade/tabela/serviço existente;
- [ ] não incluí secret;
- [ ] rodei testes focais;
- [ ] documentei limites;
- [ ] produção não foi alterada sem autorização explícita;
- [ ] atualizei documentação/evidência necessária.
