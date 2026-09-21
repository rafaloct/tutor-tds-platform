# Tutor TDS - auditoria de aceite das ondas

Data da fotografia: 2026-09-20

## Escopo e regra de decisão

Esta auditoria reflete o workspace atual, o staging implantado e as evidências
registradas em 2026-09-20. Ela não altera os critérios normativos de
`docs/maintenance/ACCEPTANCE_CRITERIA.md`.

Os estados abaixo não são equivalentes:

- **Implementado e testado:** código coberto por análise/testes automatizados.
- **Comprovado em staging:** execução observada no ambiente isolado publicado.
- **Aceito operacionalmente:** critério de saída demonstrado no ambiente e no
  dispositivo-alvo, com evidência reproduzível.
- **Pendente externo:** depende de conta, credencial, serviço ou decisão humana.
- **Bloqueado por intervenção:** o próximo passo técnico está pronto, mas exige
  uma ação física ou autorização do responsável.

Código testado não equivale a aceite operacional. Da mesma forma, um smoke de
API não substitui a jornada Android, os testes offline, a acessibilidade ou o
piloto. As quatro ondas de produto **não estão fechadas** nesta fotografia.

## Resultado executivo atual

| Etapa | Estado real | Evidência disponível | Prova ainda necessária para aceite |
|---|---|---|---|
| Onda 0 - Auditoria | Aceite documental parcial | Arquitetura, segurança, migração, integrações, QA e intervenções estão documentadas; manual oficial auditado | Confirmação institucional da assinatura conjunta e atualização dos documentos históricos que ainda descrevem itens já entregues como inexistentes |
| Onda 1 - Fundação | Parcial avançada; staging comprovado | API e migrations implantadas em staging isolado; seed e smokes aprovados; **67 testes API** no snapshot local | Sheets real, restore ensaiado, automação CI/CD externa ativada e evidência operacional de observabilidade/rate limit |
| Onda 2 - Aprendizagem | Parcial avançada; código e recorte físico provados | Catálogo/cache, analytics, horas e Assessment Sync; **177/177 Flutter** no código atual; Home, curso remoto, retomada cross-device/offline e player HLS com 0,75x/2x/retomada no Xiaomi | Tutor IA real, conflito concorrente físico, legenda com fixture real e medição de latência |
| Onda 3 - Sala e evidência | Parcial avançada; check-in físico corrigido | Professor/monitor autenticados; Entrada, duplicidade segura e Saída provadas no Xiaomi; PostgreSQL final 1/1 check-in/checkout e 2 evidências; retomada segura offline coberta por testes sem persistir token | Reteste físico da perda/reconexão e reabertura do check-in no Xiaomi; Evidence/revisão completos, certificado público E2E, aluno/admin e negações fora do vínculo |
| Onda 4 - Mídia, creator e comercial | Implementação testada; aceite operacional parcial | Staging em `0014`; P1 de prefixo corrigido, 16/16 regressões de mídia, player HLS/0,75x/2x/retomada físicos, dois POSTs `201` confirmados no container e gates backend de RBAC/expiração/ledger | Legenda com novo fixture VTT, telemetria qualificada, grant revogado/expirado no app, direitos/canais e decisão jurídica/comercial |
| Onda 5 - QA / Release | Parcial; **não aceita** | SDK fixado, análise Dart limpa, 59 API, **177/177 Flutter** no código atual, cobertura crítica >=80%, upgrade `.dev`, offline/reconexão, branding e mídia físicos | Reteste/rebuild após Evidence offline; E2E certificado/Evidence, Sheets, TalkBack/tema/teclado físicos, performance, integrações externas e gates Play |

Conclusão: o estado atual é muito mais avançado que o retrato inicial, mas não
há base para declarar as quatro ondas encerradas nem para promover diretamente
à Play. O próximo marco é o aceite físico integrado contra staging, não uma
nova expansão de escopo.

## Evidência técnica consolidada

### Staging, migrations, seed e smokes

