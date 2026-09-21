# Tutor TDS - QA em dispositivo físico Android

Data do inventário: 2026-09-20

## Dispositivo disponível

| Item | Valor observado |
|---|---|
| Fabricante/modelo | Xiaomi 2311DRK48G (`duchamp_global`) |
| Android | 15 |
| API | 35 |
| ABI | `arm64-v8a` |
| Patch de segurança | 2025-11-01 |
| Tela física | 1220 x 2712, densidade 480 |
| Override ativo | 1080 x 1920, densidade 420 |
| Estado ADB | `device` |
| Espaço em `/data` | 344 GB livres de 465 GB |
| Bateria na coleta | 61%, carregando |

O serial completo não é registrado neste documento. Use `adb devices -l` no momento da execução.

## Aplicativos Tutor TDS encontrados

| Pacote | Versão | Tipo observado | Decisão |
|---|---|---|---|
| `com.tutortds_cartilhas` | 1.2.0 (11), min SDK 32, target 36 | Produção/Play | Não substituir durante desenvolvimento |
| `com.tutortds_cartilhas.dev` | 1.4.0-dev (13), min SDK 24, target 36 | Debug lado a lado | Build atual de QA em staging |
| `br.org.ipex.cartilhas_app` | 1.1.0 (2), debug | Legado | Não remover sem decisão sobre dados legados |

Em 20/09/2026 foi gerado e depois atualizado um APK debug fresco, apontando
somente para o staging isolado. Metadados do artefato atual da rodada:

- package: `com.tutortds_cartilhas.dev`;
- versão: `1.4.0-dev+13` (`versionCode` 13);
- SHA-256:
  `EDCADDB4D6021650A13EA0A591162B10431749741DCEC3D230C41ECE8E21BF96`;
- assinatura APK validada e health do staging aprovado antes da tentativa.

Após a instalação/execução da build atualizada, o package Play permaneceu
preservado em `1.2.0+11`; nenhum update, limpeza ou remoção foi direcionado a
`com.tutortds_cartilhas`.

O artefato acima é o rebuild que corrige a preservação do prefixo da API nas
rotas de playback/rating. Foi validado como package `.dev`, assinatura v2 e
instalado com `adb install -r`, preservando sessão/dados. Ao final, o package
Play continuava em `1.2.0+11`.

O DEV 1.2.0 antigo usava assinatura incompatível e foi removido exclusivamente
do package `.dev`. A reinstalação do novo APK foi recusada pelo MIUI com
`INSTALL_FAILED_USER_RESTRICTED`, exigindo confirmação humana de “Instalar via
USB”. Após a tentativa, o package DEV estava ausente e o package Play permanecia
inalterado em 1.2.0 (11). Nenhum dado ou binário do app publicado foi removido.

Atualização posterior no mesmo dia: após a confirmação humana no MIUI, o APK
`.dev` foi executado contra o staging e foram capturadas as evidências descritas
abaixo. Essa execução comprova abertura do build de QA, mas não comprova upgrade
com preservação de dados nem autoriza qualquer ação sobre o package Play.

## Comando de inventário reproduzível

Na raiz do projeto:

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\android_readonly_inventory.ps1
```

Com mais de um dispositivo:

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\android_readonly_inventory.ps1 -Serial <serial-retornado-pelo-adb>
```

O script executa apenas consultas ADB. Não instala, remove, limpa dados, altera rede nem inicia o aplicativo.

## Pré-condições para instalar a próxima build

- Branch/fatia congelada e commit identificado.
- Testes unitários e análise estática verdes.
- APK debug assinado pela chave debug, com `applicationIdSuffix=.dev`.
- `TUTOR_API_URL` apontando exclusivamente para staging HTTPS.
- Conta e dados de teste sintéticos; nenhum CPF real.
- Feature flags perigosas ou comerciais desligadas.
- Backup/exportação de qualquer estado de QA que precise ser preservado.
- Hash SHA-256 e metadados da build registrados.

Instalação preservando dados do pacote `.dev`, quando a assinatura coincide:

```powershell
adb -s <serial> install -r .\cartilhas_app\build\app\outputs\flutter-apk\app-debug.apk
```

Antes de executar, confirme com `aapt dump badging` ou `apkanalyzer manifest application-id` que o pacote é `com.tutortds_cartilhas.dev`. Nunca use `adb uninstall`, `pm clear` ou `install -r` contra `com.tutortds_cartilhas` durante o QA de desenvolvimento.

Se o MIUI solicitar “Instalar via USB”, mantenha o aparelho desbloqueado e
aprove a confirmação visível. Não tente contornar a proteção por ADB. Se houver
erro de assinatura em um package `.dev` antigo, registre a versão e remova
somente `com.tutortds_cartilhas.dev`; a versão Play não deve ser usada como alvo.

## Execução física observada em 20/09/2026

Esta atualização consolida as capturas armazenadas em
`docs/testing/evidence/2026-09-20` e as anotações da execução. A jornada
offline descrita abaixo foi executada por ADB somente no package `.dev`; o
package Play não foi instalado, limpo, removido nem usado como alvo de
`force-stop`.

| Caso relacionado | Resultado observado | Classificação e limite |
|---|---|---|
| A01 - APK `.dev` | O upgrade `1.3.0-dev+12` -> `1.4.0-dev+13` foi instalado com `-r`, abriu apontando para staging e preservou sessão/progresso; o package Play permaneceu `1.2.0+11` | **Aprovado para upgrade side-by-side de QA:** não equivale ao upgrade pela trilha interna da Play |
| A03 - logout | O app exigiu confirmação explícita, removeu a sessão e as filas autenticadas e retornou ao Welcome | **Aprovado para logout:** tokens/filas da conta não permaneceram ativos; login, refresh e troca completa entre contas continuam casos separados |
| A03 - re-login | Configurações ofereceu `Entrar na conta online`; login seguro foi concluído com professor e monitor, a sessão conectada foi exibida e o progresso local permaneceu no aparelho | **Aprovado fisicamente:** o antigo bloqueio de UX foi corrigido; credenciais não foram registradas nas evidências |
| A04 - conteúdo remoto | A Home exibiu `Curso Sintético QA [STAGING]` fornecido pelo ambiente remoto | **Aprovado para descoberta de conteúdo de staging:** ainda falta medir atualização/publicação repetida sem novo APK |
| A05 - cache/fallback | Com Wi-Fi e dados móveis desabilitados, Home, curso e simulado sintético continuaram disponíveis; a resposta 1/1 foi mantida | **Aprovado no recorte sintético:** cache e continuação da avaliação foram observados; não equivale a validar todos os recursos offline |
| A06 - estudo offline e morte do processo | O aluno removeu a marcação de revisão sem rede; o app mostrou `Aguardando sincronização`, o package `.dev` sofreu `force-stop` e, ao reabrir ainda offline, preservou resposta, progresso e fila | **Aprovado para a tentativa sintética:** morte/reabertura e persistência local foram comprovadas sem tocar no package Play |
| A07 - reconexão e idempotência | Após reativar Wi-Fi/dados, a mesma tentativa voltou a `Sincronizado`; o backend expôs uma única tentativa, uma resposta, marcação final removida e revisão 39 estável em duas leituras separadas por 6 s | **Aprovado para Assessment Sync/CAS:** não houve duplicação de tentativa/estado; deduplicação de `LearningEvent.event_id` permanece um caso distinto |
| A09 - Tutor IA | O recurso permaneceu indisponível e comunicou a indisponibilidade sem fingir resposta | **Comportamento honesto aprovado; integração pendente:** gateway IA de staging está desligado, portanto contexto, fontes e latência não foram aceitos |
| A11 - Assessment Sync entre dispositivos | A build encontrou uma tentativa remota com 1/1 resposta, retomou sem nova IA, hidratou deck/resposta e depois preservou uma alteração durante offline, morte/reabertura e reconexão | **Aprovado para recuperação cross-device e offline/reconexão do caso sintético:** ainda faltam conflito concorrente e tentativa concluída em dispositivo |
| A13 - capacidades por papel | Professor recebeu `Área da equipe` e `Registrar presença`; monitor recebeu saudação própria, `Monitor por exceção` e `Registrar presença` | **Aprovado para professor e monitor sintéticos:** capabilities vieram dos vínculos de staging; aluno/admin e negações cruzadas ainda pertencem à matriz completa |
| A14 - dashboards por vínculo | Professor abriu o acompanhamento da `Turma Sintética QA [STAGING]`; monitor abriu o painel acionável por exceção da mesma turma | **Aprovado para os cenários sintéticos observados:** ainda faltam volume, outra turma e tentativa explícita de acesso fora do vínculo |
| A15 - check-in/QR | Após corrigir a ordem transacional somente no staging, a `Entrada` e a `Saída` foram confirmadas no Xiaomi. Uma repetição física da `Entrada`, com nova chave gerada pela UI, foi recusada como duplicada e não criou outra linha | **Aprovado para sucesso e proteção contra duplicação:** PostgreSQL final com um `checkin`, um `checkout`, duas evidências `attendance` distintas. Retry com a mesma chave passou no smoke da API; expiração foi observada no ensaio anterior. O subcaso offline permanece pendente |
| A18 - mídia | O rebuild corrigido foi instalado com `-r`; o item `external_hls` recebeu grant e exibiu quadro/posição. Os menus nativos confirmaram seleção de `0.75` e `2`, e o vídeo reabriu em posição não zero após `force-stop`/relaunch. O container de staging confirmou duas autorizações físicas `201` | **Parcial aprovado:** P1 de rota encerrado no cliente físico. O fixture tem `captions=[]`, portanto legenda não pôde ser exercitada. Não foram concluídos offline/rede, telemetria qualificada nem expiração/revogação do grant |
| A12/A23 - visual/branding | A build `1.4.0-dev+13` exibiu IPEX/UFT/FAPTO/CDR em cards brancos no modo escuro, sem o quadriculado anterior | **Aprovado no recorte físico:** marca TDS e assets seguem o manual; resta confirmar institucionalmente a ordem/assinatura conjunta |

