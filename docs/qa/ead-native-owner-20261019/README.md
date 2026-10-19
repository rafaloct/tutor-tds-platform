# Homologação nativa LearnPress e checkpoint Android — 19/10/2026

## Resultado e proveniência

**Release ainda BLOCKED.** PR #296 continua draft, HEAD
`0b06e81ff3ed2ea2061384b22e645d81c783ddc7`; fonte funcional
`c853db021368f4b536521800ed9dc33ef68e3aac`. Esta fatia usa a worktree exclusiva
`tds-issue297-learnpress-http-save-20261019`. Não modifica runtime PHP, Flutter,
FastAPI, capabilities de produção nem vendor/core. Nenhum merge/deploy/AAB novo.

DECISION: WordPress/LearnPress é autoridade editorial e da matrícula/progresso
EAD, conforme #249 e nova autorização de 19/10. FastAPI conserva identidades e
vínculos institucionais, frequência, evidências e certificados oficiais.
Identidades distintas e matrícula EAD não são sincronizadas por inferência.
O instrutor formalmente responsável deve possuir curso e aulas compatíveis;
aulas compartilhadas exigem inspeção de **todos** os cursos pais. Não há
autorização para reatribuição de cursos reais ou bypass de capabilities.

## Matriz executada

WordPress 6.7.2 / LearnPress 4.3.6 / PHP 8.2, MySQL sintético no VPS existente.
Cada execução usou banco, usuário DB e container descartáveis, rede interna,
sem porta publicada, senhas efêmeras e cookies reais. Usuários do clone:
`qa-admin`, `qa-prof-a`, `qa-prof-b`, `qa-editor`, `qa-aluno`, domínio `.test`.
O papel professor reproduz as 14 capacidades de #280, sem `edit_others_*`.

| Gate | Estado | Evidência |
| --- | --- | --- |
| professor proprietário do curso 12 e aula 13 | PASS parcial | POST 302; título, autoria e metadados persistem; pai enumerado, autor 4 |
| capacidade nativa | PASS | `edit_lp_course` e `edit_lp_lesson` verdadeiros; `edit_others_lp_courses/lessons` falsos |
| publicação contínua após fluxo do professor | FAIL | nas duas fixtures ampliadas o curso foi observado `pending`; REST retornou 404 `course_not_published` |
| professor em aula alheia / editor / aluno | PASS ACL, FAIL HTTP | sem formulário; HTTP 500; visitante 302 para login |
| administrador, formulário real | PASS | POST 302, persistência, mesmos arquivos do candidato |
| YouTube: dois saves / nonce editorial inválido | PASS | direitos 0→1; nonce inválido não altera mídia/direitos |
| MP4/VTT pelo administrador | PASS | três POSTs 302, direitos 0→1→0, projeção somente quando aprovada |
| REST / ETag | PASS admin | 200/304; nova fonte invalida ETag |
| nonce WordPress inválido | PASS | HTTP403 e título inalterado |
| rascunho | PASS admin | POST302, status draft persistido, REST público404 |
| efeitos acadêmicos editoriais | PASS | zero linhas `learnpress_user_items` após a sequência editorial |
| aluno existente, matrícula gratuita nativa | PASS | HTTP200/success; readback: uma linha `lp_course/enrolled/in-progress` |
| matrícula duplicada | PASS | HTTP200/error `already enrolled`; continua uma linha |
| sessão ausente com nonce anterior | PASS | HTTP403 |
| logout nativo | PASS | link da sessão, HTTP302; `users/me` após logout403 |
| GET da aula após redirect | PASS transporte / UNKNOWN autorização de conteúdo | visitante e aluno200; não basta para provar restrição |
| cadastro público novo | BLOCKED | `users_can_register=0`, register GET302; política preservada, `qa-novato` não criado |
| formulário institucional `/cadastro/` | UNKNOWN | sandbox tem Twenty Twenty-Five, não o tema institucional |
| múltiplos pais / M2 / upgrade LearnPress | UNKNOWN nesta execução | não repetir falha histórica nem inferir delegação; não houve upgrade |
| portal público | preservado no escopo | somente GETs anônimos; nenhum login, cadastro, POST ou instalação produtiva |

O primeiro ensaio M1 menor também comprovou REST200/304, mas não fechou
preservação do banco-base. Nas fixtures ampliadas, a observação de `pending`
foi feita após o save; não há snapshot de status imediatamente anterior que
permita atribuir causalidade exclusiva ao POST. A fronteira a investigar é o
ciclo nativo de revisão/publicação e a preparação da fixture. Não foi concedida
`publish_lp_courses` ao professor para fabricar PASS. Duas ocorrências do mesmo
404 encerraram esse caminho. O teste administrativo é uma frente independente.

