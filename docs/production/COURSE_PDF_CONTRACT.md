# Cartilha PDF — hospedagem e abertura rastreável

Recorte incremental de 01/10/2026. Preservar catálogo, cartilhas, arquivos e
permissões existentes. O estudo interativo usa JSON (assets no APK e catálogo
remoto/cache no candidato); o PDF complementar usa downloadUrl do mesmo curso.
Não criar Course, tabela, storage ou matrícula paralelos.

## Situação auditada

Os nove cursos de produção retornam links de visualização Google Drive. Consulta
anônima às nove páginas devolveu HTTP 200 e os títulos PDF esperados. Metadata
autenticada da cartilha IA confirmou application/pdf e 9.472.927 bytes. Isso não
substitui teste do visualizador no Android nem comprova download offline. PDFs
originais também existem na raiz do projeto; não estão entre os assets do APK.
O pacote pdf/printing do Flutter serve à geração de certificados.

O botão PDF da Home chama um aplicativo externo. Os gates 2A usam sete blocos
interativos sintéticos e downloadUrl ausente; não testaram PDF. A edição congela
a URL, mas não impede que o arquivo no Drive seja substituído. Versionamento
físico do PDF exige futuramente arquivo/URL imutáveis e digest por edição; não
declarar essa propriedade no modelo atual.

## Mudança contratada

Manter o botão e o Drive. Controller valida URL HTTPS, impede acionamento
concorrente e entrega o link ao launcher existente. Falha retorna mensagem
recuperável na Home; não abrir URL inválida nem marcar a aula concluída.
Instrumentação reutiliza AppTelemetryService → fila por dono/API → POST /events.
Somente JOURNEY_TRACEABILITY_ENABLED e consentimento do novo escopo permitem
registrar feature_used/course_pdf_open_requested. O evento significa pedido de
abertura, não download, renderização, leitura, frequência ou conclusão. Nenhuma
URL, nome de arquivo, CPF ou texto da cartilha é enviado como payload analítico.
Falha de telemetria não impede abrir o material.

Offline policy: o app não faz cache do PDF; a disponibilidade offline no Drive
é independente. O pedido de abertura consentido segue OFFLINE_WRITE_SYNC na
outbox existente; não gera segundos de estudo. Tempo em outro app não entra no
cronômetro de tela do Tutor TDS. BI já exporta feature_used/alvo_id e pode filtrar
course_pdf_open_requested; não interpretar esse evento como página visualizada.

Testes: botão/controller com URL válida/inválida, launcher falso/exception,
duplo toque e telemetria indisponível; fluxo real com consentimento, dono/API e
export sanitizado. PDF Android e demais gates de release precisam de evidência
própria. UI existente preservada; digest de referência da Home
75ac62c1bb3241aba1b3092f908b7c5f já inspecionado, sem nova aprovação visual.

## Continuação da liberação

Próximo gate físico: Classroom, reabertura fria offline e revogação conhecida,
usando turma sintética nova e package QA isolado. Não revogar vínculos dos runs
aprovados. Também pendem Evidence offline e emissão autenticada de certificados;
não usar sucesso do botão PDF como aceite de qualquer um desses gates.

Resultado parcial 01/10: nove testes do botão/controller passaram, mais cinco
Home e três screen_engagement; após ajuste para enfileirar antes do handoff, os
nove PDF passaram novamente. Cinco testes API e analyze do recorte passaram.
APK físico c1864113d395948e06c6fa95dc06d25204a3f10e4b42a99c3efa510440874ec2
compilou. Android cancelou instalação inicial e retomada, sem executar fases.
Evidências classroom-access-abbdfe6c3fd54366b26c46d1d6075954-android*.json;
produção/DEV preservados, rede restaurada, nenhuma autorização de release.
Abertura direta por VIEW também foi bloqueada por revisão automática antes de
executar; PDF Android ainda não observado. Link entregue para conferência manual.

## Validação física concluída

Após Rafael confirmar ready, o mesmo APK foi instalado no POCO. Oito fases
passaram; o botão PDF real entregou o link ao Drive e um único evento consentido
chegou à API com validated_seconds=0. O Drive exibiu seletor de contas; Rafael
selecionou uma e confirmou a abertura. Screenshot independente mostra título
IA - CARTILHA - T... e página FUNDAMENTOS TEÓRICOS renderizada. Não inferir acesso
anônimo Android a partir dessa sessão autenticada nem disponibilidade offline.
Artefatos: evidence/course-pdf-poco-2026-10-01.png e
evidence/classroom-access-physical-acceptance-2026-10-01.json. Hospedagem mantida;
sem nova contratação, upload de cartilha ou alteração de permissões. Nenhuma
medição de página/tempo externo, migração de PDF ou promoção de release.
