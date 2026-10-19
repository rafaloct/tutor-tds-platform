# Gate independente adaptador/Android — STOP de integridade

## OBSERVED

Após #299 concluir com hash-base idêntico, GETs diretos ao adaptador do sandbox
retornaram currículo12 e aula13 válidos (YouTube histórico, não MP4 novo).
Não houve POST ao banco-base. Ao preparar um **novo** clone para MP4/VTT e Android,
o gate anterior à criação recusou o hash-base diferente.

Execução 2026-10-19T23:37:01Z, saída1:
`/opt/tds-learning-qa-20261017/backups/20261019T233701Z-adapter-android`.

- Esperado e comprovado no fim de #299:
  `4dc75881fb3f2df0c01a9fa65f1e99973cb231a35ee84ddd0ee34a1ccbc81a16`.
- Encontrado antes e depois do STOP:
  `1ffeecf98e7999890ab7218ee4b3fbb7d142ccdad3bc29e292e5acb1cacecfa4`.
- Nenhum clone/container/DB/usuário MySQL criado. Ausência verificada pelo cleanup.
- Nenhum POST editorial novo. Nenhuma repetição após a divergência.
- Base sem restart desde 2026-10-17T21:42:23.250450596Z.

Comparação read-only dos dumps identificou alteração somente nos INSERTs de
`tdsqa_options`: 90522→90440 bytes. Hash do bloco:
`345b8fbdc14fa641ab8b73ee782b03586b2ca4cff5d60c18ce5d97f5828f77c7` →
`80eb06b47e1637fabac27d5b082ab517ccef4b61a5279e97c0737390f647efec`.
Parser identificou 154→155 opções; nomes alterados, sem publicar valores:

- `_site_transient_timeout_wp_theme_files_patterns-b24c4b64a1fe6f9f73313f730ddfc1cf`
- `_site_transient_update_core`
- `_site_transient_update_plugins`
- `cron`
- `finished_updating_comment_type`

`DISABLE_WP_CRON` ausente do wp-config da base. Isso é compatível com manutenção
do WordPress acionada por GET, mas **não comprova causalidade exclusiva** nem
explica retroativamente a divergência antiga M1. Não normalizamos nem aceitamos
automaticamente o novo hash. Não restauramos ou alteramos a base.

## Fronteira responsável e correção estrutural proposta

Fronteira: origem sintética usada como baseline, anterior ao clone descartável.
Esperado: origem imutável, com todos os acessos HTTP limitados a clones.
Proposta, não executada: auditar origem e validar um backup-base imutável; servir
GETs/cron somente em clones descartáveis. Não excluir opções/cron do hash para
forçar PASS. Arquivos preparados: `qa-adapter/run.sh` e `test_editorial.py`.
Somente syntax/AST desses arquivos foram validados; testes HTTP não executados.

## Preservação

Código do plugin no sandbox corresponde aos três hashes Git já publicados.
Origem pública somente lida: funções/cadastro/admin-cadastro continuam com hashes
`3f896a20b7d0db98fe20eb6e211ab1785648d7ca322465fd77eb9fc99447c687`,
`67e88421dbd1a0883ef5dbb24cd906b6e3082b6d5026c46461b70030d0a8088f`,
`f34757104fb3f8b4d2d7491e8b3d144a43ba705c01d0ed42a58e4b16cce20e07`.
Container público sem restart desde 2026-10-17T06:08:58.427789614Z.
Não copiamos banco produtivo nem acessamos usuários reais.

## Gate

BLOCKED: nova homologação adaptador/Android contra clone derivado desta origem.
Reason: divergência-base exige interrupção pela regra do usuário.
Exact human action: revisar esta ocorrência e autorizar uma nova fatia de QA
com baseline sintético imutável após validar sua proveniência; não é autorização
de produção, nem pedido para repetir o bypass #297.
What remains unblocked: revisão/CI do PR301 e promoção controlada da #299 sob
gate separado; checks Android locais sem banco; nenhuma assinatura/Play.