### Evidências armazenadas

| Arquivo | O que comprova |
|---|---|
| [`xiaomi-home-staging.png`](evidence/2026-09-20/xiaomi-home-staging.png) | Home conectada ao staging, curso sintético e defeito checkerboard nos logos |
| [`xiaomi-media-staging.png`](evidence/2026-09-20/xiaomi-media-staging.png) | Item de mídia de staging carregado no player com metadados/contexto |
| [`xiaomi-media-playing.png`](evidence/2026-09-20/xiaomi-media-playing.png) | Estado do player durante a sequência de reprodução |
| [`xiaomi-media-after-play-action.png`](evidence/2026-09-20/xiaomi-media-after-play-action.png) | Quadro do stream após ação explícita do usuário |
| [`xiaomi-media-playback-prefix-blocked.png`](evidence/2026-09-20/xiaomi-media-playback-prefix-blocked.png) | Regressão da build instalada no item restrito: catálogo/contexto carregados, mas autorização de playback caiu em 404 antes do stream; a captura não comprova os chips de legenda/velocidade |
| [`xiaomi-media-playback-fixed.png`](evidence/2026-09-20/xiaomi-media-playback-fixed.png) | Rebuild corrigido reproduzindo o stream HLS de staging, com quadro e posição visíveis |
| [`xiaomi-media-speed-075.png`](evidence/2026-09-20/xiaomi-media-speed-075.png) | Menu nativo do player com `0.75` selecionado |
| [`xiaomi-media-speed-2x.png`](evidence/2026-09-20/xiaomi-media-speed-2x.png) | Menu nativo em tela cheia com `2` selecionado |
| [`xiaomi-media-resume-before.png`](evidence/2026-09-20/xiaomi-media-resume-before.png) | Posição antes do fechamento forçado somente do DEV |
| [`xiaomi-media-resume-after.png`](evidence/2026-09-20/xiaomi-media-resume-after.png) | Reabertura do mesmo item em posição não zero, sem reinício |
| [`xiaomi-home-offline-cache.png`](evidence/2026-09-20/xiaomi-home-offline-cache.png) | Home em modo avião preservando curso e retomada em cache |
| [`xiaomi-assessment-cross-device.png`](evidence/2026-09-20/xiaomi-assessment-cross-device.png) | Tentativa remota localizada, com progresso 1/1 e retomada sem nova IA |
| [`xiaomi-assessment-cross-device-resumed.png`](evidence/2026-09-20/xiaomi-assessment-cross-device-resumed.png) | Deck e resposta hidratados no simulado, com estado `Sincronizado` |
| [`xiaomi-offline-baseline-online.png`](evidence/2026-09-20/xiaomi-offline-baseline-online.png) | Baseline online da tentativa sintética antes do corte de rede |
| [`xiaomi-offline-assessment-pending.png`](evidence/2026-09-20/xiaomi-offline-assessment-pending.png) | Alteração local sem rede, resposta preservada e estado `Aguardando sincronização` |
| [`xiaomi-offline-assessment-after-relaunch.png`](evidence/2026-09-20/xiaomi-offline-assessment-after-relaunch.png) | Mesma resposta/estado local após `force-stop` e reabertura ainda offline |
| [`xiaomi-offline-assessment-resynced.png`](evidence/2026-09-20/xiaomi-offline-assessment-resynced.png) | Reconexão concluída com estado `Sincronizado` e marcação final removida |
| [`xiaomi-logout-complete.png`](evidence/2026-09-20/xiaomi-logout-complete.png) | Retorno ao Welcome após confirmação e conclusão do logout |
| [`xiaomi-relogin-teacher-settings.png`](evidence/2026-09-20/xiaomi-relogin-teacher-settings.png) | Sessão online do professor conectada, com progresso local preservado |
| [`xiaomi-teacher-capabilities.png`](evidence/2026-09-20/xiaomi-teacher-capabilities.png) | Menu do professor com `Área da equipe` e `Registrar presença` |
| [`xiaomi-teacher-dashboard.png`](evidence/2026-09-20/xiaomi-teacher-dashboard.png) | Dashboard da turma sintética acessível ao professor |
| [`xiaomi-relogin-monitor-settings.png`](evidence/2026-09-20/xiaomi-relogin-monitor-settings.png) | Sessão online do monitor conectada, com progresso local preservado |
| [`xiaomi-monitor-capabilities.png`](evidence/2026-09-20/xiaomi-monitor-capabilities.png) | Home `Olá, Monitor` e menu com capacidades de monitoria/presença |
| [`xiaomi-monitor-dashboard.png`](evidence/2026-09-20/xiaomi-monitor-dashboard.png) | Painel acionável do Monitor por exceção para a turma sintética |
| [`xiaomi-branding-partners-fixed.png`](evidence/2026-09-20/xiaomi-branding-partners-fixed.png) | Build `1.4.0-dev+13` em modo escuro, com os quatro logos parceiros corrigidos e legíveis |
| [`xiaomi-checkin-duplicate-safe.png`](evidence/2026-09-20/xiaomi-checkin-duplicate-safe.png) | Falha anterior à correção: campo limpo e mensagem honesta de não sincronização; preservada como evidência do P1 detectado |
| [`xiaomi-checkin-entry-success.png`](evidence/2026-09-20/xiaomi-checkin-entry-success.png) | `Entrada confirmada` no Xiaomi após o deploy corrigido, com o campo já limpo |
| [`xiaomi-checkin-entry-duplicate-safe-after-fix.png`](evidence/2026-09-20/xiaomi-checkin-entry-duplicate-safe-after-fix.png) | Repetição física recusada sem nova persistência; campo limpo e confirmação anterior ainda visível |

