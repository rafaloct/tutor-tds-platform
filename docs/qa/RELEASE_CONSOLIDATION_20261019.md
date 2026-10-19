# Tutor TDS — consolidação e homologação local

Data: 19/10/2026. Executor: LARGeo. Estado: player Android e candidato integrado
homologados localmente; AAB não assinado aprovado para inspeção; release/Play
continuam sob gates humanos.

## Origem e candidato

| Item | SHA / estado |
| --- | --- |
| base do PR #295 / PR #293 | `91c5934eb071d8decc8d26e12eeb50e63bd72846` |
| candidato local homologado | `b05eaa058fb4b0c86c5569215652b893c55b517d` |
| branch | `agent/issue-294-caption-accessibility-20261019` |
| #284 local | `7112d098891aef357c47ab70707d0d5e8a686a47` |
| #287 local | `b9a7fab6dcccc96fbcd41ac34ab45c47e9345de9` |
| #289 local | `1de5e9e6f55c161e433cbf5882cb5e62a80eebc3` |
| #292 integrado | `e8b60569e36da42b0cf11e98e4adced3da6631d6` |
| #293 local | `91c5934eb071d8decc8d26e12eeb50e63bd72846` |
| #295 local | `b05eaa058fb4b0c86c5569215652b893c55b517d` |
| recibos #295 | `2d61805a982643c6ec16b4275d6f7f7633baa26b` |
| candidato integrado #292+#295 | `c853db021368f4b536521800ed9dc33ef68e3aac` |

Os HEADs remotos acima foram confirmados ao vivo após reautenticação. PRs #238,
#284, #287, #289, #292, #293 e #295 estão OPEN/draft, mergeáveis/CLEAN; todos
os checks reportados concluíram SUCCESS, inclusive no HEAD documental
`2d61805a…` do #295. O PR #295 não possui review, pedido de review ou thread;
o comentário de handoff foi publicado após a homologação. A pilha
#284→#287→#289→#293→#295 é linear; o PR
#292 era frente paralela de #289 e foi integrado localmente ao #295 por merge
`--no-ff`, sem conflito, no candidato `c853db0`.

PRs/issues reutilizados: PRs #238, #284, #287, #289, #292, #293 e #295;
Issues #290, #291 e #294. A busca de duplicidade encontrou as Issues #3
(preflight sem AAB) e #197 (release 1.4.0+13); nenhuma issue nova foi criada
antes de uma reprodução limpa. Nenhum merge foi realizado.

## Matriz final

| Gate | Estado | Resultado |
| --- | --- | --- |
| ownership/processos | PASS | reserva original respeitada; AVD próprio usado após liberação; fixture PID 15032 preservada; processos próprios encerrados |
| integridade SDK/cache | PASS | Flutter 3.44.9/Dart 3.12.2; Android SDK 36.1.0 e pub cache usados |
| APK exato do #295 | PASS | SHA-256 `F5BD7623521E7ACC115E68994F55497862DC78BE9525A3BDFD20E789F4C5596A` |
| MP4 IPEX/play/pause/retorno | PASS | reprodução real, cenas/cues distintas, pausa estável, retorno sem crash |
| painel VTT separado/toggle | PASS | painel fora do vídeo; Mostrar/Ocultar e cues atualizados |
| sem VTT | PASS | nenhum track, botão ou painel |
| YouTube | PASS | alternativa editorial existente preservada |
| TalkBack semântico | PASS | controles, ToggleButton e cue expostos na árvore |
| TalkBack falado | UNKNOWN | diálogo do Accessibility Suite impediu validação completa |
| áudio técnico | PASS | stream AAudio media iniciado e não mutado |
| áudio acústico | UNKNOWN | não houve aferição auditiva/instrumental confiável |
| cookies/credenciais | PASS no caso | MP4 sem Cookie/Authorization; cookie jar vazio; sem PII |
| testes Flutter afetados | PASS | #295 9/9; analyze zero issues |
| regressão EAD ancestral | PASS | #293 78/78 e analyze PASS |
| entrada pública/catálogo/aula | PASS sintético | Welcome → catálogo → curso → curriculum LearnPress sintético → aula no Android |
| inscrição/login/matrícula E2E novo | UNKNOWN | não afetados pelo diff e não repetidos; aceite histórico não foi promovido a prova deste APK |
| currículo LearnPress real | UNKNOWN | bridge sintética passou; integração real integral continua não demonstrada |
| presença/frequência | PASS de contrato | regra exata de 70% e fallback legado passaram na API; sem operação produtiva |
| progresso por vídeo | PASS (ausência) | player não chama conclusão, presença, nota ou certificado |
| conclusão/pedido/aprovação | PASS de contrato | snapshot/idempotência/ordem e gate humano passaram; E2E institucional não repetido |
| Tutor contextual/conectividade | NOT_AFFECTED | nenhum arquivo/contrato do Tutor mudou; evidência anterior preservada, sem novo claim |
| regressão acadêmica | PASS | sete testes focais, ambiente lockado; API não alterada pelo #295 |
| LearnPress real integral | UNKNOWN | #292 comprova WordPress core/fixtures; LearnPress real integral não demonstrado |
| preflight Android/release | PASS | 3/3; versão 1.4.0+13; min24/target36/compile36; lock preservado |
| configuração de produção | PASS | endpoints aprovados; todas as flags de risco false |
| endpoints/flags dentro de AAB release | PASS | `libapp.so` sem URL local/staging/dynamicqa; endpoints aprovados presentes; config validada |
| AAB de inspeção | PASS | 68.474.022 bytes, três ABIs, não assinado, SHA-256 `F671CC61…776ADC` |
| assinatura/upload/Play | HUMAN_GATE | `key.properties` ausente; artefato histórico superseded; upload proibido |
| cadeia #292 + #295 | PASS | merge `c853db0`, ambos os pais preservados e sem conflito |
| CI/HEADs GitHub | PASS | HEADs inalterados; checks verdes; PRs draft/mergeáveis |
| handoffs GitHub | PASS | recibo publicado no PR #295 e na Issue #294 |
| merge/deploy/produção | HUMAN_GATE | autorização humana específica não concedida |