Contagens: contrato PHP **63/63 PASS**, lint PASS (warnings preexistentes de
extensões no PHP local). Runner administrativo: **17 checkpoints PASS**, mais
quatro verificações de teardown; a semântica HTTP negativa permanece FAIL
separadamente. Matrícula: 4 checkpoints de preparação e seis observações
funcionais verificadas (GET visitante/aluno, formulário, primeira matrícula,
duplicata/readback, sessão ausente). Execução complementar confirmou redirect
interno da aula, GET200 de aluno/visitante, logout302 e pós-logout403. Não constitui
suíte completa de cadastro, proteção do conteúdo ou quiz. Os 68 stubs da
tentativa descartada não são usados.

O primeiro ensaio administrativo recebeu nonce de outra sessão e falhou;
o runner corrigiu **somente a obtenção do formulário com a sessão do admin**.
Nenhuma correção de autorização foi reinstalada. Scripts versionados são
receitas de QA específicas deste sandbox, não deploys ou ferramentas produtivas.

## Evidências remotas e preservação

Raiz: `/opt/tds-learning-qa-20261017/backups/`.

| Execução / arquivo `run.log` | SHA-256 |
| --- | --- |
| `20261019T205432Z-native-owner-297` — M1 inicial, 9 checkpoints e falha de hash-base | `fefa6551dd897e88daf35da517ee68142b88945dd7aba56abf64cbfe3b1eb5fe` |
| `20261019T205641Z-native-owner-297` — ampliado, REST404 | `5482f215e7bce3890ad2fd7b338f893059bc3dd9d37cbff80059a57c38861d6a` |
| `20261019T205841Z-native-owner-297` — status pending confirmado, STOP | `41cc28c53b3dcaf9c2fb5194a3123abaca3f89731c9fb7b6e762c3ed44fa00c2` |
| `20261019T210009Z-native-admin-297` — administrativo PASS parcial | `611e9f88203fb7ea7255d51fd1c51ac619fd582014ccfb76e63579e6c14d37a4` |
| `20261019T210050Z-native-enrollment-297` — matrícula nativa | `18e40a9c1ba64dce45a0f4ce5d50aa1261e6eaee57340299abf832e6b5f40e85` |
| `20261019T210452Z-native-enrollment-297` — redirect e logout adicionais | `8e4b4e5bfabcf0544730ea5052b6bfad449a256690b4ac761d0a1c2ca1c87448` |

Admin: `mp4-2.json` SHA256
`2729cf3e1c66386036d09ccae2d75a4c229fcd1848fc9be4b5331ce14ad83d4f`;
`RECEIPT.txt` SHA256
`5071c7396d59bbf24c0ef00d53126c0227fe1542f2d5e72b489f3208e5cd527c`.
Matrícula: `enrollment-readback.json` SHA256
`03ee724759bd5d2b8a1073974b06e14e1f326809e963792c103e9872c4e358ee`.

**Ressalva de preservação:** no primeiro ensaio, o hash-base mudou de
`cb8588cfcbde48120eaae52840a1f97b0c376f7b79ab8efa3610c18b8fab71cd`
para `4dc75881fb3f2df0c01a9fa65f1e99973cb231a35ee84ddd0ee34a1ccbc81a16`.
A causa não foi isolada; os dumps foram removidos pelo cleanup, portanto não
é possível provar a diferença por linha retrospectivamente. O clone inicial
usava o hostname da base; nas execuções seguintes passou a usar hostname próprio
e `DISABLE_WP_CRON=true` somente no clone. Não afirmar que isso prova a causa.

Nas execuções posteriores, inclusive admin e matrícula, os hashes antes/depois
foram exatamente `4dc75881…`. Nenhum container-base reiniciou:
`StartedAt=2026-10-17T21:42:23.250450596Z`, restart0; rede internal=true com
dois containers ao final. Todas as contas, bancos, usuários MySQL, cookies,
containers e diretórios de clones foram removidos pelo teardown. A base
continuava com 3 usuários e 16 posts na inspeção intermediária. Não houve
escrita deliberada na base nem restauração para esconder o hash divergente.

## Catálogo e integração real de leitura

Consulta anônima de 19/10: 11 cursos publicados. Os extras 1474 e 1709 são
ofertas WordPress, não CourseVersions TDS. O catálogo dinâmico não deve ser
reduzido artificialmente para nove. Os nove cursos TDS:

| ID | Curso / slug | Seções | Itens públicos do currículo | API LP |
| --- | --- | ---: | ---: | --- |
| 614 | inteligencia-artificial-e-inclusao-digital | 5 | 17 | 200 |
| 1298 | agricultura-sustentavel | 8 | 13 | 200 |
| 1307 | atendimento-cliente | 6 | 9 | 200 |
| 1314 | audiovisual | 6 | 9 | 200 |
| 1321 | cooperativismo | 6 | 10 | 200 |
| 1328 | economia-lar | 6 | 9 | 200 |
| 1335 | educacao-financeira | 7 | 11 | 200 |
| 1343 | sim-sima | 6 | 9 | 200 |
| 1356 | saf | 5 | 8 | 200 |

Todos os nove `/wp-json/tds-learning/v1/courses/{id}/curriculum` retornaram404.
Isso não autoriza texto/vídeo interno: o aplicativo usa o fallback LearnPress
somente para sequência pública e encaminha ao curso oficial. A disponibilidade
das 48 URLs MP4/VTT históricas não equivale a opt-in móvel das 48 aulas.