Comprovado em `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`:

- PostgreSQL e API de staging em containers, volume e rede separados de
  produção;
- imagem `tutor-tds-api:staging-0014-certificate-seed-20260920` em execução e registrada em
  `.deployed-image`;
- `alembic current` remoto comprovado em `20260920_0014 (head)`;
- `/health` externo com API `ok` e banco `available`;
- endpoints protegidos recusando acesso sem token;
- seed sintético aplicado com 23 registros na primeira execução e zero na
  segunda, demonstrando idempotência;
- credenciais sintéticas mantidas somente no host em arquivo modo `0600`;
- smoke público e smoke autenticado para administrador, professor, monitor e
  aluno;
- turma visível conforme o vínculo, tentativa de avaliação, mídia, painel de
  professor/monitor e sessão aberta do aluno;
- produção permaneceu saudável durante e após a implantação;
- logs Docker limitados por tamanho/quantidade no staging.
- smoke integral de mídia aprovou URL com prefixo público, resolução 307,
  tamper, telemetria/idempotência, rating, bloqueio, revogação, histórico e
  arquivamento do registro sintético.
- esse smoke de API não substitui o cliente: o primeiro artefato DEV descartava
  `/tutor-staging-api` em playback/rating e falhou honestamente. O rebuild
  corrigido foi instalado com `-r` e reproduziu o HLS no Xiaomi, com 0,75x, 2x
  e retomada após `force-stop`. Os logs internos do container confirmaram duas
  autorizações `POST /media/staging-qa-media/playback-authorizations` com `201`;
  o prefixo público é removido pelo Traefik antes do encaminhamento.
- smoke complementar aprovou RBAC negativo, rejeição de UPDATE/DELETE pelo
  trigger editorial, grant expirado com HTTP 401, Score v2 de 10.000, retry da
  mesma janela e janela sobreposta; terminou `archived`, sem grant ou ledger.
- smoke Evidence no PostgreSQL real aprovou entrada `201`, retry idempotente
  `200`, rotação de token `200`, saída `201`, retry `200` e relatório fechado
  com dois registros; conferência no banco encontrou `2:2` check-ins/evidências.
- aluno sintético elegível para certificado (`28804/28800` segundos e conclusão
  presente); carteira exige autenticação, isola titulares e não expõe CPF ou
  telefone. Emissão/verificação seguem bloqueadas sem gateway próprio de staging.
- no reteste físico de mídia, logs internos confirmaram dois `POST` de
  playback authorization com HTTP 201. O Traefik remove o prefixo antes do log
  da aplicação; nenhum header, token ou payload foi registrado/exposto.

Isso comprova implantação, migrations e contratos básicos no recorte observado.
Não comprova restauração de backup, carga, rede limitada, todas as jornadas
Android ou todos os critérios de negócio. A revalidação SSH foi somente leitura:
não acessou secrets/dados de usuário e não executou deploy, restart ou migration.

### Gates automatizados

- API: **67 testes aprovados** no snapshot local; repetir no SHA candidato.
- Flutter 3.44.9 / Dart 3.12.2: análise com `--fatal-infos` sem achados.
- Flutter: **177/177 testes aprovados** no snapshot atual, incluindo re-login,
  Assessment Sync, capacidades por vínculo, regressões responsivas e base path
  de playback/rating, persistência mínima/retry/reabertura segura do check-in
  sem token; recorte dirigido de mídia **16/16**.
- Cobertura: total **68,24%**; certificados **88,01%**, Study AI **83,43%** e
  sync/outbox **88,62%**, sem exclusões artificiais.
- Gates Android separam debug `.dev`/staging de release/produção e bloqueiam
  URLs vazias ou cruzadas.

Os números valem para o snapshot auditado. Devem ser repetidos no commit e no
artefato candidatos.

## Regras transversais da especificação visual

