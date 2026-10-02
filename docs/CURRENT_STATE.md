# CURRENT STATE

- CURRENT RELEASE: código `1.4.0+13`; produção histórica `1.2.0+11`, não revalidada na Play. Release bloqueada por seus gates.
- CURRENT WAVE: 2 — Dynamic Learning; fatia 2A aprovada funcionalmente em staging. Wave 1 aprovada em `0081ab0`.
- CURRENT ACCEPTANCE GATE: POCO aprovou 2A e Classroom offline/revogação em 01/10; `course_versioning_xiaomi` e `classroom_cold_offline_xiaomi` fechados. Certificado e Evidence offline pendentes; Wave 2 completa e produção ainda não aprovadas.
- STABLE: MVP/assinatura preservados; Context Core, publicação remota, edição fixa e sincronização verificados em staging.
- IN PROGRESS: ativação do recorte identidade/jornada; código e QA sintético concluídos. IPEX responsável, confirmado por Rafael. Piloto IA e Inclusão Digital: Palmas, Itaguatins, Augustinópolis; 11–30/10/2026; 40h; Rafael confere vínculos.
- BLOCKED: Rafael sem conta online; oferta/equipe e release mantêm seus gates. Login Google resolvido. Rastreio sintético no BI validado; consultas legadas ainda têm 68 linhas com erro no Baseline e 65 na Jornada, incluindo datas inválidas.
- DO NOT TOUCH: produção, keystore, certificados KV, secrets, baselines e rascunhos/execuções QA preservados.
- LAST VERIFIED: 2026-10-01; POCO 2A: oito fases/quatro verificações host, replay sem duplicata, Play/DEV preservados. BI sintético/filtros passou, datas legadas pendentes. Flutter 367 + analyze; API 346/347 + rerun 1/1. Clone 0005→0020/retorno da imagem antiga e backup externo verificados.
- NEXT ACTION: concluir gates técnicos de release/proveniência e preparar conta/equipe/oferta reais; conferir erros de dados legados antes da promoção do BI. Não repetir login Google ou confirmação IPEX. Retomar 2B depois.

QA de catálogo editorial 02/10: curso sintético `validacao-dinamica-tds` criado
em staging Cloud (draft → in_review → published v1/v2); um APK debug com
`REMOTE_CATALOG_ENABLED=true` e contexto/outbox/jornada desligados recebeu v1
e depois título/questão de v2 no mesmo binário e instalação, sem rebuild.
Emulador QA próprio: módulos/pergunta/três quizzes abriram; offline após cold
restart trouxe quatro cursos do cache remoto + nove assets; rede restaurada.
Flag false por padrão. A união offline dos nove assets é exceção opt-in à
semântica anterior de retirada editorial por lista vazia; requer decisão
antes de produção. Evidência `production/evidence/remote-catalog-qa-2026-10-02.json`.
Não equivale a aceite de release ou Wave 2 integral.

Auditoria de ambientes 02/10: Git ainda sem remote/tag; 48 tracked modificados
e milhares de outputs QA preservados localmente, agora ignorados para evitar
stage acidental. GitHub CLI indisponível; nenhum commit/push. Endpoint real
`https://ead.ipexdesenvolvimento.cloud/tutor-api/health` respondeu 200 com DB e
TLS válido; `/version` e `/live` responderam 404, schema/runtime/restore não
comprovados. API/Alembic candidatos agora falham sem PostgreSQL explícito em
production; compose candidato declara ambiente, sem deploy. Gates Android/Dart
de release aceitam só endpoints fixos e flags false; preflight atual falha na
config ignorada e freeze segue ativo. Backup offsite/restore completo,
proveniência Git e upgrade Play pendentes. `PRODUCTION_RELEASE_READY=false`.
Ver production/ENVIRONMENT_CONTRACT.md, PRODUCTION_READINESS.md e
TDS_MEASUREMENT_CONTRACT_V1.md. Baseline físico, Power BI legado, Play,
produção e assinatura não alterados.

