# Decisões vigentes

## Retomada delimitada #303 — 19/10/2026, após STOP

O usuário autorizou nesta sessão somente a menor correção do ETag fraco no
cliente Flutter, testes focais e novo APK QA/homologação Android, usando PR304
HEAD `f9260a6d118e7142b0c9ec7f11a14b09440c725a` após conferência remota.
ETags forte/fraco devem representar exatamente a mesma revisão JSON, mantendo
autorização, fingerprint, mídia, schema e cache. Homologar primeiro isoladamente;
reativação produtiva exige teste focal concluído, rollback preparado e aprovação
específica pós-STOP. Não repetir #299/#302, alterar LearnPress, fazer merge,
assinatura real ou Play sem os respectivos gates. Ver recibo da #303.

## Autorização final institucional — 19/10/2026, posterior ao PR302

O responsável autorizou promoção controlada do adaptador e patch299 ao portal
ead.ipexdesenvolvimento.cloud, após backup produtivo recuperável/restore isolado;
criação de nove contas genéricas lp_teacher com e-mails institucionais controlados,
custódia segura e autoria legítima de curso/aulas sem capabilities globais.
Conteúdo educacional pode ser público sem matrícula quando direitos individuais
estiverem comprovados; presença de arquivo não é prova. Identidades LP/FastAPI
permanecem distintas. Público amplo/gratuito, não exclusivamente adulto; nenhuma
conformidade infantil ou declaração legal é inferida dessa decisão.
Uso da chave de upload existente, teste interno e rollout produtivo limitado
foram autorizados condicionalmente a certificado/versionCode Play atuais, QA,
Xiaomi/áudio/TalkBack, revisão de dados/políticas e aceite final. Não autoriza
100%, force-push, auto-merge ou merge genérico. Após duas falhas iguais, parar
apenas a frente afetada. A execução parcial e STOP303 estão no recibo
`production/portal-promotion-20261019/README.md`; autorização não significa PASS.

## Precedência institucional de 19/10/2026 — LearnPress nativo

A decisão #249 e a missão final de 19/10 prevalecem sobre trechos históricos
que vedavam qualquer matrícula no WordPress: LearnPress é autoridade de
inscrição e progresso **da oferta EAD** e do material editorial; FastAPI
continua autoridade de identidades/vínculos institucionais, turmas, frequência,
evidências e certificados oficiais. Uma matrícula não comprova a outra.

Reutilizar `lp_course`, `lp_lesson`, papel `lp_teacher` e login/cadastro/matrícula
nativos. O responsável formal deve ter autoria compatível de curso e aulas.
Administração/revisão mantém suas atribuições; editor genérico não recebe
permissão adicional por conveniência. Verificar todos os pais de aula
compartilhada. Proibidos `edit_others_*` global, elevação temporária, bypass de
`map_meta_cap` ou mudanças core/vendor. Titularidade dos nove cursos reais
depende de confirmação institucional; não reatribuir automaticamente.

Sem SSO homologado, o app abre a URL oficial HTTPS no navegador, com identidades
distintas. Nenhuma sincronização LP→FastAPI inferida, nem matrícula/frequência
por reprodução. QA sintético autorizado no VPS existente; produção, merge,
assinatura e Play exigem autorização própria. Provas e limitações de #297 em
`qa/ead-native-owner-20261019/README.md`; decisão não equivale a gate aprovado.

1. 2026-09-23: contrato do usuário redefine Wave 1 como Context Core. Números
   de ondas em documentos de 19–21/09 são históricos; não significam gate atual.
2. Reusar `Institution` como Organization e `Classroom` como Cohort; não duplicar
   entidades por diferença de nome. Não remover `User.role` global de uma vez.
3. A matrícula existente não satisfaz Membership+CourseVersion. Backfill deve
   considerar aluno em várias turmas no mesmo programa/curso; não há mapeamento
   garantido de uma matrícula antiga para uma única nova matrícula.
4. `StudyProgress` é retomada local, enquanto dashboard calcula horas validadas.
   O gate exige projeção compartilhada, além da retomada; não comparar essas duas
   métricas como se fossem equivalentes.
