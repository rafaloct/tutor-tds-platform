# Issue #297 — autorização do editor de aula compartilhada

Base: PR #298, `58059436bace0ae032005972ec9e865f3b39d0f0`.
Ambiente: clone descartável de WordPress 6.7.2, LearnPress 4.3.6 e MySQL
sintético no VPS institucional, rede Docker interna, sem portas públicas.
Fonte produtiva, usuários reais e cursos reais não foram alterados.

## Estado e causa

**OBSERVED:** `wp-admin/post.php` chama `wp_die()` sem status explícito quando
`edit_post` é negado; o GET negado devolvia HTTP 500, sem formulário. O
LearnPress mantém `required_review=yes` e `LP_Background_Single_Course` muda
o curso de `publish` para `pending` após um save válido do instrutor. No clone
anterior à correção, o curso estava `publish`, o instrutor recebeu POST 302,
o título persistiu e o curso passou a `pending`. Portanto o REST 404 posterior
correspondia ao estado de revisão nativa, não a uma falha do player ou do save.

**OBSERVED — falha de segurança da operação editorial:** ao vincular a mesma
aula sintética a dois cursos de autores distintos, o professor autor da aula
e de apenas um dos cursos recebeu HTTP 500 no POST. Antes da exceção, o título
da aula já havia mudado e seu curso passara a `pending`. O curso alheio não
mudou. A autorização tardia do LearnPress não protegia a primeira mutação do
WordPress nesse caso.

**DECISION:** instrutor edita somente cursos e aulas sob sua responsabilidade
nativa; uma aula compartilhada exige autorização em todos os cursos pais.
O estado `pending` segue a revisão nativa. Nenhum privilégio `edit_others_*`,
bypass de `map_meta_cap` ou edição de vendor/core foi adicionado.

**IMPLEMENTED:** o adaptador examina GET `edit` e POST `editpost` de
`wp-admin/post.php` na fase `admin_init`, antes de qualquer gravação. Para
`lp_lesson`, exige `edit_post` na aula e `edit_lp_course` em cada pai listado
nas tabelas nativas LearnPress. Falha de consulta ou falta de autorização
retorna HTTP 403. Outras rotas/tipos de post permanecem no WordPress.

## Provas HTTP no clone

| Condição | Antes | Com o guard |
| --- | --- | --- |
| GET negado: aula alheia, editor, aluno | 500 sem formulário | 403 sem formulário |
| Curso e aula do mesmo professor, POST real | 302; curso `publish→pending` | 302; readback do título, direitos revogados, `publish→pending` |
| Aula com dois pais, autores distintos; GET/POST do professor de um pai | POST 500, título alterado | GET/POST 403, título e ambos os cursos inalterados |
| Administrador, aula compartilhada | não executado nessa fixture | POST 302 e readback do título |
| Registros acadêmicos após edição | 0 | 0 |

Cada execução verificou teardown de container, DB, usuário DB e filesystem
temporários, hash do banco-base idêntico antes/depois e container-base sem
reinício. Hash-base observado: `1ffeecf98e7999890ab7218ee4b3fbb7d142ccdad3bc29e292e5acb1cacecfa4`.
Os recibos privados do VPS ficam sob
`/opt/tds-learning-qa-20261017/backups/20261021T002244Z-native-owner-297`,
`20261021T002356Z-native-owner-297`, `20261021T002521Z-native-owner-297` e
`20261021T002610Z-native-owner-297`. Somente os `run.log` sanitizados foram
copiados a `D:/AI-Shared/test-results/tutor-tds/issue297-native-owner-final-20261020/`.

| Log local | SHA-256 |
| --- | --- |
| `baseline-run.log` | `96654451d99e3a87ad69e5917d5df85b7990980d8189b201c5488c7f85a8b4e8` |
| `shared-before-run.log` | `a7e3a7f62207b3ac026d8de72ee9d096379193ac7a82e9d12e5303b42f04690b` |
| `shared-after-run.log` | `fbe0c8f747d311a73ef0cc46e218987f629ab8ada4c12dc611c6335cddc160c5` |
| `owner-after-run.log` | `39af6de401b3989cff5971e2e509eb11f5116a580cf1ec90decd57a7b1dc36fd` |

Os scripts executáveis neste diretório reutilizam a fixture de
`../ead-native-owner-20261019/run-native-owner.sh` e exigem os dois arquivos
candidatos em `/tmp/tds-issue297-candidate-{admin,entry}.php` no VPS.
Preparação reproduzível: copiar os dois arquivos da worktree para esses nomes,
comparar seus SHA-256 com o commit testado, copiar o runner e executar `bash -n`,
depois `timeout 300 bash <runner>` no VPS. O runner é limitado pelo hostname,
verifica o plugin e a rede-base, cria somente clone sintético e usa trap para
teardown. `run-owner-guard.sh` cobre o save legítimo; `run-shared-guard.sh`
cobre a negativa e o administrador. Não executar ambos simultaneamente, pois
usam nomes de clone exclusivos da mesma fixture.

## Limites

**TESTED-STAGING sintético:** salvamento HTTP/readback, negativos, aula com
dois pais e preservação da origem. A suíte local de contrato PHP existente
passou 63/63. **UNKNOWN/BLOCKED:** titularidade dos nove cursos reais,
aprovação editorial das aulas e promoção do novo adaptador. Nenhum POST real,
republicação, merge ou deploy foi feito. A homologação do cadastro #299 e do
player Android permanecem em seus próprios recibos.