| Regra | Estado | Evidência e limite |
|---|---|---|
| Jornada antes de ferramentas | Parcial | Home possui retomada e próximas ações, mas o aceite da jornada completa por papel ainda depende do app físico |
| Zero tela morta | Implementado/testado em fluxos principais | Esperas pedagógicas e estados vazios existem; falta inventário físico completo com rede lenta e falhas reais |
| Papel muda a interface | Parcialmente provado no Android | Professor e monitor receberam capabilities distintas derivadas dos vínculos; falta aluno/admin e negações fora da turma |
| IA com fonte e ação | Implementado no cliente | O gateway de IA de staging continua externo/desligado, portanto falta E2E e medição de latência |
| Offline e baixa conectividade | Provado no recorte sintético | Avaliação foi alterada offline, preservada após `force-stop`, reconectada e consolidada como uma tentativa/estado estável no backend |
| Gestão por exceção | Provado no caso sintético | Monitor abriu o painel acionável da turma vinculada; volume e isolamento negativo ainda não foram provados fisicamente |
| Evidência antes de narrativa | Parcial avançada | A ordem transacional foi corrigida e o Xiaomi confirmou Entrada/Saída e proteção contra duplicação, correlacionadas com 2 check-ins/2 evidências no PostgreSQL. A retomada offline segura passou em testes automatizados com mesma chave idempotente, sem persistir token e exigindo novo código após reabertura; faltam reteste físico desse fluxo, revisão/relatório físico e política institucional de retenção |
| Drive como acervo, não CDN | Regra preservada | Player rejeita Drive; Shared Drive, responsáveis e retenção ainda são decisões externas |
| Privacidade e rastreabilidade | Parcial avançada | CPF protegido, telemetria tipada e auditoria backend; ainda faltam E2E de exclusão/Sheets e revisão final da Data Safety |

## Onda 1 - Fundação

### Implementado e validado

- PostgreSQL, Alembic, autenticação, refresh rotativo, RBAC e hierarquia
  instituição/programa/oferta/curso/turma/matrícula.
- CPF pseudonimizado no servidor e protegido no dispositivo; telemetria sem
  nome, telefone, CPF ou texto livre.
- LearningEvents e worker com idempotência, retry, pseudonimização e purge
  auditável.
- Staging isolado vivo, migrations, seed sintético e smokes por papel.
- Workflow de imagem imutável, health/smoke e rollback descrito no repositório.

### Gates ainda abertos

1. O Google Sheets de staging está **desligado por padrão** e continua externo.
   É necessário fornecer planilha, service account e segredo de pseudonimização
   exclusivos, então demonstrar evento, retry, deduplicação, purge e
   reconciliação dentro do SLA.
2. Ativar externamente branch/environment/secrets do GitHub para demonstrar o
   pipeline automático, inclusive rollback real. O código do workflow não é a
   prova da operação.
3. Executar backup e restauração em base vazia e registrar RPO/RTO.
4. Demonstrar rate limit e alertas no proxy/WAF/stack operacional.

Estado: **não fechada**.

## Onda 2 - Aprendizagem

### Implementado e validado

- Catálogo remoto, cache/fallback, retomada de cartilha, resumos, flashcards,
  quiz e simulado.
- Tutor contextual, controles de geração, TTS e espera pedagógica.
- Eventos de página/recurso/funcionalidade, atividade real e cálculo de horas.
- Assessment Sync com revisão CAS, retry idempotente, conflito 409 explícito,
  tentativa concluída imutável e estado 403 honesto. O payload não envia deck,
  perguntas, alternativas, gabarito ou explicações.
- Mídia remota e retomada existem no cliente; o smoke confirmou item publicado
  no catálogo de staging.

### Gates ainda abertos

1. Executar conflito concorrente entre dois clientes e uma tentativa concluída
   no dispositivo; o modo avião, autosave, morte/reabertura e reconexão do caso
   sintético já foram provados.
2. O gateway de IA de staging está **vazio/desligado**. Configurá-lo exige URL e
   credenciais externas; depois medir qualidade, fontes, erros e percentis.
