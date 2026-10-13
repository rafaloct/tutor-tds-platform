# Promoção da API executada — 13/10/2026 (#197)

## OBSERVED

A API produtiva foi promovida na VPS entre 15:34:49 e 15:37:20 UTC, após
o plano somente leitura aceitar os recibos reais de recuperação e a
preservação de configuração. Migração transacional PostgreSQL:
`20261005_0028 → 20261006_0029 → 20261007_0030`.

Apenas o serviço `api` foi recriado. Os IDs dos containers `db` e `policy-web`,
o compose, redes, mounts e valores JWT/CPF/DATABASE_URL foram preservados.
O catálogo legado de nove cursos manteve a mesma projeção e SHA-256
`212c860f04d95d87e48f39d7cd0326a6b12a2cc0cd581a1f957459c632389e42`.
Nenhum seed, downgrade, exclusão de dados, troca de assinatura ou upload Play.

| Identidade | Valor observado |
| --- | --- |
| Imagem candidata ativa | `sha256:4ed8a189b3741d8b8f536a0b790cc0215f997f05c4254ea65d9e67826b1a858b` |
| Fonte declarada, construída nesta operação | `d3b1331a14ec77b37a8b05e9f5f19e2ccfe57c2e` |
| Árvore API | `dc32d081dffd4d778e51871a85ae4077eb75f6ce` |
| Schema ativo | `20261007_0030` |
| Versão mínima de app | `1.2.0+11` |
| Sinal de compatibilidade | `true`, após validação interna |
| Imagem anterior retida para rollback | `sha256:d6701c77b8a48b84fa4b9cea7bbc1c2858bf69aa75dd2367c9a3a4f6fb30666c` |

Contexto, atividade dinâmica, jornada, lifecycle, ativação CPF, candidato de
certificado, operações e simulação comercial seguem false, explicitamente ou
pelo default false inspecionado na fonte. Pagamentos seguem `disabled`.
Este sinal de compatibilidade cobre os apps suportados com essas flags;
`API_COMPATIBILITY_REVIEW_2026-10-13.md` delimita o prepare HTTP antigo não
coberto. Não é declaração de compatibilidade de todo consumidor externo.

## Probes e recibos

- `evidence/api-production-promotion-20261013.json`: saída original sanitizada
  do executor, SHA-256
  `72b39925de1de1c7dc4a5c54fd6d98b3ab463ae09d5c65b75424946805d28923`.
  Registra o aceite interno, duas fases false→true, preservação e migrações.
- `evidence/api-production-https-20261013.json`: consulta externa pelo LARGeo
  às 15:39:42 UTC, SHA-256
  `091093c47929fc1a7153f02099e2017c012ff7f804006e1892023bd884aa0e16`.
  `/health`, `/live`, `/version` e `/courses` passaram com TLS padrão, schema0030,
  production, mínimo11, compatibilidade true e nove cursos.

Uma inspeção posterior confirmou ausência da identidade age temporária e de
containers de migração. O ensaio suplementar isolado das 15:56 passou:
73 arquivos de fonte da imagem conferidos contra Git; 447 colunas,
270 constraints, 109 índices, 16 triggers e 15 funções originais preservados.
Somente as adições previstas nas migrations ocorreram. Recibo e limites em
`RECOVERY_EXECUTION_2026-10-13.md`; labels OCI e fingerprints de valores,
sozinhos, não serviram como prova dessas propriedades.

## Operação e rollback

Execução pública revisada: `promote_production_api_20261013.py`, SHA-256
`47de0ce2e2c5b256b3772e6c8b34c8f8638f2fb5bab6e03a9ae8d4433c193af2`;
instalação root-owned em `/opt/tds-release-ops-20261013/release-review`.
O verificador de evidência permaneceu inalterado, SHA-256
`7bd410c8bc3e1124b6f1f801f3d49bff15f3989d674edf6d75a8201865558a45`.

Cópias privadas anteriores de `.env` e compose foram retidas no host, em
`/opt/tutor-tds-api/.promotion-20261013T153449Z-6f9d7cc64f07`, modo restrito.
O script aborta se configuração/identidades mudarem e comprova ausência da
migração interrompida antes do rollback. A imagem antiga deve iniciar com
uvicorn diretamente e conservar DB0030; não usar seu bootstrap Alembic antigo.
Não aplicar downgrade automático. O rollback não foi necessário nesta promoção.

Tag, freeze da release, AAB/manifesto, verificação do bundle e autorização de
upload continuam separados desta promoção da API. Google Analytics do domínio
e Cloudflare seguem a opção informada pelo operador; não houve implantação
Firebase ou verificação independente de métricas nesta operação.