5. Não usar documentação antiga como prova de staging atual. Produção e assinatura
   preservadas; nenhuma promoção até gate completo e checklist da release.
6. Stitch autenticado no navegador integrado: HTML original Classroom exportado
   e validado. Cache completo não comprova paridade visual do Flutter.
7. Skill Flutter expert lida da fonte pública sickn33/antigravity-awesome-skills
   e instalada em `.agents/skills/flutter-expert/SKILL.md` do usuário.
8. Primeira fatia usa adapter `legacy-lineage-v1` sobre relações existentes, atrás
   de flag desligada. Membership UUID5 identifica chave natural existente, sem
   nova concessão de acesso. Migração física continua pendente.
9. Aluno e instrutor usam `_student_progress`. Retomada local é separada por
   contexto; evidências contextuais preservam dono/ambiente no logout.
10. PostgreSQL 16 isolado na VPS passou no golden path da API. Isso não equivale
    a staging público ou teste Android; nenhum gate foi aprovado.

11. Com flag contextual ativa, atividade com turma+edição é autorizada pela
    matrícula ativa mesmo quando User.role é teacher/monitor/admin. Catálogo,
    mídia e listagem legados mantêm política anterior até migração específica.

12. Fila SQLite atrás de DURABLE_LEARNING_OUTBOX_ENABLED=false; importar legado
    em transação e manter recibo para replay. Nunca inferir dono de evento legado.
    Falha definitiva fica pendente bloqueada; não interrompe demais envios válidos.
13. Preflight físico somente leitura antes do backfill; preservar ambiguidade
    histórica explicitamente. Staging auditado sem alteração de dados.
14. Reusar class_enrollments para matrícula Membership+CourseVersion; manter
    enrollments como linhagem legada e adicionar cohort_memberships. Migration
    0019 validada em PostgreSQL descartável; resolver v2 integrado e testado.
    Colunas contextuais aceitam todas nulas para rollback de servidor antigo,
    nunca preenchimento parcial. Reconciliar antes de reativar consumidores.
15. Contrato v2 usa enrollment_id contextual + legacy_enrollment_id explícito.
    Progress mantém semântica antiga e acrescenta context_enrollment_id; mesma
    projeção completa em aluno/instrutor. Flutter lê cache v1/v2, preservando
    posição com linhagem exata, sem transferir dados entre contextos.

16. 2026-09-23: usuário autorizou staging FastAPI Cloud + Supabase. Preservar
    FastAPI/Auth/contratos/Flutter; Supabase fornece PostgreSQL inicialmente.
    Projeto staging isolado lgtphbbpgqnzduhtyate; Data API e exposição automática
    de tabelas desabilitadas. Somente seed sintético; Auth/Realtime/Storage
    não migrados nesta etapa. Gate Wave 1 continua obrigatório.

17. 2026-09-23: gate funcional Wave 1 aprovado em staging, sem promoção de
    produção. WAVE1_ACCEPTANCE e hashes de evidências comprovam seis fases Android,
    aluno/professor com projeção idêntica, offline sem duplicata e isolamento HTTPS.
    Atualiza as pendências históricas dos itens 8/10/16; próxima wave autorizada
    pelo contrato é Dynamic Learning. Manter Course/CourseVersion/editor existentes;
    não duplicar domínio nem remover os limites de release/QA físico.

18. 2026-09-23: fatia 2A aprovada funcionalmente em staging, execução
    `b65cb8de005444fb9ac707e1d9c6f5f8`. Um APK comprovou publicação de duas
    edições, turma fixada, progresso compartilhado e offline sem duplicatas.
    Sem nova migration/API. Wave 2 continua aberta: corrigir refresh após logout
    e concluir tentativas contextuais na fatia 2B antes da próxima wave.
    `production/WAVE2A_ACCEPTANCE.md` delimita evidências e pendências de produção.