Continuação PDF/acesso 01/10: nove viewers Drive de produção respondem com os
títulos esperados; PDF IA confirmado por metadata, sem prova de render Android.
Botão mantém hospedagem externa e registra somente pedido de abertura consentido,
com tratamento de falha; 17 testes Flutter do recorte, nove repetidos após ajuste
de enfileiramento, cinco API e analyze passaram. Contrato COURSE_PDF_CONTRACT.md.
Turma sintética abbdfe6c3fd54366b26c46d1d6075954 preparada uma vez. Após duas
instalações canceladas e preservadas, Rafael confirmou ready e instalou o mesmo
APK. Oito fases passaram em oito processos: retomada fria, fila offline,
reconexão sem duplicata, outra conta, revogação conhecida online/offline e PDF.
Dois eventos offline confirmados uma vez; progresso QA de 2,5% para 5%; 332
eventos e 77 registros anteriores preservados. Play/DEV intactos, rede restaurada,
QA encerrado. PDF abriu pelo botão real; Rafael escolheu conta do Drive e confirmou
a abertura, observada também em screenshot. Um pedido de abertura, zero crédito;
páginas/tempo de leitura e download offline continuam não medidos/verificados.
123 hashes de fonte conferidos. Aceite classroom-access-physical-acceptance-
2026-10-01.json; gate classroom_cold_offline_xiaomi fechado, freeze preservado.

Continuação concluída: Cloud staging restaurado da pausa, 7 contas QA intactas;
backup + migration 0019→0020 preservaram colunas/valores das 42 tabelas. Deploy
`f060ca99-4715-4265-8466-9249329a8e1a` saudável; 62 dependências conferidas no lock
(Python Cloud 3.13.15 versus local 3.13.9). Docker candidato locked passou oito
testes; não implantado, proveniência Git de release pendente. POCO usou pacote
debug `.dev.dynamicqa.r<run_id>` e aprovou 2A: v1 5%, v2 0%, histórico preservado.
Rede restaurada e QA encerrado. Gates de certificado e Evidence offline seguem
pendentes após a continuação Classroom descrita acima; emissão autenticada API→Worker ainda exige
implementação na fatia própria. Produção, flags fora de QA e freeze preservados.
Evidência: production/evidence/wave2a-physical-acceptance-2026-10-01.json.

## Completed
01/10: identidade usa users/matrículas existentes; migration 0020 adiciona ponte
BI conferida. Sem baseline continua pessoa matriculada pendente, sem ficha
fictícia. Fila por dono, sessão concorrente, consentimento novo e tempo de tela
sem crédito implementados. POCO manteve Play 1.2.0+11 e passou online/offline/
reconexão; dez eventos offline entregues uma vez. BI final é cópia local com
ParticipantesApp/JornadaApp/AtividadeApp/PessoaApp e página RastreioApp. Desktop
validou duas contas QA pendentes, 3 minutos e um pedido de ajuda; seleção de cada
pessoa filtrou corretamente. As 17 páginas originais e Jornada foram preservadas.
Baseline/ComplementoBaseline da cópia receberam tipos numéricos explícitos para
impedir SUM sobre texto após refresh; resumo voltou a calcular. Fonte preservada.
40h confirmadas; curso ia-cartilha já existe no catálogo público. Gate físico
de conferência comprovou ID pendente estável, source BI real sem tablet e histórico.
API temporária removida; produção e staging anteriores saudáveis. Pacote final:
outputs/TDS_Journey_Pilot_2026-10-11/TDS_Rastreio.pbip. Ver TDS_JOURNEY_QA_2026-10-01.
Rafael confirmou cartilha atual e ausência de conta. Reutilizar cadastro na
WelcomeScreen e autorização administrativa de equipe, sem senha em chat ou
identidade QA. API pública atual não expõe admin/oferta nem edição fixa no curso;
referência/hash e decisões registrados no pacote, sem alteração de produção.