3. O prefixo, player, 0,75x/2x e retomada já foram retestados no Xiaomi.
   Completar legenda com fixture que declare caption, fonte ampliada, landscape,
   rede limitada e telemetria qualificada no aparelho.

Estado: **não fechada**.

## Onda 3 - Sala, Evidence e certificados

### Implementado e validado

- Classroom por vínculo, professor/monitor e painel por exceção.
- Evidence Engine com sessão, QR/token rotativo e check-in do aluno validado no
  Xiaomi para Entrada, duplicidade segura e Saída,
  importação somente de metadados estruturados, conciliação/revisão, exceções,
  relatório e recuperação de sessão sem reexpor token.
- RBAC por turma/organização e testes de isolamento entre turmas.
- Certificado com elegibilidade, integridade SHA-256 no cliente, carteira local,
  PDF e ausência de CPF no artefato público.
- Seed e smoke de staging comprovaram turma por papel e sessão aberta.

### Gates ainda abertos

1. Completar no Xiaomi aluno/admin e negações de acesso fora da turma; professor
   e monitor já têm login, capabilities e dashboard provados.
2. Completar apenas o restante do Evidence físico: a correção implantada já foi
   retestada no Xiaomi com Entrada, duplicidade sem nova linha e Saída; o banco
   terminou em 1/1 e duas evidências. O smoke da API cobre retry com a mesma
   chave. Ainda faltam perda de rede/retomada e revisão/relatório do professor.
3. Homologar política institucional de importação, retenção e descarte de
   evidência bruta; o código não decide a governança.
4. Provisionar gateway/KV/segredo exclusivos de staging e então executar
   emissão, PDF local, compartilhamento e verificação pública. Elegibilidade,
   isolamento da carteira e ausência de CPF já foram comprovados.
5. Aprovar visualmente Classroom, Monitor, Evidence e certificado com TalkBack,
   fonte ampliada e contraste.

Estado: **não fechada**.

## Onda 4 - Mídia, creator, analytics e ledger

### Implementado e validado

- Ativo de mídia associado a instituição, programa, curso, módulo, competência
  e creator.
- Provider desacoplado no contrato. YouTube privacy-enhanced e HLS/Cloudflare
  são aceitos; Drive/Docs e hosts inseguros são rejeitados no playback.
- Catálogo/publicação são remotos e podem mudar sem novo APK.
- RBAC editorial restringe creator ao próprio escopo e mantém publicação com
  papel autorizado.
- Analytics de vídeo usam eventos fechados/idempotentes, checkpoints,
  conclusão qualificada, salvamento e atividade posterior.
- Creator Score e RevenueLedger existem com regra/versionamento, referências de
  origem, FKs, unicidade semântica e retry divergente rejeitado.
- A migration `0013` adiciona trilha editorial append-only com trigger/backfill,
  estados `blocked`/`archived`, rating 1-5 somente após conclusão qualificada,
  Creator Score v2 com visualização isolada igual a zero e grant opaco de
  playback por 300 segundos, armazenado somente por hash e revalidado por
  matrícula/vínculo/status.
- Ledger permanece `simulated`; adapter/pagamentos reais permanecem desligados.

### Gates ainda abertos

1. Demonstrar playback restrito com o provider institucional definitivo; o
   smoke usa YouTube sintético e ainda não homologa direitos/provedor de escala.
2. Definir Shared Drive/master, canal YouTube institucional, direitos de voz e
   imagem, legendas, retenção e provedor de escala.
3. Obter aprovação jurídica, tributária e comercial antes de qualquer payout.
   Nenhuma transação real está autorizada.

Estado: **não fechada**.

## Dispositivo físico e freeze

O APK final `.dev` `1.4.0-dev+13`, SHA-256
`5EF1AE32E3A07C1D5B0FFFE041DADCA8254F7817345C1A7B1CB02884D7F76D38`,
foi instalado e executado no Xiaomi após confirmação MIUI. O package Play
permaneceu preservado em `1.2.0+11`.

