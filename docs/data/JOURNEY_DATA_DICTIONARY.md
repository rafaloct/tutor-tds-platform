# Jornada TDS — dicionário e medidas do overlay BI

**CONTRACT_ONLY / Issue #33.** Base auditada: `3fddb09`. Este recorte documenta
os campos atuais e testa propostas de medidas com dados exclusivamente sintéticos.
Não fecha a issue inteira nem aprova regra institucional ou implantação de BI.

## 1. Fontes, escopo e atualização

Autoridades inspecionadas:

- `api/app/journey_export.py`: `tds-journey-v1` e `tds-activity-v1`;
- `api/ops/export_tds_journey.py`: projeções CSV, deduplicação e pendências;
- `docs/production/bi/{JornadaApp,ParticipantesApp,AtividadeApp}.pq`: consumo;
- `docs/production/TDS_MEASUREMENT_CONTRACT_V1.md` e
  `TDS_JOURNEY_TRACEABILITY_CONTRACT.md`: fronteiras de mensuração;
- decisões humanas registradas na Issue #33 e no PR #24
  (`docs/program/OPERATING_DECISIONS_2026-10-03.md`), ainda draft.

Este dicionário descreve **o overlay do app**, não todas as colunas das planilhas
ou do Power BI legado. Não houve leitura de dados reais, secrets ou baseline.
Os 68/65 erros legados registrados no CURRENT_STATE continuam sujeitos a revisão.

Padrões aplicáveis a cada campo das tabelas abaixo:

- Atualização **S**: snapshot online completo, paginado, gerado pela API e
  exportado sob autorização. Não anexar snapshots como fatos novos. Mudança de
  origem detectada pelo exportador exige retry; não há snapshot transacional
  garantido só porque a contagem ficou constante. Exibir `generated_at` e janela.
- Janela **S**: estado no snapshot; não permite reconstruir situação histórica.
  Janela **E**: timestamp de ocorrência; atividade filtrada por `[since, until)`.
  Agregado **D**: dia UTC dentro da janela E; não é necessariamente um dia completo.
- Classificação **P**: dado pessoal pseudonimizado ou referência de vínculo.
  HMAC não torna a pessoa anônima; ambiente e domínio do pseudônimo precisam ser
  iguais para reconciliar. Não ler/exportar o segredo. **O**: metadado operacional,
  que também requer acesso restrito quando associado à pessoa.
- Owner **DADOS**: administração de dados/secretaria; **ENSINO**:
  instrutor/coordenação; **API**: responsável técnico pela projeção; **EMISSOR**:
  responsável autorizado por certificados. São papéis funcionais, não grants.
- Denominador por campo: **—** = chave, categoria, timestamp ou valor absoluto;
  não há percentual implícito. Denominadores de medidas estão na seção 5.
- `null`/célula vazia significa desconhecido, não apurado ou não aplicável conforme
  a linha. Não fazer `COALESCE(flag, 0)`. Zero medido não comprova resultado negativo
  oficial. Importar datas com fuso e converter para UTC antes de agregar.

## 2. Grão e reconciliação

| Fonte | Grão/chave | Uso permitido |
| --- | --- | --- |
| `TDS_PARTICIPANTES_APP` | `(pessoa_id, turma_id)` | Contas com vínculo ativo e consistente no snapshot, inclusive sem baseline. Não equivale à consolidação formal da matrícula na secretaria. |
| `TDS_JORNADA_APP` | `registro_id` único no pacote; guardar também pessoa+turma+matrícula contextual+curso+edição | Ponte BI conferida e projeção parcial de estudo/certificado. Uma linha não é um evento. |
| `journey-activity` bruto | `event_id` | Fato de conta; aparece em consultas de mais de uma turma. Deduplicar antes de agregar; replay divergente falha. |
| `TDS_ATIVIDADE_APP` | `(pessoa_id, data_utc, evento, alvo_tipo, alvo_id)` | Resumo diário substituído integralmente; não tem `event_id` para deduplicar reimportações. |

`users.id` é identidade interna; `ClassEnrollment.context_id` é matrícula
contextual; `enrollment_id` legado não a substitui; `CourseVersion.id` fixa a
edição. Nenhum desses IDs pode ser derivado de nome, CPF, telefone ou linha.