As capturas não contêm nem devem receber token de check-in, senha, CPF ou
credenciais do staging. As capturas da UI foram correlacionadas com contagens
somente leitura no PostgreSQL; nenhuma delas é usada isoladamente para atribuir
sucesso ou falha.

### Rodada compacta de certificado e mídia restrita

O aluno sintético de staging foi preparado pelo backend com 28.804 segundos
validados para 28.800 planejados, conclusão registrada e matrícula/turma ativas.
Mesmo assim, a carteira permanecia vazia (`certificates=0`). A emissão e a
verificação pública não foram tentadas no Xiaomi porque o DEV mantinha
`TUTOR_GATEWAY_URL` vazio e o staging mantinha o prefixo de verificação vazio:
não existe ainda emissor, KV ou segredo exclusivos de staging. O smoke da API
comprovou fail-closed 503, autenticação/isolamento da carteira e ausência de
CPF/telefone. Isso é bloqueio externo honesto, não aprova emissão, detalhe,
PDF, compartilhamento, QR ou verificação pública.

Como o certificado não estava pronto, a rodada seguiu para a mídia restrita.
O catálogo remoto abriu online e exibiu o item sintético, a associação a
curso/módulo/competência, o creator e o aviso de acesso protegido. Ao abrir o
player, a UI apresentou de forma honesta a indisponibilidade e a ação `Tentar
novamente`. A captura `xiaomi-media-playback-prefix-blocked.png` foi preservada
sem PII.