Há evidência física de upgrade `.dev` preservando estado, Home/curso de
staging, estudo offline com morte/reabertura/reconexão, player público,
Assessment Sync cross-device, logout/re-login, professor, monitor, dashboards e
branding corrigido em modo escuro. O P1 do check-in tokenizado foi corrigido e
retestado fisicamente: Entrada, duplicidade segura e Saída foram correlacionadas
com um `checkin`, um `checkout` e duas evidências no PostgreSQL. Não há evidência
física
suficiente de Evidence completo, certificado, acessibilidade, performance,
exclusão de conta ou upgrade via trilha Play. O freeze permanece aberto.

## Onda 5 - matriz de aceitação

Estados desta matriz: **Provado** exige evidência reproduzível já registrada;
**Parcial** indica cobertura incompleta ou indireta; **Bloqueado** depende de
serviço, credencial, decisão ou operação ainda indisponível. Nenhum item parcial
ou bloqueado conta como aceite.

| Critério normativo | Estado | Evidência exata e limite |
|---|---|---|
| `flutter analyze` sem erros | Parcial | `dart analyze --fatal-infos lib test` passou no SDK fixado; o wrapper `flutter analyze` teve falha LSP no caminho com espaços/parênteses e não há execução final equivalente registrada |
| `dart analyze` sem erros | Provado | `docs/testing/FLUTTER_TOOLCHAIN_QA_2026-09-20.md`: análise com Flutter 3.44.9/Dart 3.12.2, zero achados |
| Todos os testes Flutter | Provado no código; artefato pendente | Suíte atual **177/177**. O AAB de hash `B93FAD21CE8AE92AB464FCAFE8FB69E66C07C6E712DB0DBFCA0AE580B2844B66` antecede a mudança de Evidence offline, está **superseded/não uploadável** e não corresponde mais a este snapshot |
| Cobertura crítica >= 80% | Provado | Relatório do candidato: certificados 88,01%, Study AI 83,43% e sync/outbox 88,62%; total 68,24%, sem exclusões artificiais |
| Cadastro -> estudo -> conclusão -> certificado | Parcial | Cadastro, estudo, Assessment Sync e certificado têm testes separados; não há `integration_test` único nem certificado físico E2E |
| Offline -> reconexão | Provado no recorte sintético | `xiaomi-offline-assessment-pending.png`, `after-relaunch` e `resynced` provam alteração sem rede, morte/reabertura e uma tentativa canônica estável após reconexão |
| App -> banco -> Google Sheets | Bloqueado | Sheets de staging permanece desligado e sem planilha/service account homologadas |
| Sem CPF/credencial real em logs/respostas | Parcial | Dados físicos são sintéticos, CPF está protegido e scans não acharam segredo privilegiado; falta inspeção consolidada dos logs runtime do candidato |
| Scan de segredos | Provado | `docs/testing/FLUTTER_TOOLCHAIN_QA_2026-09-20.md`: padrões de alta confiança sem chave privada/token privilegiado em código rastreável; arquivos locais sensíveis estão ignorados |
| HTTPS em endpoints de produção | Parcial | Gates Android exigem URLs HTTPS produtivas exatas; esta auditoria não revalidou todos os endpoints externos nem TLS operacional do candidato |
| Startup <= 3 s em 3G | Bloqueado | Nenhuma medição 3G/percentil registrada |
| Tutor IA <= 10 s em 90% | Bloqueado | Gateway IA de staging desligado; comportamento indisponível é honesto, mas não mede latência/qualidade |
| AAB com chave aprovada | Bloqueado até rebuild | O AAB histórico, SHA-256 `B93FAD21CE8AE92AB464FCAFE8FB69E66C07C6E712DB0DBFCA0AE580B2844B66`, passou assinatura/certificado, bundletool e alinhamento 16 KB, mas está **superseded e não deve ser enviado** porque antecede Evidence offline. Retestar no Xiaomi e reconstruir antes de nova validação |
| Release notes finais | Parcial | Runbook existe, mas notas do artefato candidato ainda não foram aprovadas |
| Política de Privacidade HTTPS | Parcial | Configuração/gate existem; a URL final deve ser conferida no candidato e na Play |
| Segurança dos Dados coerente | Bloqueado | Exige revisão humana final contra integrações realmente habilitadas e formulário da Play Console |