Continuação Astra: ensaio cec516308697 restaurou dump real isolado, preservou
colunas dos 14 objetos originais e nove cursos, atualizou até 0020 e validou API
anterior na base migrada. Edição ia-cartilha v1 resolvida:
d496856d-6bf3-5f8a-92a3-f292cca92ed5. Backup DPAPI CurrentUser fora do VPS testado;
requer o perfil/chaves Windows deste usuário. Compose API agora recebe pseudônimo
e flags false; worker legado exige perfil explícito. Config validada sem deploy.
Google Sheets: cópia privada 1a7KS1twBIlSO5kTXCmUVvmEIxkbt7IwttHKW4Xqzrzs,
três abas novas com duas contas QA pendentes, três linhas de atividade sintética
e nenhuma inscrição. Fonte original e Fabric intactos; não promover esses dados.
IPEX confirmado explicitamente em 01/10; plano/manifesto atualizados. Rafael
concluiu login Google. Refresh/filtros e save no Desktop verificados; manifesto
registra limites: JornadaApp vazia, sem validação BI de certificado/vínculo real.
Resumo manteve 510 inscrições (421 digitais/89 scans). Datas inválidas foram
observadas na fonte legada; não corrigir por inferência nem contar erros das duas
consultas como pessoas distintas. Ver journey-bi-desktop-2026-10-01.json.

Wave 1: LearningContext v2, Membership/Enrollment físicos, migration 0019,
autorização contextual, projeção compartilhada e outbox SQLite por dono/ambiente.
Seis fases Android e isolamento HTTPS aprovados; progresso original permanece 10%.
Staging FastAPI Cloud + Supabase isolado, secrets próprios, API locked validada;
candidato temporário VPS removido, VPS original preservada.
2A: catálogo por API, recarga da Home e cards adaptáveis. Autor criou/salvou/preview;
coordenador publicou v1/v2 no mesmo APK. Turma antiga manteve v1 e posição;
estudo online/offline/reconexão chegou a 5%, nova turma v2 permaneceu em 0%.
Replay sem duplicata, sete transições editoriais autorizadas e professor/aluno
com projeções idênticas. Rede e processo QA restaurados/encerrados. Tentativas
falhas anteriores e rascunho preservados; causas em BOUNDARY_DIAGNOSTICS.

## Changed contracts
`cohort-enrollment-v2` mantém linhagem `legacy_enrollment_id`. Eventos não concedem
autorização; posição local não equivale a progresso oficial. Flags de contexto e
outbox durável false por padrão, true no staging QA. 2A não criou migration/API:
reutiliza Course/CourseVersion/editor, snapshots imutáveis e cache por URL da API.
Instrumentação usa o AuthRepository real do Provider; operador fica só no host.

## Known issues
Refresh/login/requests tardios não restauram sessão após logout/troca: corrigido
e testado no recorte de 01/10. Logout ainda limpa filas
legadas de avaliação/check-in; tentativas antigas não estão isoladas por dono.
Quiz/question embutidos não persistem ActivityAttempt contextual por bloco.
Role global permanece no legado; retenção de recibos ainda precisa de política.
Ack pode anteceder revalidação do progresso. Arquivamento manual, devolução de
revisão, Creator completo, paridade visual integral, demais gates físicos, AAB assinado,
privacidade/Data Safety e Play ainda não aprovados. APK de gate contém contas
sintéticas e não é artefato de distribuição.

## Next gate
Promover rastreio somente após BI/oferta/release; implementar 2B sem duplicar entidades, com tentativas
e filas por dono/API/matrícula/edição/bloco. Só avançar para Classroom após Wave 2
completa. Não iniciar outra wave que modifique simultaneamente contratos centrais.

## Relevant files
`production/WAVE1_ACCEPTANCE.md`, `production/WAVE2A_ACCEPTANCE.md`,
`production/DYNAMIC_LEARNING_CONTRACT.md`, `production/DYNAMIC_ACTIVITY_AUDIT.md`,
`production/BOUNDARY_DIAGNOSTICS.md`, `production/TRACEABILITY_MATRIX.md`,
`production/API_MATRIX.md`, `production/CLOUD_STAGING.md`, `production/evidence/`.
Cloud: https://tutor-tds-staging.fastapicloud.dev; Supabase `lgtphbbpgqnzduhtyate`;
deploy `f060ca99-4715-4265-8466-9249329a8e1a`; somente dados sintéticos.

## Artefato de comunicação — 29/09/2026
Pré-pitch vigente: `outputs/Tutor_TDS_Pre_Pitch_Identidade_TDS_29-09-2026.pptx`, sete slides com identidade/logomarca oficiais TDS, negócio, produto e staging. Capturas existentes reaproveitadas; produção histórica, testes e hipóteses comerciais distinguidos. Originais/versões anteriores preservados. Sem alterações de app/API/release. Rastreabilidade: `production/PITCH_EVIDENCE_2026-09-29.md`.
