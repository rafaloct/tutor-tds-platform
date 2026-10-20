# Promoção focal ETag — 2026-10-20

## Escopo e proveniência

DECISION: autorização explícita nesta conversa para promover somente o PHP
do PR306, com backup/hash/rollback e smoke institucional/Android curso1298.
Não inclui liberar aulas, merge, assinatura ou Play.
Reserva: https://github.com/rafaloct/tutor-tds-platform/issues/303#issuecomment-6288135474

Fonte PR306: `0b9e2787411596646ddfe3fea9f22c05efce552d` (CI4/4 histórico).
Branch de recibo: `agent/issue-303-promote-etag-20261020`, sobre essa fonte.
WordPress6.7.2 / LearnPress4.3.6 preservados. Nenhuma mudança Flutter.
APK305 reutilizado e rehash local/instalado iguais:
`D:/AI-Shared/builds/tutor-tds/issue303-etag-20261019/issue303-f547720-qa-debug.apk`
SHA256 `24A1DEF29608D204B9CE225CE7EB3159C11DA96B4677ADACD1C841C65B8D0C2D`.
Fonte Flutter: `f547720538bfd1024544a0c9bd731b325797fdeb`.

## Resultado

| Gate | Estado | Evidência |
| --- | --- | --- |
| Promoção de um arquivo PHP + ativação nativa | PASS | promotion.log, integrity.json |
| GET currículo1298 gzip200 | PASS | http-smoke.json |
| GET com If-None-Match fraco literal,304 vazio | PASS | http-smoke.json |
| GET aula1299 não autorizada404 sem conteúdo | PASS | http-smoke.json |
| Android API35, currículo200 + refresh304 | PASS | android-refresh.json, refresh.png |
| Android não envia Cookie/Authorization | PASS | android-refresh.json |
| Fallback abre curso oficial e volta ao percurso | PASS | fallback-final.png, return.png |
| Dados e serviços preservados | PASS | integrity.json, options-audit.json |
| Reprodução MP4/VTT institucional | BLOCKED | Direitos OFF; não executada neste smoke |
| QA físico/áudio/TalkBack | UNKNOWN | Não executado nesta rodada |
| Release, assinatura, Play | HUMAN_GATE | Fora desta intervenção |

HTTP focal novo:3/3 requisições com resultados esperados,0FAIL.
Android focal novo:2/2 respostas com resultados esperados,0FAIL.
Tela mostra8 seções/13 itens,0 vídeos internos e fallback para curso oficial.
Isto comprova integração curricular, não integração completa de mídia.
32 testes #299,30 checkpoints editoriais e testes do PR306 não foram repetidos.

## Integridade e rollback

Host confirmado `srv1533541`, conexão privada; mount efetivo identificado.
Backup completo anterior `/opt/tds-institutional-backups/20261020T003715Z`:
três entradas SHA256SUMS revalidadas. Restore histórico demonstrou73 tabelas,
INSERTs idênticos;14 diferenças DDL explícitas utf8mb4 preservadas no recibo
anterior, não tratadas como igualdade de dump bruto. Nenhum novo restore alegado.

Backup focal privado root700:
`/opt/tds-institutional-backups/etag-promotion-0b9e278-20261020`.
Contém original.php, before.sql, after.sql, before.json e integrity.json.
Dumps e configurações privadas não foram copiados para Git.
Arquivo promovido:
`wp-content/plugins/tds-learnpress-editorial/includes/class-tds-learnpress-editorial.php`.
SHA anterior `6d6659bd7a4eb78885c852e4d2357941e75625831fa82a60c77e03aeadd5e154`.
SHA final `fe83864d4ac082163d493636a88fd044bc54e0529b6e334614986644a8f7ad16`.

Banco antes `90689607103fe328b61039529afb8103dbcd4f7065f89118a80bffa276281b48`.
Banco depois `b833b530d2767dacaa1ebd477d231b19c36ac5ca0849843952f3fc6b12978bc8`.
Diferença investigada, não aceita cegamente: somente opção active_plugins
mudou; lista validada como baseline + entrada exata do adaptador.
522 outras opções idênticas. Dados das outras29 tabelas com INSERTs idênticos.
A comparação focal não é um novo ensaio de restauração nem uma auditoria de schema.
IDs/imagens/StartedAt de WP,DB,Traefik iguais. Tema patch299 e demais arquivos
do plugin conferidos por hash. Nenhuma alteração de direitos, usuários ou autoria.

Rollback preparado: executar o runner `tooling/promote_editorial_etag.py`
por SSH stdin com argumento `rollback` no mesmo host. Ele desativa nativamente
o plugin e restaura somente original.php após conferir OLD/NEW; verifica hashes.
Não executado nesta promoção bem-sucedida; não alegar rollback novo testado.
Sem restaurar banco inteiro sobre produção nem substituir tema.

## Limitações operacionais

Emulador5554 reutilizado, sem reiniciar AVD ou encerrar outros processos.
Primeiro estado estava vazio; cold start apenas do package QA levou minutos,
com pressão de RAM e verificação de classes lenta. Houve duas falhas timeout
na ativação de instrumentação durante startup e dumps UI sem root; depois
app inicializou e as duas respostas HTTP finais foram observadas.
Não são resultados PASS ocultos nem novas tentativas de promoção.
Profiling HTTP foi desabilitado e forwards temporários removidos.
Fallback inicialmente demorou e o dump UI retornou null root; captura posterior
mostrou o curso oficial carregado. Botão Back voltou ao percurso com13 itens.
Ao terminar, somente o package QA foi encerrado; AVD e demais processos preservados.
Não houve cadastro, login, matrícula ou POST produtivo nesta rodada.

Histórico #297 continua independente/aberto. Nenhum novo AAB, custo de VM,
serviço contratado, merge ou publicação Play. Custos incrementais monetários
não medidos; prazo global depende de direitos, QA físico e gates Play.