19. 2026-10-01: usuário priorizou rastreio incremental e escolheu piloto IA e
    Inclusão Digital em Palmas, Itaguatins e Augustinópolis, conferido por Rafael.
    Reusar Auth/matrícula/baseline/source/history; migration 0020 aditiva, sem
    migração central concorrente. Identidade existe antes da ficha; preservar
    pendência quando ela faltar. Source BI real pode substituir a necessidade
    de um código histórico de tablet, sem fabricar ficha/resposta. Telemetria
    exige novo consentimento e não concede resultado acadêmico. BI recebe overlay
    separado; fontes originais e KV preservados. Flags false, release congelada.
    Rafael confirmou 11–30/10/2026 e 40h; ia-cartilha localizado no catálogo
    público de produção. Não duplicar curso; resolver oferta/edição autorizadas.
    QA físico e migração isolada concluídos, ambiente temporário removido.
    Refresh/render do BI e gates de release continuam necessários.
    Rafael confirmou cartilha atual e ausência de conta online. Reutilizar
    cadastro seguro existente e atribuição administrativa de equipe; não criar
    conta fictícia nem pedir senha no chat. Conteúdo público referenciado por
    hash; publicação/fixação de edição ainda deve usar contrato canônico.

20. 2026-10-01: Astra executa preparação e validação técnica; não transferir ao
    usuário testes que podem ser automatizados. Cópia real de produção restaurada
    isoladamente e migrada 0005→0020, dados originais preservados e catálogo
    compatível com imagem antiga. Edição v1 de ia-cartilha resolvida pelo contrato
    legado. Backup criptografado fora do VPS verificado. Sem promoção de ambiente.
    BI aberto no Desktop após correção TMDL; nova fonte de uso fica em cópia Sheets
    privada de homologação, com dados explicitamente sintéticos e fonte original
    preservada. Refresh/filtros aguardam clique humano no modal WebView2 que a
    ferramenta não conseguiu acionar. Instituição e conta Rafael ainda reais,
    não inferidas. Flags false; release exige seus gates antes de qualquer AAB.

21. 2026-10-01: Rafael confirmou IPEX como instituição responsável pelas três
    turmas do piloto TDS. Planos de cadastro/ativação atualizados; preservar curso,
    cidades, 11–30/10 e 40h. Reutilizar Institution existente equivalente antes
    de criar; confirmação institucional não fabrica conta, matrícula ou vínculo
    de baseline. Cadastro pessoal de Rafael continua pendente.

22. 2026-10-01: após login Google pelo titular, validar o BI com duas contas QA
    pendentes e três atividades; filtro por pessoa passou. Refresh revelou tipos
    any das consultas legadas convertidos em string, quebrando SUM. Fixar tipos
    int64 na saída de Baseline/ComplementoBaseline somente na cópia, preservando
    nulos, fontes e regras. Cartões antigos voltaram a calcular; 17 páginas e
    Jornada preservadas. Erros legados de dados (68 Baseline/65 Jornada) continuam
    explícitos, com data inválida observada; não inferir correção nem declarar
    aceitação integral do BI. Sem publicação Fabric/Play ou alteração de produção.

23. 2026-10-01: restaurar staging Cloud existente e preservado, sem recriar contas
    ou banco. Backup externo verificável antes de 0019→0020; valores anteriores
    das 42 tabelas permaneceram iguais. Deploy f060ca99-4715-4265-8466-9249329a8e1a
    com 62 dependências do lock. Docker candidato também usa lock/bases por digest;
    imagem não implantada e Git/proveniência de release ainda pendentes. QA físico
    usa pacote debug exclusivo por run para preservar Play, DEV e ensaios falhos.
    Uma recuperação só foi admitida após comprovar que o APK exato já instalado
    nunca havia sido lançado; nenhum replay de fase Android com mutações.
    Resultado físico deve fechar somente o gate demonstrado, mantendo freeze e
    os demais gates. Emissão autenticada API→Worker/KV continua lacuna de
    implementação da fatia Certificates; aprovação de pedido não equivale a emissão.
    Fechamento: oito fases/quatro hooks passaram no POCO, evidência
    wave2a-physical-acceptance-2026-10-01.json. Apenas course_versioning_xiaomi
    marcado passed; três gates físicos e release_build_allowed=false preservados.