A correlação entre tela, logs e fonte confirmou a causa no artefato anterior:
o catálogo concatenava o caminho e chegou a `GET /tutor-staging-api/media`, mas
playback/rating usavam `Uri.resolve('/media/...')`; a barra inicial removia o
prefixo `/tutor-staging-api`. Por isso a API de staging não recebeu o `POST` de
autorização.

O rebuild SHA-256 `EDCADDB4D6021650A13EA0A591162B10431749741DCEC3D230C41ECE8E21BF96`
foi então instalado como upgrade do package `.dev`. O catálogo abriu, o grant
foi resolvido e o HLS exibiu quadro e posição. Em seguida foram selecionadas e
capturadas as velocidades `0.75` e `2` no menu nativo. Após `force-stop` e
relaunch somente do DEV, o mesmo vídeo retomou em posição não zero, sem
reiniciar. O fixture de staging declara `captions=[]`; por isso a legenda não
foi marcada como aprovada nem como defeito. Por ordem de encerramento, não foi
feita nova rodada offline.

Uma verificação posterior somente leitura dos logs do container de staging
confirmou duas chamadas físicas a
`POST /media/staging-qa-media/playback-authorizations`, ambas `201 Created`, sem
expor header, token ou payload. O Traefik remove `/tutor-staging-api` antes de
encaminhar ao container; portanto o log interno não repete o prefixo, mas essas
chamadas chegaram pela rota pública prefixada usada pelo APK DEV. Não havia
access log do Traefik habilitado para uma segunda correlação.

### Inventário read-only para os próximos gates

Na consulta posterior, `adb devices -l` não listou o Xiaomi. Assim, o estado
atual do TalkBack não pôde ser inventariado sem inventar evidência: instalação,
serviço disponível e estado de acessibilidade permanecem **desconhecidos**. Nada
foi habilitado ou alterado. O último estado confirmado antes da desconexão era
Wi-Fi e dados móveis ligados, DEV `1.4.0-dev+13` em `force-stop` e Play
`1.2.0+11` preservado; ele deve ser reconfirmado quando o ADB voltar a `device`.

O fixture atual não pode ganhar legenda apenas reaplicando o seed: `_ensure`
preserva o registro existente e a mídia já está `published`, enquanto o endpoint
de patch aceita edição somente em `draft`. O caminho seguro para o próximo gate
é criar, via API editorial/admin de staging, **um novo rascunho sintético** com
caption HTTPS WebVTT (`format=vtt`, idioma e referência), publicá-lo e então
testar no DEV. O contrato atual aceita até 20 captions VTT e o player HLS injeta
somente trilhas WebVTT; SRT não deve ser usado nesse fixture.

### Jornada offline, morte/reabertura e reconexão

Execução em 20/09/2026, somente com aluno/curso/tentativa sintéticos de
staging e o package `com.tutortds_cartilhas.dev`:

1. a tentativa remota foi retomada com 1/1 resposta e estado sincronizado;
2. uma marcação de revisão foi sincronizada online e usada como baseline;
3. Wi-Fi e dados móveis foram desabilitados por ADB;
4. a marcação foi removida offline e a UI exibiu
   `Aguardando sincronização`;
5. apenas o package `.dev` sofreu `force-stop`; a reabertura, ainda sem rede,
   preservou resposta, progresso e alteração pendente;
6. Wi-Fi e dados móveis foram reativados e a UI retornou a `Sincronizado`;
7. a API do staging retornou uma única tentativa canônica, uma resposta,
   `marked_count=0` e revisão 39; uma segunda leitura 6 s depois retornou a
   mesma revisão e o total continuou igual a um.

O cronômetro do simulado produz revisões legítimas enquanto a tela permanece
ativa; por isso o número absoluto da revisão não é tratado como contagem de
toques. A prova de não duplicação deste recorte é a existência de uma única
tentativa/estado final estável, não uma alegação de exatamente um `PUT` de rede.
Nenhum check-in foi executado nesta jornada.

### Check-in detectado, corrigido e retestado no staging

Na build `1.4.0-dev+13`, a conta sintética de aluno manteve acesso a
`Registrar presença`. A hierarchy da UI confirmou campo de código vazio, opções
`Entrada`/`Saída` e a ação `Confirmar entrada`. Antes de preencher o campo, uma
consulta autenticada e sanitizada ao staging inicialmente confirmou:

- sessão `open` e ID sintético esperado;
- `token_version=5`;
- token expirado havia aproximadamente 147 minutos no momento da leitura.

Essa primeira tentativa foi corretamente interrompida. Depois da reaplicação
idempotente do seed, a sessão permaneceu `open`, passou a `token_version=6` e o
token tinha aproximadamente 479 minutos de validade futura. O token foi lido do
arquivo remoto `0600` somente em memória; não foi impresso, salvo em evidência
ou mantido no campo. A hierarchy confirmou que o código completo esperado foi
inserido antes de cada envio.

Tanto `Entrada` quanto `Saída` retornaram `Não sincronizado` / `Registro
duplicado ou divergente.`. A verificação somente leitura no PostgreSQL mostrou
zero linhas em `class_checkins` e zero evidências `attendance` para a sessão e o
aluno sintéticos. Os logs do banco explicam o 409: em ambas as tentativas, o
`INSERT` de `class_checkins` ocorreu antes do `INSERT` da evidência referenciada,
violando `class_checkins_evidence_id_fkey`. A transação foi revertida; portanto a
mensagem de duplicidade não representava um registro anterior.

O backend foi corrigido e implantado **somente no staging** na imagem
`tutor-tds-api:staging-0014-evidence-fk-20260920`. O reteste físico com o mesmo
aluno/sessão sintéticos e token ainda válido produziu:

1. `Entrada confirmada` na UI e uma linha `checkin`/uma evidência no banco;
2. repetição da `Entrada` recusada como `Registro duplicado ou divergente.`,
   mantendo exatamente uma linha/uma evidência;
3. `Saída confirmada` na UI;
4. estado final no PostgreSQL: um `checkin`, um `checkout`, duas evidências
   `attendance` e dois `evidence_id` distintos.

O cliente gera uma nova chave após sucesso; por isso a repetição física exercita
a restrição semântica de duplicidade. O retry com a **mesma** chave, que deve
retornar 200, foi validado no smoke PostgreSQL da API (Entrada e Saída), não
inferido pelo app. O token foi conferido integralmente em memória antes de cada
envio e removido do campo antes das capturas. O subcaso offline foi adiado para
evitar prolongar a manipulação do segredo depois de fechar o gate principal.

Ao encerrar, Wi-Fi e dados móveis estavam ativados, o package `.dev` estava em
`force-stop` e o package Play permanecia `1.2.0+11` sem qualquer ação.

### P1 encerrado - reconexão de conta após logout

