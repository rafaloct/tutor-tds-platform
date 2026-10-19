# Fechamento parcial #299 / integração — 19/10/2026

**Candidato NÃO homologado para lançamento.** Patch implementado e verificado
offline; HTTP do tema e E2E Android integrado permanecem BLOCKED.

## Fonte e ownership

- Base: `58059436bace0ae032005972ec9e865f3b39d0f0`, PR #298 draft.
- PR #296 continua draft `0b06e81ff3ed2ea2061384b22e645d81c783ddc7`.
- Runtime integrado preservado: `c853db021368f4b536521800ed9dc33ef68e3aac`.
- Branch: `agent/issue-299-institutional-enrollment-20261019`.
- Worktree exclusiva: `D:\AI-Shared\work\tds-issue299-institutional-enrollment-20261019`.
- Agentes anteriores concluídos; nenhum processo alheio interrompido.

## #299: resultado efetivamente executado

Fonte institucional TDS Child2.0.0/Astra4.13.1 obtida somente por leitura de
código. WP6.7.2/LP4.3.6 no sandbox. Não se copiou banco/configuração produtiva.
O patch preserva contexto de curso, valida publicação/origem, mantém login nativo,
retorno Minha Área sem curso e nonce403. Não matricula por SQL nem duplica SSO.

| Gate | Estado | Evidência |
| --- | --- | --- |
| aquisição fiel sanitizada | PASS | três hashes de origem conferidos, token removido, manifesto por arquivo |
| patch aplicado offline à cópia | PASS | diff exato e três lints PHP8.2 sem rede/DB |
| contexto: IDs/status/origem/redirect | PASS | 27/27 testes locais |
| regressão adaptador | PASS | 63/63 novos nesta rodada, fonte inalterada |
| GET de cadastro no clone fiel | FAIL | duas execuções HTTP200, sem formulário/template esperado |
| POST cadastro/novo usuário/login/matrícula deste tema | BLOCKED | não alcançados; não alegar contas QA criadas pelo formulário |
| teste negativo de nonce HTTP deste patch | UNKNOWN | previsto, não executado |
| isolamento e teardown de ambas as execuções | PASS | rede interna; container/DB/usuário DB/diretório removidos |
| banco-base antes/depois/final | PASS nesta rodada | hash idêntico `4dc75881…`; dumps recuperáveis restritos preservados |
| portal público | PASS no escopo observado | hashes das três fontes e StartedAt/restart preservados; nenhum POST/deploy |
| E2E Android contra tema/adaptador desta fixture | BLOCKED | fixture HTTP não homologada; sem nova execução Android |
| produção/merge/assinatura/Play | HUMAN_GATE | nenhuma promoção autorizada/executada |

### Stop após duas ocorrências

Observed: GET `/cadastro/?tds_curso=614` retorna200; parser encontra zero forms,
zero campos e nenhum `cad_nome`. Patch ainda não aplicado quando ocorre.
Expected: template institucional com `action=tds_cadastro` e nonce nativo.
Responsible boundary: preparação filesystem/ownership da fixture de QA.
Evidence: archive sanitizado tem diretórios700/arquivos600 `root:root`;
container sem rede executado como `www-data` confirmou leitura=NO.
Likely root cause: `umask077` aplicado aos novos arquivos do tema, sem ownership
compatível com Apache. É defeito confirmado de fixture; causalidade completa
do render só poderá ser fechada por uma nova execução autorizada.
Affected files: `acquire_theme.py`, `run-qa.sh`; não vendor/core nem Flutter.
Structural fix proposto, **não executado após stop**: ownership/permissões apenas
do código sanitizado no clone, guardas de leitura e carga do MU-plugin antes de
HTTP, manter cookies/dumps privados; capturar template/debug antes do teardown.

Não houve terceira execução. A preparação offline do diff/lint não fez HTTP,
não iniciou WordPress conectado a DB e não testa o cadastro.

## Evidências e preservação

Raiz VPS: `/opt/tds-learning-qa-20261017/backups/`.