24. 2026-10-01: manter as nove cartilhas PDF nos links Google Drive existentes;
    estudo interativo JSON e PDF externo são caminhos distintos. Auditoria HTTP
    do viewer não equivale a renderização Android. Botão PDF passa por controller
    com tratamento de falha e registro consentido de pedido de abertura, sem
    crédito de estudo ou inferência de leitura. Reusar eventos/outbox/export,
    sem SaaS, storage ou migração novos. URL congelada na edição não congela os
    bytes do Drive. Gate de Classroom/revogação usa turma sintética nova e pacote
    QA próprio, preservando os vínculos dos runs aprovados; revogação é fixture
    controlada de staging, não implementação de comando administrativo.
    Resultado: run abbdfe6c3fd54366b26c46d1d6075954 passou oito fases no POCO,
    após confirmação presencial da instalação. Congelar o APK e não repetir
    fases/fixtures foi preservado. Gate classroom_cold_offline_xiaomi fechado;
    PDF renderizado após seleção manual de conta Drive, um evento sem crédito.
    Certificado e Evidence offline continuam pendentes; freeze inalterado.

25. 2026-10-02: contrato de ambientes protege DEVELOPMENT/STAGING/PRODUCTION;
    GitHub/commit/tag ainda não comprovados, nenhum push automático. API/Alembic
    candidato rejeitam production sem DATABASE_URL PostgreSQL explícita; compose
    candidato declara TUTOR_ENVIRONMENT=production, sem deploy. Endpoint IPEX
    /tutor-api/health 200 com TLS válido não comprova volume/schema/restore;
    /version e /live ainda 404 em produção. Config ignorada atual não passou
    preflight; gates release restringem endpoints e flags false, sem alterar
    release_status.json. Outputs/evidências preservados; BI/artefatos locais
    precisam de custódia independente antes de dois desktops equivalentes.
    PRODUCTION_RELEASE_READY=false até GitHub/proveniência, offsite+restore,
    schema/upgrade e decisão editorial de fallback offline. Measurement v1
    mantém baseline papel→planilha; etapas não validadas ficam null.

26. 2026-10-03: conciliação documental META 04, sem nova decisão institucional.
    As decisões posteriores registradas nas Issues #6 (comentário 5965300113),
    #8 (5965176322) e #33 (5965176812) confirmam 75% como referência flexível,
    reposição validada pelo instrutor, lista física assinada prevalente até
    correção formal, formação alvo 80h com composição adaptável, baseline
    regularizado antes do certificado sem bloquear estudo e follow-up 30/60/90
    ancorado no certificado. Elas superam perguntas históricas e a antiga âncora
    de aplicação validada em Measurement v1. Não alteram cargas históricas do
    piloto dos itens 19/21, nem comprovam enforcement ou emissão por edição.
    Proveniência e detalhes: program/OPERATING_DECISIONS_2026-10-03.md e matriz
    https://github.com/rafaloct/tutor-tds-platform/pull/24#issuecomment-5968944747.
    Campos de resultado sem fonte integrada continuam null; reemissão exige
    regra específica antes de automatizar seu marco. Merge/produção permanecem
    gates próprios, sem AAB ou autorização nova nesta conciliação.

27. 2026-10-03: correção de precedência do item 26. A decisão posterior da Issue
    #5, comentário 5965837795, substitui 75% por 70% dos encontros configurados
    por oferta e define 80h formais por curso, sem cronômetro obrigatório ou 40h
    digitais como condição. Trilha obrigatória por edição tem validação backend.
    Baseline registrado, frequência >=70%, trilha concluída e certificado gerado
    compõem CAPACITADO. CERTIFICADO_VALIDO acrescenta fichas regularizadas assinadas
    pelo instrutor e certificado assinado pela coordenação. Geração não é validade
    e pode preceder regularização; estados GENERATED, PENDING_INSTRUCTOR_VALIDATION,
    PENDING_COORDINATOR_SIGNATURE e VALID ficam separados. Exceções de frequência
    permanecem pending_human_validation, sem presença automática. Baseline admite
    diferentes origens documentadas, sem exclusividade Jotform. Não sobrescrever
    carga/evidência histórica nem inferir fontes ausentes no BI. A âncora de #8
    continua no certificado, mas geração versus validade e reemissão ainda exigem
    definição antes de automação. #39 permanece candidato preservado; #51 requer
    reconciliação pelo seu escritor. Plano de Trabalho não examinado, provider
    real e ativação não comprovados. Matriz: program/JOURNEY_CONTRACT_RECONCILIATION_2026-10-03.md.