O defeito anterior era de UX: após logout, Configurações informava `Sem conta
online conectada`, mas não oferecia uma ação de re-login. A correção adicionou
`Entrar na conta online` sem apagar o perfil/progresso local.

Na build final, o fluxo foi aprovado fisicamente com as contas sintéticas de
professor e monitor: login seguro, sessão conectada, capacidades derivadas dos
vínculos e progresso local preservado. A correção também está coberta pela suíte
automatizada final, com **177/177 testes aprovados**. O P1 de re-login está
encerrado; o P1 independente de persistência do check-in também foi corrigido e
retestado conforme a seção anterior.

### Branding corrigido

O manual oficial TDS e os vetores de FAPTO/CDR foram localizados. Os assets
defeituosos foram substituídos sem redesenho: vetores rasterizados de forma
determinística, IPEX preservado a partir do JPG limpo e cards brancos para
contraste. A captura física no modo escuro fechou o defeito do quadriculado. A
ordem e o papel institucional dos parceiros ainda exigem confirmação humana.

## Matriz física obrigatória no freeze

| ID | Cenário | Evidência esperada | Onda |
|---|---|---|---|
| A01 | Instalação/upgrade `.dev` preservando estado | Versão, hash, screenshot e dados preservados | 5 |
| A02 | Primeiro acesso sem conta e consentimento | Fluxo acessível, sem evento antes de consentir | 1/5 |
| A03 | Registro/login/refresh/logout em staging | 200/201, 401 tratado, tokens seguros e logs sem PII | 1 |
| A04 | Curso novo publicado sem novo APK | Curso aparece em até 30 segundos | 2 |
| A05 | Cache e fallback | App abre curso com API indisponível | 2 |
| A06 | Estudo offline e reabertura após matar processo | Posição, respostas e fila preservadas | 2 |
| A07 | Reconexão e idempotência | Cada `event_id` confirmado uma vez | 1/2 |
| A08 | Atividade real | Tela parada não soma tempo; interação soma dentro dos limites | 2 |
| A09 | Tutor IA contextual | Contexto, fontes, ações, TTS e limite de 10 s medido em amostra | 2 |
| A10 | Microfone sob demanda | Permissão aparece apenas depois do toque; negação é recuperável | 2/5 |
| A11 | Quiz/resumo/cartões/simulado | Geração, espera, autosave, retomada e feedback | 2 |
| A12 | Tema, fonte e escala | Claro/escuro, fonte grande, landscape e teclado sem overflow | 2/5 |
| A13 | Home por papel | Aluno, professor, monitor e admin recebem atalhos/escopos corretos | 3 |
| A14 | Turma e painel por exceção | Lista, alertas e escopo não vazam outra turma | 3 |
| A15 | Sessão/check-in/QR | Expiração, offline, duplicidade e confirmação humana | 3 |
| A16 | Certificado | Emissão, PDF, compartilhamento, QR público e ausência de CPF | 3 |
| A17 | Evidence Engine | Importação efêmera, conciliação e revisão humana | 3 |
| A18 | Vídeo | Legenda, velocidade, retomada, provider, próxima ação e telemetria | 4 |
| A19 | Creator editorial | Creator edita rascunho próprio; apenas papel autorizado publica | 4 |
| A20 | Ledger sem pagamento | Evento idempotente gera um lançamento auditável; payout permanece desligado | 4 |
| A21 | Exclusão de conta/dados | Confirmação, revogação e comportamento offline seguros | 5 |
| A22 | Performance em rede limitada | Startup 3G <= 3 s e percentis de API/IA registrados | 5 |
| A23 | Acessibilidade | TalkBack, ordem de foco, labels, contraste e reduzir movimento | 5 |
| A24 | Upgrade a partir da Play 1.2.0 | Executar apenas em trilha interna/fechada; dados existentes preservados | 5 |

## Evidências por execução

Para cada caso registrar build/commit, dispositivo/API, ambiente, conta sintética, data/hora, resultado, screenshots/gravação, event IDs/correlation IDs sem PII e defeito associado.

Capturas e logs devem evitar notificações, telefone, CPF, tokens e outros dados pessoais do dispositivo.
