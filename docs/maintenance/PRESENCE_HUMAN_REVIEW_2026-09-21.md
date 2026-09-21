# Presença: fechamento funcional local

Estado: implantada em staging, com fluxo autenticado e proteções de histórico
verificados no PostgreSQL. Produção não alterada; validação física pendente.

O fluxo reutiliza sessões, matrículas, autorização de equipe e o repositório de
evidências existentes. Não cria um novo sistema de permissões.

Na sessão da turma, **Conferir presença** abre a lista paginada. QR e atividade
vinculada à sessão são somente indícios. Professor/monitor autorizado registra
presença, ausência justificada ou ausência, com justificativa e conexão.
Não existe aprovação offline nem confirmação automática por IA ou atividade.

## Contrato

- GET `/classes/{class_id}/sessions/{session_id}/presence`: lista autorizada.
- POST no mesmo caminho acrescido de `/{user_id}`: decisão humana com revisão
  esperada e chave de idempotência; conflitos não sobrescrevem decisões.
- Migração `20260921_0017`: registro por sessão/aluno e histórico de decisões.
- Encerramento considera também alunos sem QR. Pendências exigem confirmação
  explícita para encerrar; isso não transforma pendência em presença.
- Relatório encerrado permanece estável; relatórios legados não são reescritos.
- Revogação de vínculo bloqueia inclusive retry; não é permitida autodecisão.

## Evidências e limites

A suíte Flutter registrou 281 testes aprovados. A análise Dart dos arquivos de
evidências e testes relacionados terminou sem problemas após ajuste de chaves.
A suíte completa de backend também passou nesta revisão local (SQLite).
Os testes de backend cobrem concorrência entre decisão e encerramento,
idempotência, revogação, histórico, exclusão privada e relatório legado.

Isso não comprova implantação: ainda falta validar a migração e o fluxo no
PostgreSQL de staging, depois a interface no Xiaomi quando estiver disponível.
A listagem usa vínculos atualmente ativos; não é um extrato histórico de todos
os ex-alunos. O relatório encerrado preserva os totais daquela sessão.
Não há nesta entrega exportação nova de decisões para Sheets nem integração
baseline/mentoria. Esses requisitos continuam abertos, assim como o release.

Próximo passo: validar esta mesma implementação no staging, sem redesenhar a
arquitetura e sem alterar produção com base apenas nos testes locais.

## Implantação em staging

- Commit: `0395fa0682d85e6005705aa290737fe31f9bbc1c`.
- Arquivo fonte SHA256: `35abe5f7d9f697df4a5a18f63291ca712c58411f624015061d100e09b2d5c29c`.
- API e worker: `sha256:8d258a50896713489f148d64c4d3dac20ce9c34b42244f1565d854202ed970c8`.
- Alembic remoto: `20260921_0017 (head)`.
- Backup: `/root/tutor-tds-backups/presence-0395fa0/before-0017.dump`.
- Backup SHA256: `732c4565e8ff740862a40f2ea930d8d52706222c1a0e3f027ef148db2ba129f5`.
- `pg_restore --list` aceitou o backup; restauração integral não foi ensaiada.
- Deploy existente validou proveniência, saúde e consulta de cursos.
- Smoke autenticado de certificados passou após implantação: pedido sintético
  existente continua rejeitado na revisão 2; nenhuma emissão foi tentada.

Não confundir essas verificações com conclusão do fluxo de presença em banco
real ou com liberação de produção. Xiaomi não utilizado nesta implantação.

## Verificação funcional posterior em PostgreSQL

`smoke_presence_staging.py` criou uma sessão exclusivamente na turma sintética:
`fd77e219-c001-462b-a10b-7581a71a1667`. Relatório:
`49e61feb-0338-4357-867a-2b43d0502190`.

Login real de aluno/professor, lista inicialmente pendente, tentativa de
encerramento pendente bloqueada, decisão humana persistida na revisão 1,
releitura, retry sem duplicação, revisão desatualizada bloqueada e encerramento
com total confirmado 1 passaram. Aluno recebeu 403 na lista e na decisão.
Segunda execução na mesma sessão fechada passou sem criar sessão/decisão nova.
Os registros sintéticos foram mantidos; não representam presença real.

`audit_presence_staging.py` conferiu diretamente uma única decisão, autoria do
professor e correspondência de estado/justificativa com o registro. Tentativas
de alterar presença encerrada, reescrever histórico e apagar histórico foram
recusadas pelos triggers PostgreSQL. Todas as sondagens foram revertidas.

Scripts copiados separadamente para operação, não incluídos na imagem 0395fa0.
Esta evidência substitui a pendência de fluxo HTTP/banco acima, mas não comprova
UI no Xiaomi, concorrência em PostgreSQL, exportação Sheets ou baseline/mentoria.