## Evidências e artefatos

APK QA: 90.572.872 bytes, pacote isolado
`com.tutortds_cartilhas.dev.dynamicqa.rb05eaa058fb4b0c86c5569215652b893`,
`1.4.0-dev`/13, minSdk 24, target/compile 36, ABIs arm64-v8a,
armeabi-v7a e x86_64. Caminho:
`D:\AI-Shared\builds\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d\tutor-tds-pr295-b05eaa0-qa-debug.apk`.

Evidências Android: 74 arquivos/6.599.511 bytes em
`D:\AI-Shared\test-results\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d`.
Hashes e observações estão em
`ead-caption-accessibility-20261019/ANDROID_ACCESSIBILITY_RECEIPT_20261019.md`.
Logs acadêmicos/preflight reutilizados estão em
`D:\AI-Shared\work\android-qa\results\largeo-acceptance-20261019` e possuem hashes
registrados no mesmo recibo.

AAB integrado: `D:\AI-Shared\builds\tutor-tds\release-candidate-c853db021368f4b536521800ed9dc33ef68e3aac\Tutor-TDS-1.4.0+13-c853db0-inspection-unsigned.aab`,
SHA-256 `F671CC61BDDEB7CD45D3E7953F98CD4A85F44B1A34B274AE0D6E3FA453776ADC`.

## Estado do AAB e release

Nenhum AAB correspondente a `b05eaa0` foi gerado na primeira worktree. A tentativa usou
`production.example.json`, validado pelo verificador, sem `key.properties` e
sem chave real. A primeira compilação falhou porque o registrant Android gerado
incluía `integration_test`, ausente na classpath release. A única repetição pelo
fluxo normal deixou o wrapper de lote em loop depois de encerrar o compilador,
sem artefato. O wrapper próprio e o daemon próprio foram encerrados; daemon e
fixture preexistentes foram preservados. Após duas tentativas, as alterações
pararam conforme o playbook. Em worktree integrada limpa, o build pelo
`flutter_tools.snapshot` passou; o erro de registrant não se repetiu e o
`flutter.bat` foi isolado como o wrapper que entra em loop neste host.

O artefato versionado antigo permanece `superseded`, `upload_allowed=false` e
`matches_current_source=false`. O novo AAB é somente de inspeção, deliberadamente
sem assinatura e **NOT_FOR_UPLOAD**; a release ainda não está liberada.

## Bloqueios e ação humana mínima

1. Para fechar acessibilidade, um operador deve dispensar/conceder a permissão do
   Android Accessibility Suite e confirmar anúncio/acionamento TalkBack; para
   áudio acústico, ouvir em hardware/emulador com saída confiável.
2. Executar a prova com LearnPress real em ambiente sintético isolado.
3. Revisar o candidato integrado e decidir a estratégia de landing dos PRs
   stacked; nenhum merge está autorizado por este recibo.
4. Build oficial com config custodiada, assinatura real, upload e promoção
   continuam gates humanos separados.

## Estimativa e custo observado

- a partir deste checkpoint: **2–4 horas técnicas** para LearnPress real, revisão
  da integração e preparação do build oficial; **0,5–1 hora humana** para
  TalkBack/áudio e decisões de merge/release.
- custo incremental monetário observado nesta execução: **R$ 0,00**. Foram usados
  somente CPU, disco e emulador locais; nenhum serviço pago, deploy, upload ou
  mudança institucional foi executado.

## Estado da documentação

`docs/CURRENT_STATE.md`, `docs/production/TRACEABILITY_MATRIX.md` e o diretório
`docs/qa/ead-caption-accessibility-20261019/` foram atualizados localmente. O
commit documental posterior não altera o binário nem sua proveniência: o APK
continua ligado exatamente ao HEAD funcional `b05eaa0`.
