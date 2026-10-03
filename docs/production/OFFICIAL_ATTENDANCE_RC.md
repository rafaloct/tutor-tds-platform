# RC-B — frequência oficial e reposição (#6)

Base empilhada: `6943f849ea8f74ec74a502351b0497ca92e9ff3e` (#30, migration0023).
Pacote #37 comentário5970367703; extensão de testes/auth comentário5970509794.
Estado: IMPLEMENTED / TESTED-LOCAL, ainda sem aceite de staging/dispositivo.

## OBSERVED e decisão preservada

Já existiam SessionPresence e histórico de decisões (0017), ausência explícita,
CAS/idempotência e relatório imutável de sessão encerrada. Monitor autorizado
mantém seu endpoint legado. Telemetria/QR/atividade apenas sugerem, nunca confirmam.
Certificado v2 já exigia 70% dos encontros configurados, além dos demais critérios.

O delta acrescenta ledger append-only `official_attendance_decisions` em0024,
sem alterar fatos/relatórios originais. Cada decisão exige `original_session_id`,
pessoa, matrícula, turma/programa/curso, revisão, motivo, instrutor, data e chave
idempotente. `makeup_session_id` é opcional, deve ser diferente e da mesma turma.
O ledger aceita VALID, ABSENT, JUSTIFIED_ABSENCE e PENDING_MAKEUP; este último exige
encontro de reposição. Registrar/agendar reposição não produz VALID automaticamente.
Uma decisão explícita posterior do instrutor é necessária para qualquer efeito.

Novas decisões exigem professor designado e vínculo contextual ativo; papel admin
global não contorna revogação de ProgramMembership/CohortMembership. Autodecisão,
terceiro, monitor e coordenador não designado são recusados. A leitura mantém
escopo de equipe existente e informa `can_decide` separadamente. Erasure do titular
remove ledger; saída de ator anonimiza sua referência, preservando fatos de outros.
Triggers impedem reescrita/remoção direta; exceções só para cleanup de privacidade.

## API e projeção única

GET/POST `/classes/{class_id}/sessions/{original_session_id}/attendance/{user_id}`.
GET é histórico paginado; POST usa revisão esperada e replay exato. Mudança de
matrícula impede anexar decisão à associação histórica anterior. A sessão original
pode estar encerrada; o novo registro não reabre a sessão nem altera seu relatório.

`official_attendance_projection` compartilha o cálculo entre journey-export e
certificate_policy. Para cada ID original configurado, vale a última decisão do
ledger; sem delta, `confirmed_present` legado é adaptado a VALID. Só VALID conta,
uma vez por original. Reposição, sessão extra, indício, ausência justificada e
pendência não aumentam numerador nem denominador. Critério: `10*valid >= 7*total`.

Sem política configurada, frequência na jornada continua null. Com política
consistente e denominador conhecido, ausência de decisão é pendência com zero
presenças válidas (não inferência de falta). Configuração inconsistente falha.
CAPACITADO continua exigindo baseline, trilha obrigatória, frequência70% e geração;
VALID exige as assinaturas já definidas. Nenhum provider, emissão ou regra humana nova.

## Fluxo Flutter e contingência

Na presença existente, “Frequência oficial e reposição” mostra histórico e,
somente com capability do servidor, permite decisão com motivo e seleção do
encontro da mesma turma. Encontros e histórico são paginados. Loading/empty/error
explícitos, sem confirmação otimista; conflito exige atualizar histórico. A mesma
fronteira de owner protege todas as chamadas, inclusive lista de reposições.
Troca de alvo invalida resposta tardia tanto no histórico quanto no roster pai.

Sem conexão não há aprovação/fila automática. Contingência mantém lista assinada
em papel; instrutor registra posteriormente a correção explícita com motivo.
Não enviar dados sensíveis desnecessários na justificativa. Histórico privado
permanece na API; jornada exporta apenas resultados numéricos/pseudonimizados.

## Validação e limites

SQLite: presença/jornada legadas22PASS; certificado candidato22 casos concluídos
com recuperação do fixture de downgrade antes do runtime; frequência nova11PASS;
focal de migration operador1PASS. Esses resultados vêm de execuções focais, não de
uma suíte global. Fixtures respeitam FK e o esquema em que o runtime é executado.
PostgreSQL17.11:13PASS (ledger, concorrência/replay,70%, reposição, erasure titular,
revogação admin designado, migrações,5 regressões certificado e migration operador),
mais1PASS focal de anonimização de ator (14 casos PG únicos). Flutter16PASS no
primeiro lote, seguido de12PASS focais da invalidação de roster pai após troca
de alvo (17 casos Flutter únicos); analyze focal validado no checkpoint.
Resultados finais e SHA estão no checkpoint/revisão.

PostgreSQL portable oficial EDB já preservado fora do Git: ZIP SHA256
`6eabdf00d2893713b75db4336a23c3fdf505f056e217ec6e2e95d901750cfea3`;
postgres.exe SHA256 `4125c1e963072d929f6468a449ad184b26d3be7d97cae3181c3d613dace49c8d`.
Hash observado localmente, não atestado por manifesto assinado do fornecedor.
Cluster QA novo em127.0.0.1:15406, usuário sintético qa_attendance, bancos únicos
qa_attendance_*, removidos no finally; servidor encerrado no finally. Sem serviço
global, banco compartilhado, segredo real, SMTP/KV ou produção.

Reprodução API: `uv sync --locked --extra test`, pytest arquivos test_presence,
test_journey_traceability, test_official_attendance, test_certificate_policy_candidate.
PG: definir TDS_ATTENDANCE_PG_ADMIN_URL exclusivamente como
`postgresql://qa_attendance@127.0.0.1:15406/postgres` no servidor QA descartável e
executar `pytest tests/test_attendance_postgres.py`; fixture recusa outro alvo.
Flutter: SDK histórico3.44.9/junction exclusivo tutor-tds-attendance-qa; testes
official_attendance_test, session_presence_test, evidence_repository_test.

Rollback de0024 vazia testado. Com ledger populado, downgrade recusa perda;
preservar registros e recuperar forward. Nenhum deploy/AAB/produção autorizado.
CI, scanner completo de secrets, staging e dispositivo permanecem gates; não
declarar #6 ou RC integral aceitos a partir de mocks/testes locais.