| Artefato | SHA256 |
| --- | --- |
| `20261019T230605Z-registration-299/run.log` | `f96590876565845d5c091cd5dcf3ba55574a299ad35bb8acfa62d154be6ea35b` |
| `20261019T230700Z-registration-299/run.log` | `6db04d8ead88dd60662816ff652aaadc2dd6933ebf43934d03d4248a37749038` |
| segundo run `theme-provenance.json` | `32b5be5a88f40bcd04759c2266f222dd5ae4d67b477e1c9686318bacfa32b31d` |
| segundo run `sanitized-institutional-theme-before.tgz` | `887a5ba22a3c55be2a948278173d4dbd5a0d8dc238a9f403e17602583a42c5b6` |
| banco antes/depois/final desta rodada | `4dc75881fb3f2df0c01a9fa65f1e99973cb231a35ee84ddd0ee34a1ccbc81a16` |
| diff offline `theme.patch` | `a7d67bb7884f967d7ae108abe39f8563fb4e9e8596ba0d6b106fcec693d61c45` |

Fontes produtivas, mesmos hashes antes/depois:
`functions.php` = `3f896a20b7d0db98fe20eb6e211ab1785648d7ca322465fd77eb9fc99447c687`;
`pages/cadastro.php` = `67e88421dbd1a0883ef5dbb24cd906b6e3082b6d5026c46461b70030d0a8088f`;
`includes/admin-cadastro-aluno.php` = `f34757104fb3f8b4d2d7491e8b3d144a43ba705c01d0ed42a58e4b16cce20e07`.

Final: rede `internal=true`, dois containers-base; clone `tds-registration-299`
ausente; base3usuários sintéticos/zero itens acadêmicos. WP-base StartedAt
`2026-10-17T21:42:23.250450596Z`, público `2026-10-17T06:08:58.427789614Z`,
ambos restart0. Dumps restritos e cópias sanitizadas offline preservados;
nenhuma VM contratada. A divergência histórica do primeiro M1 do #298 continua
sem causa comprovada; estes hashes estáveis não a resolvem retroativamente.

## Nove cursos: nova auditoria anônima

Catálogo público11; extras1474 e1709 preservados. Todos os itens abaixo são
`lp_lesson`; a API marca todos como preview. Isso não é autorização móvel.

| ID | Seções | Aulas curriculares | Títulos “Aula NN” | LP HTTP | Adaptador |
| --- | ---: | ---: | ---: | --- | --- |
| 614 | 5 | 17 | 12 | 200 | 404 rest_no_route |
| 1298 | 8 | 13 | 6 | 200 | 404 rest_no_route |
| 1307 | 6 | 9 | 4 | 200 | 404 rest_no_route |
| 1314 | 6 | 9 | 4 | 200 | 404 rest_no_route |
| 1321 | 6 | 10 | 5 | 200 | 404 rest_no_route |
| 1328 | 6 | 9 | 4 | 200 | 404 rest_no_route |
| 1335 | 7 | 11 | 5 | 200 | 404 rest_no_route |
| 1343 | 6 | 9 | 4 | 200 | 404 rest_no_route |
| 1356 | 5 | 8 | 4 | 200 | 404 rest_no_route |
| Total | 55 | **95** | **48** | nove200 | nove rotas ausentes |

Corrige o total105 citado no handoff anterior: a soma real é95. Os48 títulos
numerados são consistentes com o inventário histórico48MP4/48VTT, mas não
comprovam vínculo de mídia/aprovação individual. Os47 demais itens não devem
ser contados automaticamente como videoaulas. Leitura interna do app está
indisponível por falta de rota, não por nove rejeições editoriais. Fallback ao
curso oficial não fecha a integração interna.

JSON sanitizado local: `D:\AI-Shared\test-results\tutor-tds\issue299-20261019\public-courses.json`,
SHA256 `BA5CC73B58834DF7EB07850725052E13993503980AF6ED38A4199EE088945DD2`.
O cliente urllib foi rejeitado pelo edge público; a auditoria concluída usou
GETs normais curl, sem login/cookie nem POST.

## Adaptador e #297 — frentes independentes

Os três hashes do adaptador instalado no sandbox coincidem com o Git:
bootstrap `0634e24dd1503e8e30904cf026540e7a1d89dad3c1bb1ffcfbc88144a17ec1d9`,
admin `eedf01c063ea3cd1718f92cc3e621b50b79705d374449d083701e1a7458be4da`,
REST `97e6dfd30376dd506f993980d7df9935007987f8b40eadc003b2b6b1f5dc1560`.
HTTP200/304 e direitos0→1→0 pelo admin são **evidências históricas #298**,
não novas execuções. Não houve instalação produtiva ou ativação editorial.

