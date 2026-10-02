# Identidade e jornada TDS — recorte de 01/10/2026

Estado: gates locais, PostgreSQL e Android do recorte concluídos; BI pendente de
refresh/render real; flags false por padrão. Não é aceite de
produção. Pedido atual prioriza este recorte, sem executar migrações em paralelo
com Dynamic Learning. Preservar produção, assinatura, KV e baseline externo.

## Evidência inspecionada

Fabric: workspace 61e806f8-8096-42c1-a00e-2ab5820359e1, relatório
5c922beb-971d-4ef6-b004-293d61456c00, modelo d920b1e1-22ea-4568-959c-3070188e3484.
TMDL lido em Viewing: oito tabelas, seis relações; Jornada e Baseline 1:1
bidirecional por registro_id. Baseline importa MART_TDS_LOOKER e respostas de
LOOKER_BASE_DINAMICA; Jornada importa TDS_FICHA_ALUNO. pessoa_id é tipado, mas
removido da seleção final de Baseline. A consulta de respostas usa DIG-/ESC- e
Linha na origem. Não presumir equivalência com local_record_id do tablet.
Capacitados conta concluiu_frequencia_flag=1; Certificados certificado_flag=1.
Conversões atuais dividem totais, sem interseção de inscrições ou ordem temporal.

## Contrato mínimo

- Reusar users.id, class_enrollments, student_baselines, baseline_source_records
  e baseline_revisions. Não criar cadastro paralelo de pessoas.
- Referência original de coleta permanece source+record_id. Acrescentar ponte
  explícita bi_record_id para a inscrição do modelo inspecionado, conferida pela
  equipe. Reusar BaselineSourceRecord para reservar a ponte por pessoa; referência
  antiga permanece reservada mesmo após correção. Ponte corrente exclusiva por
  inscrição; jamais inferir por nome/CPF/telefone/posição da linha.
- Ponte ligada à turma e matrícula existentes. Não cria inscrição nem acesso.
  Mudanças exigem motivo, revisão esperada, idempotência e autorização atual.
- JOURNEY_TRACEABILITY_ENABLED=false na API e Flutter. Escrita da ponte/export
  indisponíveis até configuração e validação em staging isolado.
- Exportação somente equipe da turma autorizada; pessoa_id reutiliza HMAC de
  users.id com SHEETS_PSEUDONYM_SECRET. Sem nome, CPF, telefone, respostas,
  narrativas de mentoria, tokens ou secrets. Sem troca/rotação do segredo atual.
- Uma ficha por ponte confirmada. Linhagem inconsistente é pendência explícita,
  nunca resultado zero nem duplicação silenciosa. Sem ponte: pendente, não exporta.
  Esse limite é da ficha de baseline, não da identidade no programa: contas com
  matrícula ativa e consistente aparecem em TDS_PARTICIPANTES_APP mesmo sem ficha.
  Sua atividade consentida pode ser acompanhada por pessoa, sem atribuir turma
  automaticamente e sem inventar registro_id. Desduplicar event_id entre turmas.
- Frequência presencial, elegibilidade, aceite, planos e 30/60/90 sem comando
  canônico correspondente permanecem null/desconhecidos. Progresso de estudo não
  vira concluiu_frequencia_flag. Certificado exige referência emitida no escopo,
  não solicitação aprovada. API nunca concede certificado pela exportação.
- Eventos de tempo de tela são telemetria opcional, com consentimento, dono/API,
  foreground e limite de inatividade; validated_seconds=0. Não viram carga horária.
  A autorização antiga não ativa o escopo novo: aviso e escolha específicos.
- Respostas tardias de login/refresh/requests não restauram sessão nem mudam dono.

## Offline e integração BI

Vínculo é online; nenhuma fila de decisão humana. Telemetria usa fila por dono,
idempotência e API; legado sem dono não é atribuído ao próximo usuário.
Export é snapshot online, paginado, sem cache no app. Primeira saída é artefato
local/revisável e destino separado TDS_JORNADA_APP; nunca sobrescrever baseline ou
TDS_FICHA_ALUNO automaticamente. Power Query deve consumir overlay por registro_id
preservando campos humanos, distinguindo null de 0, com verificação de unicidade.
Histórico de eventos usa tabela própria; relação 1:1 não recebe cada evento.

## Piloto confirmado por Rafael

Inteligência Artificial e Inclusão Digital: Palmas, Itaguatins e Augustinópolis.
Rafael confere cada vínculo; período comum 11/10/2026–30/10/2026 confirmado.
Carga horária oficial: 40 horas. Curso `ia-cartilha` existe no catálogo público
da API de produção; oferta/edição e equipe autorizadas ainda precisam de resolução.
Equipe/oferta/matrículas reais ainda não provisionadas.
Reusar cadastro e matrícula; propor uma turma por território para controle local.
Sem baseline, manter pendência e aplicar o instrumento de coleta existente.
Com ficha existente somente no BI, o instrutor pode usar seu registro_id real
como referência source=fabric:tds-inscription-v1 e record_id=bi_record_id, sem
exigir ou fabricar um ID de tablet. Reusar a mesma reserva e auditoria existentes.
Nunca confirmar apenas porque nomes parecem iguais. Vínculo ambíguo permanece
pendente; estado não mede falha do aluno. Atendimento solicitado não prova
conversa iniciada/resolvida nem mentoria; KV legado não identificado é desconhecido.

## Aceite necessário

Testes de sessão concorrente, replay de vínculo, conflito entre pessoas/turmas,
revogação, export sanitizado/linhagem, certificado e telemetria sem crédito;
migração vazia e base 0019 em SQLite e PostgreSQL staging isolado; teste Android
online/offline/troca de conta. Confirmar versão/build Play com o chat/artefato
original. Flag desligada e produção preservada até gates de release.