`StudentBaseline.bi_source_record_id` aponta a `BaselineSourceRecord` revisada;
`source+record_id` preserva a proveniência e reserva da ponte. No export atual,
`registro_id` vem desse `record_id`, não de uma nova ficha gerada pelo app.

Baseline pendente não bloqueia estudo nem exclui o participante e pode ser
preenchido durante ou depois do curso (Issue #6, comentário 5965300113). Baseline
registrado é requisito de `CAPACITADO` e, por consequência, de
`CERTIFICADO_VALIDO`; não é pré-requisito de `GENERATED`, que pode ocorrer
automaticamente no último checkpoint antes de baseline, frequência ou
assinaturas (contrato v2 do PR #39). Alvo (Issue #5, comentário
5965837795): baseline como evidência vinculada ao participante, com
tipo/origem/status; Forms, Jotform, app ou ficha digitalizada são aceitos, sem
exclusividade de Jotform. Este overlay não exporta tipo/origem/status nem
verifica esse gate.
Duplicata de `registro_id` impede o pacote atual, mesmo entre turmas. Não
eliminá-la arbitrariamente nem transferir a mesma ponte para outra inscrição.

Juntar jornada a participantes por **pessoa+turma**, depois verificar o vínculo
completo. Curso/edição permanecem dimensões da matrícula, não da atividade
de conta. Pessoas únicas usam `COUNT(DISTINCT pessoa_id)`; somar pessoas por
turma ou contar eventos multiplica pessoas. A relação atividade→participante
serve somente para filtrar contas visíveis: não replicar seus segundos em cada
turma. Revogação exige um novo snapshot autorizado; snapshot antigo não prova
acesso atual. Offline permite analisar um artefato revisado, sem novas decisões.

## 3. Campos atuais de jornada

Cada linha especifica tipo, origem/owner, definição/uso, unidade/denominador,
janela/atualização, null, PII e exemplo válido/inválido. Identificadores de exemplos
são fictícios; não são valores de produção.

| Campo | Tipo | Origem / owner | Definição e uso BI | Unidade / denom. | Janela / atual. | Null meaning | PII | Válido / inválido |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `registro_id` | texto | BaselineSourceRecord / DADOS | Ponte conferida para inscrição BI; join só após unicidade | ID / — | S / S | Não há ponte: vai para pending, não items | P | SYN-B01 / nome da pessoa |
| `pessoa_id` | texto | HMAC users.id / API | Pessoa pseudonimizada; distinct dentro do mesmo domínio | ID / — | S / S | Inválido no export | P | SYN-P01 / CPF |
| `turma_id` | texto | Classroom.id / ENSINO | Coorte da matrícula | ID / — | S / S | Inválido no export | P | SYN-T01 / primeira turma da pessoa |
| `programa_id` | texto | Classroom.program_id / ENSINO | Programa da turma | ID / — | S / S | Investigar origem | O | SYN-PR01 / inferido pelo título |
| `curso_id` | texto | Classroom.course_id / ENSINO | Curso estável, distinto da edição | ID / — | S / S | Investigar origem | O | SYN-C01 / versão v2 |
| `curso` | texto | título da edição ou fallback Course / ENSINO | Rótulo de exibição; não é chave | texto / — | S / S | Não substituir por chave de pessoa | O | Curso sintético / nome do aluno |
| `curso_versao_id` | texto nullable | Classroom.course_version_id / ENSINO | Edição fixada; segmentar estudo por edição | ID / — | S / S | Contexto legado sem edição; não atribuir v1/v2 | O | SYN-V01 / última edição publicada por inferência |
| `matricula_contextual_id` | texto nullable | ClassEnrollment.context_id / API | Linhagem contextual; não é Enrollment legado | ID / — | S / S | Linhagem contextual não comprovada; bloquear medida por matrícula | P | SYN-M01 / user_id |
| `status_baseline` | texto | ponte revisada / DADOS | Export atual: `Vínculo conferido`; não prova qualidade das respostas | categoria / — | S / S | Sem ponte não há linha de jornada | P | Vínculo conferido / baseline preenchido por IA |
| `vinculo_revisao` | inteiro | StudentBaseline.revision / DADOS | Revisão da conferência, não contagem de alunos | revisão / — | S / S | Não apurado | P | 2 / contagem de eventos |
| `vinculo_conferido_em` | timestamp TZ nullable | StudentBaseline.reviewed_at / DADOS | Momento da revisão, não criação da ficha | data / — | S / S | Revisão sem timestamp disponível | P | 2026-10-01T12:00:00Z / data de instalação do app |
| `carga_horaria_prevista` | número | ProgramCourse.planned_seconds ÷ 3600 / ENSINO | Carga configurada da oferta no app; não é a carga formal de 80h do curso; 0 também pode ser ausência de oferta | horas / — | S / S | Não apurado; zero não resolve configuração ausente | O | 40 configuradas no piloto / cronômetro de 80h ou de 40h digitais |
| `horas_estudo_validadas` | número | _student_progress / API | Projeção de estudo da matrícula; separada de presença | horas / — | S / S | Não apurado | P | 1.5 / segundos_tela ÷ 3600 |
| `progresso_estudo_percentual` | número | _student_progress / API | Projeção compartilhada, não posição local de leitura | % / regra da projeção de estudo | S / S | Não apurado; carga zero não habilita taxa institucional | P | 5 / frequência 70 por abrir app |
| `certificado_flag` | 1 ou null | CertificateReference / EMISSOR | Referência API legada encontrada no escopo consultado; não é GENERATED nem VALID; ausência desconhecida | flag / — | S / S | Sem referência coberta, não “não certificado” | P | 1 / 0 por não achar KV |
| `certificado_emitido_em` | timestamp TZ nullable | CertificateReference.issued_at / EMISSOR | Última referência API selecionada no escopo da turma após matrícula | data / — | S / S | Emissão não comprovada por esta fonte | P | 2026-09-01T12:00:00Z / data de solicitação |
| `certificado_cobertura` | texto | journey-export / API | `api_class_references_only`: fonte parcial; não cobre todo legado/KV | categoria / — | S / S | Cobertura desconhecida | O | api_class_references_only / cobertura universal |
| `data_ultima_interacao` | timestamp TZ nullable | eventos com linhagem explícita / API | Última ocorrência no contexto turma+edição+enrollment legado | data / — | S / S | Nenhum evento contextual localizado; não prova abandono | P | 2026-10-01T12:00:00Z / última atividade de outra turma |
| `interacoes_qtd` | inteiro | eventos contextuais / API | Quantidade acumulada consultada; não segue a janela de activity | eventos / — | S / S | Não apurado; zero observado não é falta | P | 3 / 3 presenças |
| `status_qualidade` | texto | journey-export / API | `confirmed_identity_partial_outcomes`; identidade e resultados têm coberturas distintas | categoria / — | S / S | Qualidade não classificada | O | confirmed_identity_partial_outcomes / todos gates aprovados |
| `atualizado_em` | timestamp TZ | geração da projeção / API | Momento de export, não mudança do fato acadêmico | data / — | S / S | Snapshot inválido | O | 2026-10-03T12:00:00Z / certificado_emitido_em copiado |

Limite atual de certificado: o seletor da API consultado filtra pessoa, programa,
curso, turma e `issued_at >= enrolled_at`; não filtra `course_version_id`.
Assim, a presença de v1/v2 na linha de jornada não comprova emissão naquela
edição. A referência legada também não basta para derivar `GENERATED`,
`CAPACITADO` ou `CERTIFICADO_VALIDO`. Integridade/autenticação da emissão continua na
Issue #5 / PR #39.

Estados alvo do certificado da trilha (Issue #5, comentário 5965837795; candidato
PR #39): `GENERATED`, `PENDING_INSTRUCTOR_VALIDATION`,
`PENDING_COORDINATOR_SIGNATURE`, `VALID`. A geração pode preceder as assinaturas
e não confere validade institucional. Esses estados não podem ser colapsados em
`certificado_flag`/`CertificateReference`; o overlay não os exporta.

### Campos emitidos pela API, ainda null e fora do CSV de jornada

Tipo abaixo é **alvo semântico**, não schema implementado. Todos têm janela S,
atualização S, classificação P e null = comando/integração de resultado ainda
não disponível nesta projeção. Não converter em negativo nem inferir do app.

| Campo | Tipo alvo | Autoridade / owner | Unidade / denominador | Uso e exemplo válido futuro / inválido |
| --- | --- | --- | --- | --- |
| `frequencia_percentual` | número nullable | listas/fichas institucionais / ENSINO | % / encontros configurados da oferta | BLOCKED; presença comprovada ÷ encontros configurados / eventos do app ou tempo de tela |
| `concluiu_frequencia_flag` | flag nullable | presença institucional ≥ 70% dos encontros configurados / ENSINO | flag / — | BLOCKED; ≥ 70% comprovado / exceção (`pending_human_validation`, com responsável/justificativa) tratada como frequência cumprida, presença ou CAPACITADO; o efeito acadêmico depende de resolução humana específica |
| `elegivel_mentoria` | flag nullable | decisão de elegibilidade / ENSINO | flag / — | BLOCKED; decisão com regra / certificado implica elegível |
| `status_convite_mentoria` | enum nullable | convite/resposta / ENSINO | categoria / — | BLOCKED; aceite explícito / convite enviado = aceito |
| `mentor_id` | ID nullable | atribuição MentorshipCase / ENSINO | ID / — | BLOCKED; atribuição autorizada / autor do último chat |
| `status_mentoria` | enum nullable | MentorshipCase / ENSINO | categoria / — | BLOCKED; sessão comprovada / chat resolvido |
| `plano_aplicacao_status` | enum nullable | plano revisado / ENSINO | categoria / — | BLOCKED; plano aprovado / campo next_action preenchido |
| `aplicacao_iniciada_flag` | flag nullable | aplicação comprovada / ENSINO | flag / — | BLOCKED; ação validada / leitura de cartilha |
| `evidencia_validada_flag` | flag nullable | Evidence/ReviewDecision / ENSINO | flag / — | BLOCKED; revisão humana / upload recebido |
| `acompanhamento_30d` | estado nullable | follow-up / ENSINO | categoria / — | BLOCKED; contato/resposta no marco / silêncio = false |
| `acompanhamento_60d` | estado nullable | follow-up / ENSINO | categoria / — | BLOCKED; contato/resposta no marco / extrapolar 30d |
| `acompanhamento_90d` | estado nullable | follow-up / ENSINO | categoria / — | BLOCKED; fechamento revisado / contato de suporte |
| `encaminhamentos_qtd` | inteiro nullable | encaminhamento operacional / DADOS | casos / — | BLOCKED; casos identificados / tickets = mentoria |
| `estagio_jornada` | enum nullable | projeção de fatos oficiais / DADOS | categoria / — | BLOCKED; estado derivado revisado / maior evento do app |
| `data_proxima_acao` | timestamp TZ nullable | agenda operacional / ENSINO | data / — | BLOCKED; agendamento explícito / export + 30 dias |

## 4. Participantes e atividade

Os quatro campos de participantes: `pessoa_id`, `turma_id` e `registro_id`
reutilizam os tipos/origem/PII da seção 3, com janela S e atualização S.
Aqui `registro_id=null` é permitido: vínculo BI pendente ou inconsistente, não
ausência de pessoa. Exemplo válido: `(SYN-P02, SYN-T01, null)`; inválido:
fabricar `SYN-B02` para remover a pendência.

| Campo | Tipo | Origem / owner | Definição / uso | Unidade / denom. | Janela / atual. | Null meaning | PII | Válido / inválido |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `status_vinculo` | enum | ponte/pending / DADOS | confirmed, bi_link_pending, enrollment_lineage_changed, bi_link_inconsistent; inactive_or_inconsistent é excluído do CSV | categoria / — | S / S | Inválido | P | bi_link_pending / matrícula recusada |
| `event_id` | texto | LearningEventRecord / API | Identidade bruta de fato, só API activity; dedup antes do CSV | ID / — | E / S | Inválido | P | SYN-E01 / gerar ID novo no replay |
| `evento` | enum | event_type / API | page_viewed, resource_opened, feature_used, screen_engagement | categoria / — | E,D / S | Inválido | P | page_viewed / presença |
| `alvo_tipo` | enum | taxonomia de payload / API | page_id, resource_id, feature_id | categoria / — | E,D / S | Inválido | O | page_id / pergunta livre |
| `alvo_id` | texto | identificador sanitizado / API | Taxonomia permitida; não texto de conversa | ID / — | E,D / S | Alvo inválido é omitido da API | O | home / nome do usuário |
| `ocorreu_em` | timestamp TZ | LearningEventRecord.occurred_at / API | Timestamp bruto, só API activity; determina dia UTC | data / — | E / S | Inválido | P | 2026-10-01T23:00:00-03:00 / data sem fuso |
| `segundos_tela` | inteiro nullable | active_seconds / API | Bruto screen_engagement: 1–60 por fato; CSV: soma, outros eventos contribuem 0 | segundos / — | E,D / S | Bruto em outros tipos: não aplicável | P | 30 / 30 horas oficiais |
| `escopo` | texto | journey-activity / API | conta_autenticada; atividade não atribuída à turma | categoria / — | E,D / S | Inválido | O | conta_autenticada / turma inferida |
| `atribuicao_turma` | null | journey-activity / API | Só API; ausência deliberada de atribuição acadêmica | — / — | E / S | Não atribuída | P | null / primeira turma encontrada |
| `data_utc` | data | daily_activity / API | Dia UTC do timestamp bruto | dia / — | D / S | Inválido | P | 2026-10-02 / dia local 2026-10-01 |
| `eventos_qtd` | inteiro | daily_activity / API | Fatos distintos no grupo diário após dedup | eventos / — | D / S | Inválido | P | 2 / soma de reimportações |

`pessoa_id` no activity tem janela E/D, atualização S, owner API e PII P.
`pessoa_id=null` é inválido; seu tipo/origem permanece o da seção 3.

## 5. Medidas propostas e estados BLOCKED

`tooling/data/journey_measures.sql` é referência **SQLite sintética**, sem conexão
com API, Sheets ou banco real. Usa snapshots revisados, não tabelas transacionais.
Chaves duplicadas de dimensão falham em constraints. O harness valida replay
com `daily_activity` antes da consulta; o SQL então deduplica os fatos brutos
idênticos e aplica a janela UTC. Não rodar o SQL isolado sobre uma fonte sem essa
validação: um replay divergente deve falhar, não virar dois fatos. Taxas com
denominador zero permanecem null.

A fixture contém somente o subconjunto de jornada necessário às medidas.
Sua referência por matrícula exige IDs de matrícula/edição presentes; dados
legados sem eles exigem conciliação antes do carregamento, não preenchimento.
Não é migration nem importador real dos CSVs.

| Medida / uso BI | Numerador / definição | Denominador | Janela | Owner / status |
| --- | --- | --- | --- | --- |
| `pessoas_snapshot` | pessoas distintas em participantes | — | S | DADOS / proposta testada localmente |
| `participacoes_snapshot` | pares únicos pessoa+turma | — | S | DADOS / proposta; não matrícula formal consolidada |
| `vinculos_bi_confirmados` | pares com status confirmed | — | S | DADOS / proposta; não quantidade de fichas preenchidas |
| `vinculos_bi_pendentes` | pares com bi_link_pending | — | S | DADOS / proposta; outras inconsistências separadas |
| `vinculos_bi_inconsistentes` | enrollment_lineage_changed ou bi_link_inconsistent | — | S | DADOS / proposta |
| `cobertura_vinculo_percentual` | pares confirmed × 100 | todos os pares do snapshot, mesmo sem baseline | S | DADOS / proposta |
| `horas_estudo_snapshot` | soma por matrícula contextual+edição revisada | — | S | API / proposta; nunca carga formal de 80h, frequência, trilha concluída ou capacitação |
| `referencias_certificado_api` | linhas conferidas com flag=1 | — | S | EMISSOR / observação parcial; não total institucional |
| `certificado_desconhecido` | linhas de jornada com flag null | — | S | EMISSOR / cobertura parcial explícita |
| `pessoas_com_atividade` | contas distintas com fato na janela e visíveis no snapshot | — | E | API / uso técnico |
| `eventos_conta_janela` | fatos deduplicados, sem multiplicar por turmas | — | E | API / uso técnico |
| `segundos_tela_janela` | soma de screen_engagement deduplicado | — | E | API / uso técnico, validated_seconds=0 |
| `capacitados`, `certificados_validos`, `elegiveis_mentoria`, `followup_30d_concluido` | não calculado | fontes não integradas neste overlay | — | ENSINO / BLOCKED na projeção atual |

Sem publicar conversão por divisão de totais independentes. Qualquer funil futuro
precisa de interseção das mesmas matrículas/edições, sequência de fatos validados
e cobertura conhecida. `page_view != presença`, `tempo de tela != carga oficial`,
`chat resolvido != mentoria`, `interest != eligible`, `submitted != validated`,
`certificate requested != issued`, `missing != false`.

Decisões vigentes. A decisão da Issue #5 (comentário 5965837795, candidato
PR #39) é posterior a PR #24 (`OPERATING_DECISIONS_2026-10-03.md`) e prevalece
onde divergem:

- Cada curso tem 80h formais. Não há cronômetro de 80h nem exigência de 40h
  digitais; a interpretação 40h presencial + 40h digital deixa de ser condição.
- Frequência mínima de 70% dos encontros configurados por oferta, comprovada por
  listas/fichas institucionais (substitui a referência de 75%). Exceções ficam
  `pending_human_validation`, com responsável e justificativa; exceção aceita
  não cria presença, frequência cumprida nem `CAPACITADO` automaticamente, e seu
  efeito depende de resolução humana específica. A lista assinada prevalece até correção formal.
- Trilha obrigatória por edição: checkpoints obrigatórios concluídos, com
  validação determinística no backend e configuração preservada por edição.
- `CAPACITADO` = baseline registrado AND frequência ≥ 70% AND trilha obrigatória
  concluída AND certificado da trilha gerado.
- `CERTIFICADO_VALIDO` = `CAPACITADO` AND fichas regularizadas assinadas pelo
  instrutor AND certificado assinado pela coordenação.
- Não alterar retroativamente `ProgramCourse.planned_seconds` nem o piloto
  histórico de 40h; não gerar valores sintéticos para resultados reais.
- 30/60/90 ancoram no certificado (supera o Measurement v1 antigo). O evento
  exato (geração ou validade) e a reemissão exigem definição antes de automatizar.
- Pessoa, participação e matrícula formal continuam distintas.

`BLOCKED` neste dicionário significa fonte ou comando ainda não integrado à
projeção, não ausência de decisão geral. Exceção: o evento-âncora do follow-up
(geração ou validade) e a reemissão exigem resolução específica antes de
automatizar. Faltam também fontes integradas de frequência, trilha, estados do
certificado e baseline tipado, e definição de contato/resposta para follow-up. Período sem follow-up fica desconhecido.

## 6. Lineage, privacidade e consumo

PostgreSQL autorizado → journey-export/active participants → CSV novo/revisável
→ overlay Sheets separado → Power Query → medida identificada → visual.
Baseline segue papel → digitação → planilha oficial → ponte humana revisada.
Não há caminho de retorno para “corrigir” origem por uma célula do relatório.

Sheets não recebe nomes, CPF, e-mail, telefone, resposta de baseline, texto de
conversa, prompt ou credencial. Não acrescentar PII ao overlay. Preservar escopo,
revogação, política de retenção e acesso aos pseudônimos; totais pequenos também
podem reidentificar. Os exemplos não autorizam exportar uma população real.

Cada visual deve apontar ID da medida, grão, janela, denominador e cobertura.
Atividade de conta não tem segmentação por edição só porque a pessoa participa
de duas turmas. Para medir por edição, usar fatos com vínculo explícito revisado.

## 7. Matriz do recorte e checkpoint

| Entrega | Contrato / teste | Offline | Estado / gate seguinte |
| --- | --- | --- | --- |
| Classificação dos campos do overlay atual | este dicionário; teste de cobertura dos campos CSV/API | artefato local, sem autorização nova | CONTRACT_ONLY; revisão de DADOS/ENSINO |
| Medidas sintéticas | journey_fixture.sql + journey_measures.sql; test_journey_bi_contract.py | SQLite em memória; zero rede | TESTED-LOCAL: resultado dos testes focais no PR; sem aceite BI real |
| Replay, null, duas turmas/edições, revogação | testes focais; helpers atuais daily_activity/participants | snapshot revisto, não anexado | cobre semântica do exemplo; sem migração |
| Resultado institucional e histórico | Issues #5/#6/#7/#8 e #33 | decisão humana não enfileirada aqui | BLOCKED nesta projeção; fontes/decisões próprias |

Rodar a partir de `api/`, no ambiente do lock:

```sh
uv run --locked --extra test python -m pytest \
  tests/test_journey_bi_contract.py tests/test_journey_export_tools.py -q
```

Nenhuma edição em manifests WordPress, OpenAPI público, backup, release, fontes
BI ou contratos centrais. Próximo gate: aceite semântico da conciliação com
PR #24; extensão por fontes oficiais próprias. Issue #33 permanece aberta.