O botão público observado no curso614 aponta para `/cadastro/?tds_curso=614`.
A página responde200 e possui formulário institucional `tds_cadastro` em
`admin-post.php`; nenhum POST foi feito no portal. O sandbox não contém esse
tema, portanto a matrícula nativa acima não homologa esse formulário.
Reutilizar #252/#249 para o handoff, sem duplicar SSO ou matrícula na API.

## Android e artefatos

Reexecução no LARGeo, Pixel_8_Pro read-only, Android15/API35, emulator-5556.
O diff de `cartilhas_app/lib` e `pubspec.lock` entre b05eaa0 e c853db0 é vazio.
APK QA **reutilizado**, não recompilado, com flags de laboratório visíveis:

`D:\AI-Shared\builds\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d\tutor-tds-pr295-b05eaa0-qa-debug.apk`

SHA256 `F5BD7623521E7ACC115E68994F55497862DC78BE9525A3BDFD20E789F4C5596A`.
PASS visual: abertura, catálogo11, percurso Agricultura8/13, mensagem de aula
não liberada internamente e intent HTTPS para curso canônico em Chrome.
Chrome abriu a página do curso, com diálogo inicial de notificações sobreposto.
O retorno ao app foi confirmado por `topResumedActivity` e `06-return.png`
(SHA256 `DE2F278140A970C6E030A013C8DD02BA8F584B8606E94F821BEDEBD1FD882A0F`).
Emulador desta sessão foi encerrado ao final. O buffer global de crash contém
falha de PrebuiltBugle; não foi tratado como log limpo nem como crash do Tutor.
A primeira instalação foi tentada antes do boot completar; a instalação após
boot passou. Duas capturas UI durante transições retornaram null root; uma
cópia XML obsoleta foi descartada, não usada como evidência do navegador.

Evidências: `D:\AI-Shared\test-results\tutor-tds\final-native-20261019`.

| Captura | SHA256 |
| --- | --- |
| `02-catalog.png` | `BB8CC805C7381330E39F53BEC87E5A1E21218669CA1A68A0BC0659652E3AF207` |
| `03-path.png` | `E9583BB032C8C74B16F4C16A6BF3826FC141F2D95FD503AE73D2CA654E56F882` |
| `05-browser.png` | `0A4D39CE087955C8EEDC86BB58B14AE0906D3BC1D16A09D0C157E260EF82B394` |

Playback, painel VTT, toggle, retorno do player, ausência de cookies na mídia e
fallback YouTube são **evidências históricas b05eaa0**, descritas em
`../ead-caption-accessibility-20261019/ANDROID_ACCESSIBILITY_RECEIPT_20261019.md`.
Não foram apresentados como novos testes. Áudio acústico e TalkBack falado
continuam UNKNOWN. Flutter9/9, regressão78/78, API7/7, runtime76/76 e preflight3/3
são reaproveitados com sua proveniência, não execuções novas deste recibo.

AAB histórico 1.4.0+13, fonte c853db0, hash novamente conferido:
`D:\AI-Shared\builds\tutor-tds\release-candidate-c853db021368f4b536521800ed9dc33ef68e3aac\Tutor-TDS-1.4.0+13-c853db0-inspection-unsigned.aab`.
SHA256 `F671CC61BDDEB7CD45D3E7953F98CD4A85F44B1A34B274AE0D6E3FA453776ADC`.
**Unsigned / NOT_FOR_UPLOAD**, não homologação final. Sem mudança Flutter e P0
integrado ainda incompleto, não há justificativa para novo build custoso.

## Handoff e próximo gate

- #297 permanece aberta/BLOCKED: autoria legítima permite save; HTTP negativos,
  ciclo de publicação e múltiplos pais continuam pendentes. Não repetir a ponte
  de capabilities descartada. Operação administrativa comprovada parcialmente.
- #252: reaproveitar matrícula MySQL/cookie e preparar fixture do tema
  institucional para cadastro/login/logout/redirect/acesso, sem dados reais.
- #197/#296: P0 não está homologado ponta a ponta para aulas internas, pois o
  adaptador público retorna404. Landing, assinatura e Play continuam proibidos.
- Ação humana mínima antes de publicação: confirmar responsáveis reais e
  conteúdo autorizado; decidir a operação editorial sob revisão administrativa;
  após QA do tema, autorizar separadamente promoção do adaptador/opt-ins
  selecionados. Depois cumprir revisão, custódia/assinatura, smoke físico e
  teste interno Play. Nenhuma dessas autorizações foi presumida.

Estimativa não contratual: 2–4h para fixture institucional e regressão editorial,
mais revisão humana e gates de assinatura/Play. Custo incremental observado:
R$0 de recursos contratados; VPS e LARGeo existentes. Custo de tokens/energia
não foi medido. A data-alvo não transforma UNKNOWN/FAIL em PASS.