### Cobertura visual contra especificação e mockups

A fotografia inicial do audit de mockups era anterior às implementações de
Monitor, Evidence, Assessment Sync e re-login; o documento foi atualizado para
remover essas contradições. As capturas físicas prevalecem para existência
funcional, mas não demonstram fidelidade visual completa.

| Superfície | Estado | Evidência e lacuna mínima |
|---|---|---|
| Home e jornada | Parcial | Home do aluno, capabilities de professor/monitor e branding corrigido foram provados; falta o papel admin e negações físicas fora do vínculo |
| Tutor IA / espera | Bloqueado | Estado indisponível é honesto; gateway desligado impede resposta, fonte, ação e performance reais |
| Quiz/simulado | Parcial | Cross-device 1/1, offline/morte/reconexão, `Sincronizado` e fonte 200%/landscape automatizados; falta conflito físico |
| Classroom professor | Parcial | `xiaomi-teacher-dashboard.png` prova a turma sintética; check-in do aluno foi retestado fisicamente após a correção. Ainda faltam revisão/relatório do professor, Evidence completo e TalkBack físico |
| Monitor por exceção | Parcial | `xiaomi-monitor-dashboard.png` prova painel acionável; falta isolamento negativo físico e estados com volume |
| Perfil/conta | Provado | Logout, `Entrar na conta online`, professor/monitor conectados e progresso local preservado; não equivale a validar exclusão de conta |
| Mídia | Parcial avançada | O rebuild corrigido reproduziu o HLS restrito; `xiaomi-media-speed-075.png` e `xiaomi-media-speed-2x.png` provam os extremos, o par `resume-before/after` prova retomada sem reinício e o container confirmou dois POSTs 201. O fixture tem `captions=[]`; faltam novo fixture VTT, telemetria qualificada, rede e grant expirado/revogado no app |
| Branding | Parcial aprovado | Manual oficial e fontes FAPTO/CDR foram auditados; `xiaomi-branding-partners-fixed.png` prova os quatro logos sem checkerboard no escuro. Resta confirmação institucional da ordem/assinatura |
| Acessibilidade/layout | Parcial avançada | Home, simulado, mídia, Classroom/Monitor, Evidence e certificados passam testes com semântica essencial, fonte 200%, telefone estreito e landscape sem overflow; faltam TalkBack, claro/escuro e teclado em dispositivo |

## Menor conjunto restante para freeze

Os itens abaixo consolidam múltiplos casos da matriz física para evitar testes
redundantes. Todos precisam usar o mesmo commit/configuração candidata.

1. **Assessment concorrente:** concluir uma tentativa e provocar conflito CAS
   controlado entre dois clientes. O caminho offline/morte/reconexão já está
   aprovado no recorte sintético.
2. **Evidence/check-in restante:** Entrada, duplicidade segura e Saída já
   passaram fisicamente; retry com a mesma chave, rotação e relatório passaram
   no smoke PostgreSQL. Completar somente retomada offline e revisão/relatório
   do professor. Cobre o restante de A15 e A17.
3. **Certificado E2E:** tornar aluno sintético elegível, emitir, baixar/abrir PDF,
   compartilhar e validar QR público sem login/CPF. Cobre A16 e o fluxo integrado
   exigido pela Onda 5.
4. **Controle de acesso físico mínimo:** aluno, admin, professor e monitor; uma
   tentativa negativa fora da turma e confirmação de que capability não vem de
   seletor local. Professor/monitor positivos já estão provados, então não é
   necessário repetir seus happy paths.
