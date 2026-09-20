# Assessment Sync — gates reais de staging

Data: 20/09/2026

Ambiente: `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`

Script reproduzível: `api/ops/staging_assessment_smoke.py`

## Escopo e segurança

O smoke aceita somente URL contendo `staging`, usa exclusivamente as contas e
o curso sintéticos do seed e recebe credenciais por variáveis de ambiente. CPF,
senha e tokens não são impressos. A execução de 20/09 usou identificadores
descartáveis terminados em `20260920r1`.

## Resultado observado

- conteúdo versionado criado com HTTP 201 e retry idempotente HTTP 200;
- tentativa de alterar o mesmo conteúdo recebeu HTTP 409
  `assessment_content_immutable`;
- tentativa criada na revisão 1 e retry idêntico recebeu HTTP 200;
- dois clientes partiram da mesma revisão 1: o cliente A gravou a revisão 2 e
  o cliente B recebeu HTTP 409 `revision_conflict`;
- retry idêntico do vencedor permaneceu HTTP 200;
- outra conta recebeu HTTP 404 ao tentar ler conteúdo e tentativa;
- revisão 3 concluída recebeu pontuação 1 calculada pelo servidor;
- gabarito permaneceu oculto antes da conclusão e foi liberado somente pela
  rota vinculada à tentativa concluída;
- edição da revisão 4 recebeu HTTP 409 `completed_attempt`.

Resultado final do script:

```text
Staging assessment smoke passed: immutable content, idempotency, concurrent CAS conflict, cross-account isolation, server score, answer-key release and completed-attempt immutability.
```

## Limpeza

Após o smoke, uma transação controlada no PostgreSQL de staging removeu
exatamente a tentativa e o conteúdo descartáveis (`DELETE 1` + `DELETE 1`). O
arquivo SQL, a cópia no container e o script temporário do host foram removidos.
Produção não foi acessada nem alterada.

## Limite

Esta prova fecha os contratos remotos de conflito CAS, idempotência,
isolamento, conclusão e pontuação no staging. Ela não substitui uma demonstração
visual simultânea com dois aparelhos nem os testes de acessibilidade da tela.
