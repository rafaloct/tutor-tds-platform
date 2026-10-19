# Staging institucional isolado — adaptador WordPress/LearnPress

Data: 19/10/2026. Executor: VPS institucional existente, sandbox Docker
`tds-learning-qa-20261017`. Classificação: **TESTED-SYNTHETIC-STAGING**.
O portal público, usuários reais e dados acadêmicos não foram alterados.

## Proveniência e isolamento

| Item | Evidência |
| --- | --- |
| fonte funcional instalada | `c853db021368f4b536521800ed9dc33ef68e3aac` |
| PR de consolidação | #296, HEAD documental `26fac3d34c112d0b4f08d9c5d234e5a857e85fe3` na auditoria |
| arquivo de instalação | `tds-learnpress-editorial-c853db0.tar` |
| SHA-256 do arquivo | `479E9C3F7A005B07A3B7D997BA83D0BADBBD1F6F77B644DA0B3F1576E68C47CA` |
| classe REST instalada | `97e6dfd30376dd506f993980d7df9935007987f8b40eadc003b2b6b1f5dc1560` |
| classe admin instalada | `eedf01c063ea3cd1718f92cc3e621b50b79705d374449d083701e1a7458be4da` |
| WordPress / LearnPress | 6.7.2 / 4.3.6 |
| rede | bridge Docker `internal=true`; nenhuma porta publicada |
| dados | 3 usuários e conteúdo exclusivamente sintéticos; zero `learnpress_user_items` |

O sandbox usa diretórios e containers dedicados. O WordPress público e o
Traefik global não foram reiniciados. A autorização humana permitiu instalar no
staging institucional isolado; não autorizou produção, merge ou publicação de
aulas. Não foi contratado nem provisionado outro VPS.

## Backup, instalação e rollback

Backup restrito:
`/opt/tds-learning-qa-20261017/backups/20261019T195000Z-pre-c853db0`.

- `database.sql`: 136.931 bytes, SHA-256
  `e9727232095a1b263ba5e2aed15f7279bebb3d8fadcd9c41ac081fd04cd34036`;
- plugin anterior: SHA-256
  `3823de4963bdbbb16860b9f87b42ac4f5f6bd645981ff95ae7ab94ff75407e9c`;
- `wp-config.php.before`: SHA-256
  `4d3fca259f3f5100936c3e7e87fc1905abb4db75d9958a9a93de7280372562f5`.

O restore drill importou 27 tabelas em banco temporário e confirmou 3 usuários,
16 posts e zero itens acadêmicos LearnPress; o banco temporário foi removido.
A instalação foi atômica, com trap de rollback, hashes de fonte e três lints PHP.
O ambiente foi marcado `WP_ENVIRONMENT_TYPE=staging`.

## Resultado

| Gate | Estado | Resultado |
| --- | --- | --- |
| instalação exata do plugin | PASS | arquivo e três fontes conferidos; nenhum rollback acionado |
| home/currículo/rota LearnPress | PASS | HTTP 200 |
| ETag condicional | PASS | HTTP 304 |
| `users/me` anônimo | PASS | HTTP 401 |
| editor de aula própria por `lp_teacher` | PASS parcial | página HTTP 200; metabox e nonce Tutor TDS presentes |
| editor por administrador | PASS parcial | página HTTP 200; POST não homologado |
| acesso indevido | PASS de autorização / FAIL de semântica | sem formulário, porém `lp_teacher` em aula alheia e subscriber retornaram HTTP 500, não 401/403 |
| POST real por instrutor | **BLOCKED** | HTTP 500 em duas tentativas, inclusive com todos os hidden fields/nonces de `form#post` |
| persistência e segundo save de rights | UNKNOWN | o POST não chegou a um resultado homologável |
| banco/container-base | PASS | dump determinístico antes/depois idêntico; container não reiniciado |
| teardown de clones | PASS | container, DB, usuário MySQL e filesystem temporários removidos |
| portal público | PASS de preservação | nenhuma mutação, restart ou publicação |

Após duas reproduções do mesmo HTTP 500, as tentativas cessaram conforme o
playbook. A hipótese é incompatibilidade de autorização ou hook no pipeline de
save do LearnPress 4.3.6; isso é inferência, não causa confirmada. O trabalho de
diagnóstico/correção foi isolado na Issue #297.

## Evidências

Instalação:
`/opt/tds-learning-qa-20261017/backups/20261019T195000Z-pre-c853db0`.

- `INSTALL_RESULT.txt`: SHA-256
  `9d56bfda96b990a5e5ad8166ce15f57d71b61e58710af267fd0d2d8e75b9e79c`;
- `curriculum-headers-after.txt`: SHA-256
  `1ffae4a463dc1a7d0b0ae8cde6752d8c43b0558165e4c1f950123dafce1ac6e2`;
- `curriculum-after.json`: SHA-256
  `774f537f5890620d4f0c3e4af079a03a73cee9b264b5f7d9690b96fe28d7bd26`.

Gate do editor:
`/opt/tds-learning-qa-20261017/backups/20261019T200620Z-http-editor-acceptance-c853db0`.

- `FAILURE_RECEIPT.txt`: SHA-256
  `c7bfc29966f193eeee5b0a74e2fd88a9995bed24073f16d8909977c662a52d57`;
- `run.log`: SHA-256
  `2a88aa115714adf055dc84fc235364b29ae6ef1c255a90a13d31f8525429bf06`;
- `clone-container.log`: SHA-256
  `43db754a91f648aa0b069abd295eb28fe9c9124a6089de97042915f0a21b660d`.

Os dumps temporários das tentativas falhas foram apagados após conferir a
igualdade do banco-base. O backup pré-instalação continua preservado. Cópias das
evidências sanitizadas foram mantidas no executor de coordenação em
`C:\AI-Shared\artifacts\tutor-tds\institutional-staging-20261019\server-evidence`.

Handoffs: Issue #276, PR #296 e Issue #297. A correção de #297 deve ocorrer em
branch/worktree própria, repetir o clone descartável e preservar a ausência de
`edit_others_lp_lessons` no papel de instrutor.

## Release e ação humana mínima

O plugin está instalado somente no staging sintético interno, mas o fluxo de
save por instrutor **não está homologado**. A ação mínima é corrigir #297 e
repetir o POST autenticado, readback, rights em dois saves, nonce inválido,
401/403 e teardown. Só depois cabe nova decisão humana de promoção. Produção,
48 aulas, usuários reais, assinatura AAB e Play permanecem fora deste aceite.

Estimativa remanescente observável: 2–4 h para diagnóstico/correção de #297,
0,5–1 h para rerun e documentação, mais a revisão humana. Custo incremental
efetivamente observado: **R$ 0,00**; foi usado o VPS já existente, sem compra ou
provisionamento de nova VM.