5. **Sweep visual/acessível compacto:** fonte 200%, telefone estreito e
   landscape já têm regressão automatizada em Home, simulado, mídia,
   Classroom/Monitor, Evidence e certificados. Completar em dispositivo apenas
   claro/escuro, TalkBack e teclado; anexar somente falhas/capturas
   representativas. O defeito de checkerboard dos logos já foi corrigido;
   preservar a ordem até confirmação institucional.
6. **Mídia restante:** prefixo, playback HLS, 0,75x/2x, retomada e POSTs 201 já
   passaram. Como o seed não atualiza o item publicado, criar um novo draft
   sintético com caption HTTPS VTT e publicar; então validar legenda, evento
   qualificado único e grant expirado/revogado no app. Cobre o restante de A18
   e o gate operacional da Onda 4.
7. **Privacidade e release:** exclusão de conta/dados (A21), scan/logs do
   candidato, startup 3G e, quando o gateway existir, amostra p90 do Tutor.
8. **Upgrade/release Play:** instalar a partir de `1.2.0+11` somente na trilha
   interna/fechada, validar preservação e revisar AAB, Data Safety, privacidade e
   release notes. Não executar esse caso por sideload sobre o package publicado.

Os testes 1 a 6 são o núcleo físico/visual mínimo. Os itens 7 e 8 são gates de
segurança/publicação e não podem ser omitidos apenas porque a UI passou.

## Branding e conformidade visual

O tema, os tokens TDS, a tipografia Poppins, as cores e os exports da marca foram
conferidos contra o manual oficial. Os ícones Android coincidem com os exports; a
faixa de parceiros foi corrigida com as fontes encontradas e aprovada fisicamente
no modo escuro, sem redesenho por IA.

Ainda pendem a confirmação institucional da ordem/assinatura conjunta, um vetor
IPEX se houver e o sweep final em tamanhos/temas acessíveis. Isso é um gate de
homologação, não mais um bloqueio por asset defeituoso.

## Intervenções externas objetivas

1. **Branding:** confirmar ordem, assinatura e papel institucional das marcas
   parceiras; fornecer vetor IPEX caso exista.
2. **Google Sheets:** fornecer planilha e service account exclusivas de staging;
   manter o profile desligado até a homologação.
3. **Gateway IA:** fornecer/autorizar endpoint e credenciais de staging; manter
   vazio/desligado enquanto isso.
4. **Certificados:** autorizar e validar gateway/verificação pública com dados
   sintéticos.
5. **Mídia:** definir Drive/canal, direitos, retenção e provedor de entrega.
6. **Comercial:** aprovar regra e termos; pagamentos continuam desativados.
7. **GitHub/operacional:** configurar environment/secrets do staging e autorizar
   ensaio de restore/rollback.
8. **Play Console:** confirmar chave de upload, Data Safety, política, notas e
   trilha interna/fechada antes do upgrade do package publicado.

## Ordem de encerramento recomendada

1. Confirmar institucionalmente a assinatura conjunta e congelar o candidato.
2. Executar os itens físicos ainda abertos 1 a 6 descritos na matriz Onda 5.
3. Homologar Sheets, gateway IA e certificado separadamente, sem usar produção
   como ambiente de teste.
4. Repetir no candidato os smokes de `0013`/`0014` e validar mídia
   restrita/editorial, mantendo pagamentos desligados.
5. Repetir 59 API, análise, 173 Flutter e preservar o relatório de cobertura.
6. Fechar privacidade/performance e executar upgrade somente na trilha
   interna/fechada da Play.
7. Revisar Data Safety, assinatura, notas e rollout antes de qualquer promoção.

## Decisão

**NO-GO para declarar as quatro ondas fechadas e NO-GO para promoção direta à
Play.**

**GO para continuar o QA físico em staging**, pois o APK `.dev` final já está
instalado e os recortes descritos foram provados. Esse GO não é aceite de freeze
nem autorização de AAB/Play: o núcleo mínimo, as integrações bloqueadas e as
intervenções humanas listadas acima continuam obrigatórios.