28. 2026-10-03: registro do candidato #39 implementando a decisão direta do
    usuário na Issue #5 comentário5965837795: curso80h formal, presença70% de encontros configurados, baseline
    multiorigem e checkpoints integrais. CAPACITADO e CERTIFICADO_VALIDO são
    fórmulas separadas. Geração antecede validação humana; lifecycle de quatro
    estados, instrutor assina fichas com cobertura da oferta, coordenação assina
    certificado. Recorte sintético v2 reutiliza EvidenceItem/StudentBaseline;
    último checkpoint gera automaticamente e registra pending_dispatch para
    tdsdados@gmail.com, sem SMTP/VPS real. Plano citado não anexado. Gate real
    permanece deliberadamente fechado; legenda antiga por horas/approval só se
    aplica a ofertas sem política nova. Não mudar checkpoints retroativamente.

29. 2026-10-05: Issue #138 estabelece FastAPI/PostgreSQL como autoridade
    funcional do ciclo de turma territorial. Capacidade padrão é 30 participantes
    ativos; exceder exige coordinator escopado ao programa e motivo auditável.
    O candidato mantém RBAC fail-closed: program_operator/coordinator podem
    preparar e ajustar a turma enquanto planned; ativação/encerramento e mudança
    de equipe após ativação ficam restritos à coordenação. Professor/monitor não
    ganham poder administrativo novo. Município/local da oferta permanecem
    separados de residência do participante; encerramento não fabrica presença,
    frequência ou certificado. Feature flag segue false por padrão: com
    CLASS_LIFECYCLE_ENABLED=false, /admin/classes preserva criação/status e gestão
    de monitor legadas; com a flag true, novas turmas administrativas também
    precisam iniciar planned e equipe pós-ativação usa o fluxo contextual.
    Capacidade 30 e rejeição de novo vínculo em turma closed não ganham bypass.
    O backend expõe candidatos de equipe mínimos e listagem contextual de turmas
    para o Flutter, sem CPF/telefone nem dependência de /operations/scopes.
    Decisão da coordenação em 05/10/2026: sessão aberta bloqueia o encerramento
    da turma. O readiness deve expor open_sessions como blocker e negar active→closed
    enquanto houver sessão aberta. Demais pendências de evidência, presença,
    regularização e certificado permanecem warnings e não bloqueiam o fechamento
    por si só. Sem staging ou produção nesta decisão.

30. 2026-10-07: Dynamic Learning 2B evolui as tabelas existentes de avaliação,
    sem criar um domínio paralelo. O candidato sobre `fbb4b6a` adiciona a
    migration `20261007_0030`, com linhagem `published_block` completa ou legado
    `practice` todo nulo, e preserva IDs/versões do snapshot publicado até o
    Flutter. Gabarito, nota e evidência determinística pertencem ao servidor;
    conclusão tem crédito zero e nunca concede autorização, matrícula,
    frequência, carga horária ou certificado. Persistência local antecede o
    avanço da interface e a fila é segregada por dono/API/contexto. Professor e
    admin só leem a turma exata; monitor e pessoa externa não recebem respostas.
    `DYNAMIC_ACTIVITY_ENABLED=false` por padrão e requer Context Core ativo.
    API, Flutter e runner foram verificados localmente, sem commit, deploy,
    staging, produção ou secret alterado. O gate
    `dynamic_activity_contextual_android_e2e` é obrigatório antes de ativar a
    flag, mas não bloqueia build produtivo com ela false. Cloud `0024` e VPS
    `0029` seguem sem compatibilidade confirmada nem SHA implantado exato; `0030`
    é somente local. O runner usa fixture e identidades sintéticas; apenas a
    conta outsider pode precisar ser criada ou confirmada se ausente, sem secret
    novo de produção.
