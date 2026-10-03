# TDS Measurement Contract v1 — pessoa, matrícula, etapa e prova

Estado: **contrato de mensuração, não implantação de Jotform, novo baseline,
credencial, concessão de acesso ou conclusão acadêmica**. Base de auditoria:
`DOMAIN_CONTRACT.md`, `TDS_JOURNEY_TRACEABILITY_CONTRACT.md`,
`api/app/journey_export.py`, `models.py`, `student_followup.py` e cópia BI
homologada em 01/10. Produção antiga e candidato de manutenção são diferentes.

## Chaves e autoridade

- `users.id` é pessoa interna; `ClassEnrollment`/`Enrollment` guardam vínculo
  por turma/curso/programa, `CourseVersion` fixa a edição na turma.
  `LearningContext` v2 é resolvido pelo servidor; progress e `LearningEvents`
  são evidência idempotente, não matrícula, presença, elegibilidade, conclusão
  ou certificado. Outbox preserva dono, API, contexto e event_id.
- A ficha original permanece **papel → digitação → planilha oficial**; não
  reconstruir baseline no Flutter/Jotform. `BaselineSourceRecord` registra
  source+record_id humano e `StudentBaseline` apenas vínculo conferido com
  pessoa/matrícula/turma/bi_record_id, revisão e ator. Não importar respostas
  por inferência de CPF/nome/código de tablet nem converter ausência em zero.
  Baseline pendente não bloqueia estudo, mas deve estar regularizado antes do
  certificado, conforme decisão posterior da Issue #6, comentário 5965300113,
  registrada em `../program/OPERATING_DECISIONS_2026-10-03.md`, seção 2.
- `journey-export` requer equipe autorizada e flag desligada por padrão;
  `pessoa_id` é pseudônimo HMAC, `registro_id` é referência BI conferida,
  `matricula_contextual_id` e `curso_versao_id` não são intercambiáveis.
  `journey-activity` é por conta, não por turma automaticamente; consumidor
  deduplica `event_id`. Identidade/matrícula sem ficha continua em
  `TDS_PARTICIPANTES_APP`, pendente de vínculo da ficha, sem ficha fictícia.
- Cada etapa nova terá `source`, chave de fato, `occurred_at`, `recorded_at`,
  pessoa+matrícula+turma+edição quando aplicável, ator, consentimento,
  revisão/estado, motivo e idempotência. Somente um comando autorizado pode
  mudar resultado oficial; exportação e IA são leitores, não escritores de
  decisão. Revisões preservam histórico. Em flags de resultado, `null` = não
  apurado; `0` = negativo validado, nunca inferido do silêncio do app. Contagens
  técnicas podem ser zero no snapshot/janela observado, sem provar negativo
  acadêmico; percentual com denominador zero permanece null.

Legenda de competência: **AUTOMÁTICA** captura técnica; **OPERACIONAL**
registro por equipe; **DECLARATÓRIA** relato do participante;
**VALIDADA** decisão de fonte habilitada/revisor autorizado. Produzir não
implica validar. Destino `J` = `journey-export` atual; `E` = fonte existente
que pode ser ligada após contrato/testes sem criar tabela; `P` = pendência de
implementação/integração; `B` = baseline oficial externo. BI consome apenas
projeção conferida, não concede resultado.

| Etapa | Fonte/competência e fato mínimo | PRODUZ → VALIDA → CONSOME | Situação export |
| --- | --- | --- | --- |
| 01 Baseline | B, OPERACIONAL → VALIDADA: ficha física digitada na planilha; referência única humana, data/território, revisão de vínculo | campo/admin dados → administração de dados → instrutor, coordenação, BI | J `status_baseline`, `registro_id` somente com ponte confirmada; respostas permanecem B; sem ficha = pendente |
| 02 Capacitado | OPERACIONAL → VALIDADA: presença/frequência e critério oficial por matrícula/edição; estudo automático é métrica separada | instrutor/monitor e sistema → instrutor/coordenação → participante, coordenação, BI | J `horas_estudo_validadas`/`progresso_estudo_percentual` já chegam; `concluiu_frequencia_flag`/`frequencia_percentual` permanecem null; sessão/presença existente pode subsidiar comando futuro E, não prova conclusão automática |
| 03 Certificado | VALIDADA: emissão comprovada com referência autenticada por pessoa+matrícula+turma+edição e data; pedido/revisão ≠ emissão | coordenação/emissor autorizado → referência verificável + revisor → participante, coordenação, BI | J `certificado_flag` e `certificado_emitido_em` só de `CertificateReference` da API no escopo; KV/planilha legados sem vínculo são desconhecidos; emissão API→Worker pendente |
| 04 Elegível para mentoria | OPERACIONAL → VALIDADA: regra publicada + decisão de coordenação, motivo/revisão | instrutor/coordenação → coordenação → mentor, participante, BI | J `elegivel_mentoria=null`; P: comando determinístico/autorizado, não inferir de certificado/score |
| 05 Convite aceito | DECLARATÓRIA → VALIDADA: convite rastreável, resposta explícita e timestamp | coordenação/participante → coordenação → mentor, BI | J `status_convite_mentoria=null`; P: entrega, consentimento e aceite; Jotform futuro opcional, não implementado |
| 06 Mentoria | OPERACIONAL → VALIDADA: caso/mentor da equipe, abertura e sessões comprovadas | mentor/equipe → coordenação → participante, BI | `MentorshipCase` e revisões E já existem com vínculo; J `mentor_id`/`status_mentoria` permanecem null; conectar com autorização/testes, sem nova tabela nesta etapa |
| 07 Plano | DECLARATÓRIA+OPERACIONAL → VALIDADA: plano versionado, responsável, meta e aprovação | participante+mentor → mentor/coordenação → equipe de campo, BI | objetivo/next_action em `MentorshipCase` E não bastam para afirmar plano aprovado; J `plano_aplicacao_status=null`; P: contrato de plano e aprovação |
| 08 Aplicação | DECLARATÓRIA+OPERACIONAL → VALIDADA: ação datada por pessoa/turma/plano, verificação em campo | participante → monitor/instrutor → mentor, coordenação, BI | J `aplicacao_iniciada_flag=null`; P: registro e validação; eventos de leitura não comprovam aplicação |
| 09 Evidência | AUTOMÁTICA ou DECLARATÓRIA → VALIDADA: item/digest/object_reference, revisão humana e vínculo da ação | participante/monitor/sistema → revisor da equipe → mentor, coordenação, BI | `EvidenceItem`/`ReviewDecision` E guardam metadados; J `evidencia_validada_flag=null` até comando e ligação revisados; binários exigem storage privado, não notebook |
| 10 30 dias | OPERACIONAL+DECLARATÓRIA → VALIDADA: contato datado e resultado conferido, janela a partir do certificado emitido/validado | monitor/participante → equipe de campo → mentor, coordenação, BI | J `acompanhamento_30d=null`; P: instrumento e janela; eventual Jotform não substitui revisão |
| 11 60 dias | OPERACIONAL+DECLARATÓRIA → VALIDADA: mesma chave/janela de 60 dias, motivo se não localizado | monitor/participante → equipe de campo → mentor, coordenação, BI | J `acompanhamento_60d=null`; P; sem resposta não vira "não aplicou" |
| 12 90 dias | OPERACIONAL+DECLARATÓRIA → VALIDADA: 90 dias, fechamento/encaminhamento auditado | monitor/participante → coordenação → administração dados, BI | J `acompanhamento_90d`/`encaminhamentos_qtd=null`; P; não preencher por extrapolação |

