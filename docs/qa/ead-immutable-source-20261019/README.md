# Fonte imutável e integração editorial Android — QA sintético

Rodada autorizada após STOP do PR #301; base `da748302907f523f63eb2dc427b748ff9cbbe994`.
Branch `agent/issue-197-immutable-qa-audit-20261019`. Execução 19/10/2026 local;
VPS iniciou `20261019T235832Z` (evidências finais atravessam 20/10 UTC).
Nenhum patch de aplicação, Flutter, WordPress público ou bypass #297.

## Investigação somente leitura

Os dois dumps da rodada #299 preservam SHA256
`4dc75881fb3f2df0c01a9fa65f1e99973cb231a35ee84ddd0ee34a1ccbc81a16`.
Os dois dumps do STOP preservam
`1ffeecf98e7999890ab7218ee4b3fbb7d142ccdad3bc29e292e5acb1cacecfa4`.
O parser lexical [dump-comparison.json](dump-comparison.json) comparou 27 tabelas:
26 blocos de dados iguais; 3 usuários sintéticos, 16 posts e currículo iguais.
Seis opções diferem: cron, finished_updating_comment_type, update_core,
update_plugins, timeout e valor de wp_theme_files_patterns. Também mudou
AUTO_INCREMENT de options, 208 para 213. O novo parser inclui o valor do
transiente de padrões, ausente da comparação anterior por expressão regular.

**UNKNOWN:** qual processo escreveu essas mudanças. Não há atribuição exclusiva
a cron nem descarte da divergência por serem opções. O novo hash não foi aceito
como baseline. A divergência histórica do primeiro M1 permanece não explicada.
Os dumps originais não foram normalizados, sobrescritos ou apagados.

## Fonte de restauração offline

VPS `srv1533541`, diretório exclusivo:
`/opt/tds-learning-qa-20261017/immutable-qa-4dc75881-20261019`.
É uma **reconstrução verificável**, não um backup histórico completo do filesystem:

- SQL: cópia exata do dump #299 4dc75881 antes/depois, somente dados sintéticos.
- WordPress 6.7.2: 3.224 checksums oficiais conferidos; ZIP SHA256
  `b6acbc116aabdc5a7c9bc4e861647148a1b444c1f2beec5440261b88f02c3a6e`.
- LearnPress 4.3.6: ZIP igual ao pacote anteriormente ensaiado,
  `1230172064c3065e131f95f25d5a8772255e85b725842eade28bf24b0ff61a20`.
- Tema institucional sanitizado: 40 arquivos conferidos contra manifesto retido,
  Astra do mesmo arquivo preservado; não recapturado da produção.
- Três arquivos runtime do adaptador comparados com pins Git da fonte c853db0.
- WP-CLI: `ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c`.

Manifesto de 6.043 arquivos, SHA256
`7c9d4b3771640e63a3df30799a8aebdb97b4bc8b02f96c568d0acb4fbfae2e51`.
Arquivos0400/diretórios0500 root:root, atributo imutável +i, sem wp-config.php,
sem container montando essa origem e sem WordPress/cron conectado a ela.
Todos os hashes foram revalidados antes/depois do clone. Não houve novo dump,
POST ou consulta WordPress contra a antiga origem ativa.

## Matriz executada nesta rodada

| Gate | Resultado | Evidência |
|---|---|---|
| Parser de dumps | PASS 6/6 | `python -m unittest discover -s tooling -p test_qa_snapshot_audit.py -v` |
| Apache UID33, MU, mail/HTTP bloqueados, POST inicialmente fechado | PASS | [apache-probe.json](apache-probe.json), [run.log](run.log) |
| Rede Docker internal, zero portas publicadas | PASS | runner com assertions e run.log |
| Formulários nativos, direitos0→1→0 com mudança VTT, REST/ETag200/304 | PASS | [editorial-http.json](editorial-http.json), 30/30 checkpoints totais |
| Nonce inválido403 e opt-out REST404 | PASS | editorial-http.json |
| Uma aula explicitamente reautorizada para Android | PASS | dois salvamentos nativos adicionais, direitos0→1 |
| Android currículo/aula de clone real | PASS | [ui-course.xml](android/ui-course.xml), [ui-lesson.xml](android/ui-lesson.xml) |
| MP4 avança, 35 cues, legenda separada atualiza | PASS | [reprodução](android/player-playing.png), [cena posterior](android/player-later.png), JSONL |
| Mostrar/ocultar, pausa e retorno | PASS | captions-hidden/paused-captions JSONL e ui-return.xml |
| Reprodução não cria estado acadêmico | PASS | zero learnpress_user_items antes/depois; FastAPI não conectado ao clone |
| Rollback de container, DB, usuário e cópia de arquivos | PASS | run.log, rollback-counts.txt (0/0) |
| Fonte imutável após rollback | PASS | 6.043 hashes conferidos novamente |
| Autoria da divergência antiga | UNKNOWN | diferenças comprovadas, writer não atribuído |
| Áudio ouvido e TalkBack | UNKNOWN | sem medição acústica ou ensaio TalkBack nesta rodada |
| #297 | BLOCKED independente | não ensaiada, nenhum bypass nem mudança de autoria real |
| Produção/release | HUMAN_GATE | não homologados por este clone |

