# Presença: fechamento funcional local

Estado: implementação local, ainda não implantada em staging ou produção.

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
