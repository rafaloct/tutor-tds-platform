# Wave 2A — publicação e consumo remoto

**WAVE2A_FUNCTIONAL_STAGING_PASSED**, 2026-09-23. Candidato `f3ee6f4`, sobre o
produto Flutter validado em `bfa4fe6`; API implantada preservada. Este aceite não
encerra a Wave 2, não aprova produção e não libera a publicação na Play Store.

## Jornada verificada

Execução `b65cb8de005444fb9ac707e1d9c6f5f8`, Android 16/emulator-5556,
`com.tutortds_cartilhas.dev`, staging FastAPI Cloud/Supabase. Uma compilação,
uma instalação sem apagar dados e oito processos distintos usaram o APK
`670e3aea05116608421d68edd38eaaec7cda4566a82a2997c3beb7f2482c64fa`.
O curso estava ausente antes de instalar esse APK.

| Etapa | Evidência funcional |
| --- | --- |
| Autor v1 | criou/salvou sete blocos, conferiu prévia sem progresso, enviou à revisão; publicação pelo autor negada com 403 |
| Coordenador v1 | publicou pela interface; rascunho não estava no catálogo público |
| Aluno v1 | recebeu curso no mesmo APK, abriu edição da turma, persistiu estudo e posição; progresso 2,5%; editor/publicação negados |
| Autor v2 | criou nova edição, alterou conteúdo, conferiu prévia; revisão obsoleta recebeu 409 sem sobrescrever dados |
| Coordenador v2 | publicou nova edição; snapshot anterior permaneceu intacto |
| Aluno após v2 | catálogo recebeu v2; turma anterior continuou em v1 com 2,5%; nova turma abriu v2 com 0% e matrícula contextual distinta |
| Offline | novo processo sem rede abriu cache da turma v1, conservou posição e persistiu atividade em fila; pendência visível |
| Reconexão | novo processo recuperou a mesma fila, sincronizou, reteve edição/posição e chegou a 5%; replay idêntico retornou 200 sem duplicação; turma v2 permaneceu em 0% |

Professor e aluno receberam exatamente os mesmos contextos, conteúdos e
projeções de progresso no fechamento. Foram preservados os 101 corpos de eventos
e os 33 registros de núcleo existentes antes da execução, incluindo o rascunho
da tentativa anterior. Total final: 209 eventos. Progresso original da Wave 1:
10%, sem alteração. Histórico editorial: sete transições dos atores autorizados.
Rede restaurada, aplicativo QA encerrado e somente forwards próprios removidos.

## Verificação e rastreabilidade

- `evidence/dynamic-learning-android.json`: oito fases, quatro verificações do
  host, identidades de instalação, hashes das fontes, paridade Android/API e limpeza.
- `evidence/dynamic-learning-b65cb8de005444fb9ac707e1d9c6f5f8-after-android.json`:
  preservação por registro, progresso compartilhado e histórico editorial.
- `evidence/wave2a-flutter-local-gate.json`: 358 testes Flutter e análise global
  sem problemas. Os 191 arquivos de produto/testes unitários/configuração seguem
  idênticos; correções posteriores limitaram-se à instrumentação, analisada separadamente.
- `evidence/wave2a-api-full-suite.json`: 334 testes da API no runtime locked.
  Bootstrap posterior por execução passou 20 testes em `dynamic-gate-run-isolation.json`.
- `evidence/dynamic-gate-auth-repository-binding.json`: reprodução da concorrência
  artificial do cliente auxiliar, uso do Provider real, análise limpa e 18 testes
  originais de autenticação aprovados. O driver exige esse vínculo em cada fase.

Sem migration, endpoint novo ou novo sistema de cursos nesta fatia. Correções de
produto: cache do catálogo por API, atualização explícita/retorno do editor e
cards de estudo com altura natural. Os contratos e matrizes delimitam o escopo.
Os arquivos das três tentativas anteriores permanecem registrados como falhas;
não compõem uma aprovação por combinação de fases de execuções diferentes.

## Limites e próximo recorte

Atividades `question/quiz` ainda não persistem tentativas contextuais por bloco:
implementar a fatia 2B conforme `DYNAMIC_ACTIVITY_AUDIT.md`. Primeiro corrigir o
risco reproduzido de refresh pendente restaurar sessão após logout; depois tratar
filas/tentativas por dono e contexto. Não inferir segurança dessas fronteiras a
partir da aprovação de publicação.

Arquivamento manual não foi exercitado neste gate; apenas o arquivamento automático
da v1 pela publicação da v2. Devolução de revisão, Creator completo, paridade visual
integral, QA em aparelho físico, release assinado, privacidade/Data Safety e Play
mantêm seus gates. O APK de instrumentação contém contas sintéticas e não é artefato
para distribuição. Produção, assinatura e flags de produção continuam preservadas.

## Extensão física concluída — 01/10/2026

O limite físico acima foi fechado para publicação/edições no POCO 2311DRK48G,
run `3c2d38851f024a1eb50667aa86dc7ce0`, em staging. Oito fases Android e quatro
verificações host passaram no mesmo APK, SHA256
`c59d4044e6a9718ec60f6f9dcb0c9d012117afe0693efd2aa6cafab0ce6a02dd`.
Pacote QA isolado por execução; aplicativos Play 1.2.0+11 e DEV preservados.

Turma anterior reteve v1 e progresso online de 2,5%; após estudo offline e
reconexão chegou a 5%. Turma nova recebeu v2 e permaneceu em 0%. Replay idêntico
retornou 200 sem duplicata; professor/aluno e Android/host tiveram os mesmos
contextos, edições e progresso. Preservados 224 eventos e 57 registros do núcleo;
332 eventos ao final e sete transições editoriais autorizadas. Rede restaurada,
processo QA encerrado e forwards próprios removidos. Conferidos 135 hashes de
fontes, oito relatórios/logs Android e quatro evidências host.

A instalação havia terminado, mas uma leitura ADB falhou antes do primeiro
lançamento. O run original foi preservado. Recuperação delimitada conferiu o
APK exato e notLaunched=true, sem recompilação/reinstalação/reset nem repetição
de fase. Todas as oito fases passaram em uma única execução da recuperação;
nenhuma fase de tentativa falha foi combinada para aprovar o gate.

Evidências: `evidence/dynamic-learning-poco-2026-10-01.json` (SHA256
`5239f8b9b6babcea7276331bc619ab7052de1bd4628e4275487a23614133dd92`) e
`evidence/wave2a-physical-acceptance-2026-10-01.json`. Somente
`course_versioning_xiaomi` foi marcado passed em release_status.json.
Certificado, Classroom/revogação e Evidence offline mantêm seus gates;
release_build_allowed=false. A correção de sessão foi validada no recorte de
rastreio de 01/10; ActivityAttempt 2B e demais limites continuam abertos.