Pacote novo para inspeção/promoção futura:
`D:\AI-Shared\builds\tutor-tds\tds-learnpress-editorial-c853db0-promotion-inspection.zip`,
SHA256 `F8D61E14F6787EDD8FE3C332B75728D51B89A475C91CCA5B7A60DB3F66BD13DF`.
É arquivo Git da árvore inalterada do plugin, não autorização de instalar.
Backup/rollback pré-instalação e restore drill históricos:
`../ead-institutional-staging-20261019/README.md`. Promoção exige backup novo
do destino, revisão dos hashes/configuração, somente uma aula autorizada,
smoke HTTP, plano de desativar/restaurar plugin preservando dados e aprovação.

#297 continua aberta/BLOCKED. Leitura nova do código instalado:
`wp-admin/post.php:138–139` nega `edit_post` por `wp_die` sem status explícito;
o handler padrão usa500. Isso sustenta a origem semântica dos GETs, mas não foi
instrumentado um novo request para excluir todos os hooks. O erro de save de
curso alheio permanece a exceção LearnPress já comprovada; não são o mesmo caso.

`LP_Background_Single_Course::review_post_author`, linhas157–170, verifica
instrutor + `required_review` (default `yes`) + curso publicado e chama
`wp_update_post(... pending)`. A opção não está gravada na base sintética,
portanto o default é relevante. Não se observou novamente a transição antes/
depois em HTTP; não atribuir causalidade conclusiva ao save histórico. Preservar
revisão administrativa, sem conceder publish/edit_others e sem patch de bypass.

## Segurança pontual

O literal de integração foi removido da cópia sem ser exibido. O código o usa
como `websiteToken` do widget Chatwoot; privilégio de API secreta não foi
demonstrado. Não afirmar comprometimento nem rotacionar automaticamente.
TLS SMTP desabilitado foi confirmado no tema; recomenda-se validação TLS e
teste de entrega em ambiente apropriado antes da promoção do cadastro.
Envio administrativo de senha e matrícula SQL permanecem fora do patch;
substituição por definição de senha/matrícula nativa requer fatia própria.
Nenhum valor, senha, cookie, nonce ou banco real entrou no Git.

## Android/release

Flutter/lib e lock idênticos ao APK histórico b05eaa0; nenhum build novo.
Hashes novamente medidos:

- APK: `D:\AI-Shared\builds\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d\tutor-tds-pr295-b05eaa0-qa-debug.apk`,
  `F5BD7623521E7ACC115E68994F55497862DC78BE9525A3BDFD20E789F4C5596A`.
- AAB1.4.0+13: `D:\AI-Shared\builds\tutor-tds\release-candidate-c853db021368f4b536521800ed9dc33ef68e3aac\Tutor-TDS-1.4.0+13-c853db0-inspection-unsigned.aab`,
  `F671CC61BDDEB7CD45D3E7953F98CD4A85F44B1A34B274AE0D6E3FA453776ADC`,
  **unsigned / NOT_FOR_UPLOAD**.

ADB sem dispositivos nesta rodada; nenhum emulador ou Xiaomi utilizado.
Capturas/playback/VTT históricos estão no recibo #295, e catálogo/portal no
#298. Não alegar E2E novo, áudio acústico ou TalkBack falado. Testes históricos
Flutter9/9, EAD78/78, API7/7, runtime76/76 e preflight3/3 conservam proveniência.

## Ação mínima e trabalho remanescente

Técnico: fixture legível pelo Apache, bloqueio de correio comprovado, HTTP real
do tema, matrícula e acesso restrito; depois Android contra staging efetivo.
Humano imediato: autorizar uma nova rodada **após o stop**, limitada à correção
de ownership da cópia QA e à matriz #299. Não implica produção.
Humano para publicação: responsabilidade real por curso, direitos por aula,
promoção separada tema/plugin após QA, revisão/merge, assinatura, smoke físico
e teste interno Play. Nenhum desses gates foi dispensado.

Estimativa não contratual: 2–4h após retomada autorizada para fixture/HTTP/Android,
mais decisões de promoção e publicação. Custo incremental contratado observado:
R$0; LARGeo/VPS existentes. Tokens/energia não medidos.
