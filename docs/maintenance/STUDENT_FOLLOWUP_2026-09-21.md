# Acompanhamento: baseline e mentoria

Estado: API implantada em staging e fluxo HTTP autenticado validado. Tela ligada
ao painel local; integração no aparelho ainda pendente. Produção não alterada.

## Reaproveitamento confirmado

O app de formulários permanece independente e somente foi lido seu código.
Em `flutter_app/lib/main.dart:1047`, o ID combina identificação do tablet e
milissegundos. O valor é gravado como `local_record_id` junto ao `timestamp`.
Portanto ele identifica uma coleta, não a identidade durável de uma pessoa.
Não associar por nome/CPF, nem exigir que esse identificador seja UUID.

A primeira entrega liga explicitamente o aluno autenticado do Tutor ao registro
externo, com origem, data, território opcional e revisão humana justificada.
Não importa respostas, senhas, dados socioeconômicos ou interesses. A planilha
baseline e o banco do outro app não são alterados. Campos de capacitação em
texto não são convertidos automaticamente para IDs de cursos do Tutor.

## Cliente

`ClassroomRepository` existente ganhou operações online para vínculo e casos de
mentoria. Rotas preservam turma, aluno e prefixo da API. O acompanhamento fica
vinculado à conta que o abriu: troca de conta descarta a resposta e bloqueia
novas operações naquele repositório. Não há cache ou fila offline desses dados.

Testes direcionados: 7 passaram (3 novos de acompanhamento e 4 existentes de
turmas). Verificam métodos/corpos/caminhos HTTP, paginação, autenticação e troca
de conta. Não substituem testes de autorização/persistência no servidor.

## Próxima integração

API aditiva com histórico e autorização por turma; depois tela simples de
acompanhamento no contexto do estudante, com objetivo, responsável, próxima
ação e estado do caso. Reusar navegação/telemetria existentes, sem criar um
painel analítico novo. Testar vínculo, abertura, atualização e releitura antes
de promover. Nenhuma recomendação automática concede mentoria nesta entrega.

## Tela local

O painel da turma abre `StudentFollowupScreen` pela rota rastreada
`student_followup`. O operador seleciona explicitamente o aluno e pode conferir
baseline, abrir ou atualizar mentoria. Vínculo exige checkbox de conferência e
justificativa; data é validada. Decisões não entram em fila offline, erros limpam
dados editáveis e pedem releitura. O responsável inicia com o ID do operador;
a API precisa validar qualquer outro ID informado.

14 testes direcionados de tela/painel passaram, incluindo cancelamento sem
escrita, confirmação obrigatória, acesso revogado e leitura do próximo passo.
Atualização: teste positivo de escrita de baseline pela UI passou, incluindo
confirmação explícita, revisão esperada, chave de idempotência e releitura.
Histórico de vínculo e mentoria ganhou consulta online na tela (sem cache).
Atualização posterior: criação, atualização com revisão esperada e consulta de
histórico passaram no teste Flutter com HTTP simulado. Corrigido indicador de
carregamento que permanecia ativo durante a exibição do histórico.
Ainda pendentes: seletor de responsável por nome, integração real API e
verificação física.

## Backend local concluído

Migração aditiva `20260921_0018` e `student_followup.py`: vínculo explícito por
turma/aluno/matrícula, referência de origem reservada à mesma pessoa entre
turmas, casos com objetivo/responsável/próxima ação e estados
`open/in_progress/closed`. Revisões humanas justificadas, idempotência e
histórico são persistidos; exclusão privada remove dados do titular e anonimiza
responsáveis/revisores no histórico de terceiros. RBAC reutiliza vínculos de
equipe ativos; o aluno não recebe capacidade de decisão.

Regressão API local reportada pelo agente responsável: 196 testes passaram;
18 testes direcionados/migrações passaram. Flutter: 5 testes da tela passaram.
Esses resultados usam dados sintéticos/SQLite ou HTTP simulado, não são prova de
integração PostgreSQL/Flutter real. Migração 0018 ainda não implantada.

## Implantação e teste real subsequentes

Commit implantado `096c0d4af276c9dc42fdad89611eaf06a1c87b4c`, Alembic
`20260921_0018 (head)`. API/worker usam a mesma imagem:
`sha256:6fe11576906f40ca3f37b741846e4257eb387233560ae41728d9a2c6e14fc84f`.
Fonte SHA256 `93947ccf52bf31764e1d13c64c1c143295b0e6c531d829dce672b7dde494fa85`.
Backup `/root/tutor-tds-backups/followup-096c0d4/before-0018.dump`, SHA256
`2aacc4a4c514fca55b04567ae56a8bb7825d30296aa5b6b8b03cd82dafae870e`.
`pg_restore --list` aceitou o backup; não foi ensaiada restauração completa.

Smoke autenticado com contas sintéticas passou: vínculo criado/repetido/relido,
mentoria criada, atualizada para revisão 2 e histórico relido; aluno recebe 403
e revisão desatualizada recebe 409. Fonte externa não consultada.

- Baseline sintético `e0866a41-a5f8-4dd4-80cf-b6445cf9340e`, revisão 1.
- Caso sintético `707ddba4-07c8-453a-a231-92048b9f0698`, revisão 2.
- Script `smoke_followup_staging.py` copiado separadamente, fora da imagem.

Esta evidência supera a pendência HTTP/PostgreSQL acima, mas não comprova
interface em dispositivo, concorrência/guards diretos PostgreSQL ou exportação
para Sheets. Nenhuma resposta real de baseline foi importada.

## Seleção de responsável — incremento local posterior

Removida a digitação de ID técnico: a tela consulta responsáveis pelo nome em
`GET /classes/{class}/students/{user}/mentors`. A lista retorna somente ID/nome
da equipe ativa vinculada à turma, excluindo o próprio aluno. A gravação
continua revalidando autorização no servidor. Nenhuma migração adicional.
17 testes direcionados do backend e 8 testes Flutter passaram. Este incremento
ainda não está na imagem de staging 096c0d4; precisa acompanhar o próximo deploy.