HTTP30/30 são checkpoints, incluindo leituras de formulário repetidas, não 30
cenários de negócio distintos. Nenhuma falha de assertion no ensaio HTTP.
#299 HTTP32/32 e testes locais27/27 são históricos, preservados e **não repetidos**.
Não somar esses números como testes novos. O ensaio editorial usa administrador
sintético com capacidades administrativas; não demonstra resolução da #297.

## Android e conexão privada

Emulador `emulator-5554`, Pixel8Pro Android35. APK histórico, hash revalidado:
`F5BD7623521E7ACC115E68994F55497862DC78BE9525A3BDFD20E789F4C5596A`.
Fonte `b05eaa058fb4b0c86c5569215652b893c55b517d`, caminho LARGeo:
`D:\AI-Shared\builds\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d\tutor-tds-pr295-b05eaa0-qa-debug.apk`.
Não é um APK recompilado do HEAD desta documentação; lib/lock inalterados.

Ponte: ADB reverse18731 → loopback LARGeo → TLS com certificado efêmero pinado
e SNI validado sobre tailnet → loopback Desktop18732 → túnel SSH → IP Docker
privado192.168.16.4:80. Somente dois GET REST (curso12/aula13), sem Cookie ou
Authorization; POST501, caminho administrativo404 e cookie canário403 testados.
Não houve porta pública, túnel público ou desativação da verificação TLS.
MP4/VTT são arquivos públicos já existentes no IPEX, acessados somente por GET.
Currículo/aula vieram **ao vivo do clone**, não de JSON fixture servido localmente.

Player: avanço0→7,346→19,883→26,254s, duração293,843s,35 cues, sem mediaError.
Legendas atualizadas abaixo da imagem; botão aria-pressed true→false→true.
Pausa confirmada no DOM e retorno à aula na árvoreUI. Cookies do domínio de mídia:
zero em todas as capturas; não equivale a auditoria de todo o tráfego anterior.
Uma tentativa programática de play foi corretamente negada por falta de gesto;
o toque real iniciou a reprodução. A primeira captura UI durante transição falhou
com null root; a leitura seguinte funcionou. Ambos são preservados como limites
do procedimento, não ocultados nem classificados como falhas do produto.

## Rollback, preservação e próximos gates

Recibos privados completos:
`/opt/tds-learning-qa-20261017/backups/20261019T235832Z-immutable-editorial`.
Container `tds-immutable-editorial-20261019T235832Z`, DB/grant exclusivos e
diretório `immutable-clone-20261019T235832Z` removidos; são recriáveis pela fonte
imutável preservada. Hash da origem permaneceu fixo. PHP log privado não vai ao Git.
Túnel SSH e relays próprios encerrados, forwards/reverse desta rodada removidos,
chave TLS efêmera excluída. Nenhum processo de outro agente foi encerrado.

Não há novo APK/AAB. AAB histórico F671CC61… permanece unsigned/NOT_FOR_UPLOAD.
Não houve nova auditoria dos nove cursos reais nem autorização editorial em massa.
Produção intacta pelo limite operacional (nenhuma escrita); não alegamos comparar
o banco produtivo ou provar imutabilidade de um site público ativo.

TARGET: promoção controlada do adaptador e patch #299, seguida de homologação
institucional e gates de release. Reason: QA sintético não concede implantação.
Exact human action: aprovar separadamente pacote de implantação/backup/rollback,
seleção editorial legítima e, posteriormente, assinatura/publicação após seus gates.
What remains unblocked: revisão deste PR draft e planejamento da promoção; #297
continua separada. Nenhuma nova VM/GPU contratada; custo incremental monetário não
medido, nenhuma contratação realizada. Horas restantes dependem desses gates,
portanto não há estimativa verificável de publicação nesta rodada.