31. 2026-10-07: tentativa publicada possui identidade canônica independente da
    URL da API e unicidade parcial no banco por dono/contexto/bloco. Conteúdo de
    prática não pode ocupar `published-block:` nem carregar proveniência
    publicada; projeções públicas/do aluno não expõem gabarito, `isCorrect`,
    `value`, feedback ou explicações. O evento de conclusão omite IDs de pessoa e
    matrícula. Clock skew futuro é recuperável somente por uma correção de
    `updated_at`, sem mudar revisão, respostas ou contexto. O runner só considera
    restauração de revogação efetiva após reler a tentativa canônica.

32. 2026-10-12: decisão posterior da pessoa responsável substitui, no item 29,
    as restrições de autoridade para ativar/encerrar e o bloqueio de capacidade.
    `program_operator` ativo no programa pode preparar, ativar e encerrar turma;
    `coordinator` escopado conserva esses poderes. Alteração de equipe após
    ativação continua reservada à coordenação. A referência de 30 participantes
    ativos gera aviso antes da inclusão e no resultado, mas não bloqueia a 31ª
    inclusão por operador, coordenação, admin ou professor autorizados. Motivo
    especial de exceção deixa de ser obrigatório; comandos contextuais mantêm
    motivo e recibo usuais. Recibos históricos `assign_capacity_override` são
    preservados. Escopo institucional/programático, rejeição de novo vínculo em
    turma fechada, sessão aberta como bloqueio ao encerramento e auditoria
    permanecem. Esta decisão ainda não constitui aceite de staging ou produção.

33. 2026-10-15: usuário autoriza configurar o portal Drupal em produção no VPS
    existente usando Tailscale e Dokploy, construir a imagem no VPS e gerar
    credenciais sob custódia do Dokploy sem hardcoding/exposição. Host confirmado
    portal.ipexdesenvolvimento.cloud. Escopo público/editorial isolado da API e
    WordPress; funcionalidades autenticadas/IA dependem de suas verificações.
    Não rotacionar chaves JWT/CPF nem modificar bancos acadêmicos. Autorização
    não constitui aceite E2E nem permissão de merge. Issue210/PR211.

34. 2026-10-19: usuário autorizou instalar o adaptador WordPress/LearnPress no
    staging institucional isolado já existente e encerrar somente sessões SSH
    obsoletas. O portal público não pode ser prejudicado; não contratar ou
    provisionar nova VM sem necessidade, porque a VM alugada anterior não ficará
    disponível. A instalação no sandbox Docker interno passou com backup e
    restore, mas o save real por `lp_teacher` retornou HTTP 500 e ficou bloqueado
    na Issue #297. A autorização não inclui produção, usuários reais, ativação
    das 48 aulas, merge, assinatura ou Play Store.

35. 2026-10-20: após proposta focal, usuário respondeu “autorizado” para
    promover o PHP corrigido do PR306, com backup/hash/rollback e smoke
    institucional gzip/ETag/Android curso1298 usando APK305 existente.
    Essa intervenção não inclui publicação de aulas, merge, assinatura ou Play.
    Promoção e cache institucional passaram; evidência em
    `production/etag-promotion-20261020/README.md`. Não equivale a aceite
    integral de lançamento nem resolve a Issue297.

36. 2026-10-20: responsável declarou “se tiver funcional ta autorizado, os
    direitos da midia são do proprio projeto tds”. Titularidade institucional
    confirmada para as mídias próprias TDS, sem inferir direitos de terceiros.
    Issue308 vincula cada aprovação à fonte/hash/fingerprint conferidos e
    publica progressivamente após checks, começando pela aula1420/curso1298.
    A decisão não comprova playback, áudio, acessibilidade nem declarações Play.
    Preservar matrícula, autoria, avaliações privadas e demais gates de release.