## Cobertura BI, métricas e qualidade

Conciliação de 03/10: a âncora do certificado para 30/60/90 foi confirmada na
[Issue #8](https://github.com/rafaloct/tutor-tds-platform/issues/8#issuecomment-5965176322)
e substitui a referência anterior à aplicação validada. Reemissão exige regra
específica antes de automatizar esse caso. Ver decisão operacional seção 12.

Limite OBSERVED em `3fddb09`: o seletor de `CertificateReference` em
`api/app/journey_export.py` filtra pessoa/programa/curso/turma e data de matrícula,
mas não `course_version_id`. A chave completa da etapa 03 é requisito alvo;
a referência exportada não prova emissão naquela edição nem execução dos novos
requisitos institucionais. Issue #5/PR #39 mantêm a fronteira de emissão.
Formação alvo de 80h não substitui cargas históricas/configuradas. Capacitação,
frequência e elegibilidade dependem de decisão autorizada, não da soma de estudo.

`GET /classes/{id}/journey-export` hoje entrega identidade BI conferida,
turma/programa/curso/versão/matrícula, carga prevista, estudo validado,
certificado API emitido se houver, data de última interação e contagem de
eventos contextuais; `status_qualidade=confirmed_identity_partial_outcomes`.
As etapas 04–12 estão nulas; 02 frequência está nula. `journey-activity`
traz apenas taxonomia sanitizada e tempo de tela consentido com
`validated_seconds=0`; não atribuir automaticamente turma nem carga horária.
Power BI legado já lê ficha/planilha e tem 68 erros de Baseline/65 de Jornada
observados: preservar nulos/datas originais, revisão humana antes de promoção.
Cópia BI não deve sobrescrever fontes, 17 páginas existentes ou Fabric.

Indicador por etapa = número de **matrículas únicas elegíveis e validadas** no
período/edição/coorte dividido pelo denominador explicitamente definido nessa
mesma coorte, com janela temporal e fonte. Pessoas em turmas diferentes não
são fundidas por nome; não calcular conversão a partir de totais independentes
(Baseline/Certificados). Regra de 30/60/90 requer marco inicial validado e
prova de contato/resposta, com atrasos/não encontrado como estados próprios.
Mostrar cobertura da fonte, pendências de vínculo, faltantes e revisões ao
lado do percentual; dados sintéticos separados de pessoas reais.

## Ordem mínima de implementação (não iniciada aqui)

1. Conferir baseline externo/qualidade legada e vínculos por pessoa+matrícula;
   preservar planilha fonte e revisão humana.
2. Fechar frequência oficial e certificado autenticado API→Worker/KV nos gates
   próprios; não reutilizar quiz/evento como conclusão.
3. Formalizar elegibilidade/convite com ator autorizado e aceite explícito;
   reusar `MentorshipCase` em projeção sanitizada antes de criar tabelas.
4. Decidir contrato de plano/aplicação/evidência, object storage e retenção;
   ligar apenas Evidence revisada, nunca upload bruto livre no BI.
5. Instrumentar 30/60/90 e eventual Jotform com consentimento, idempotência,
   fonte, revisão e reconciliação; atualizar `journey-export`/testes/BI separado.
6. Validar offline/troca de conta, restore, privacidade, qualidade e replay em
   staging antes de qualquer promoção. Nenhum trabalho desta lista altera
   production, assinatura ou baseline físico nesta rodada.
