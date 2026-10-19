# #299 — rodada sintética autorizada após STOP

## Resultado

TESTED-SYNTHETIC: **32/32 HTTP PASS, 0 FAIL**, baseline 3/3, contexto local
27/27 e contrato editorial local 63/63. Produção não homologada nem modificada.
Base: PR #300 `5f833c2a07cfa2e786d3a203413711bcf0d2578f`.
Branch: `agent/issue-299-qa-resume-20261019`.
Execução: 2026-10-19T23:30:38Z, WordPress 6.7.2, LearnPress 4.3.6, PHP 8.2,
tema institucional TDS Child 2.0.0 sanitizado sobre Astra 4.13.1.

DECISION: usuário autorizou nova rodada exclusivamente no QA isolado depois do
STOP. A revisão do PR #300 foi lida. As duas tentativas anteriores e seu runner
permanecem intactos; esta execução usa `qa-resume/run-qa-resume.sh`.

## Controles antes de POST

- Cópia descartável: diretórios de código 0750, arquivos 0640, grupo www-data;
  intermediários verificados, raiz do bind 0710. Sem 777 ou alteração da origem.
- `permissions.txt`: leitura efetiva por UID33 e travessia de todos os pais.
- `apache-probe.json`: Apache SAPI, MU-plugin carregado, `wp_mail` interceptado,
  HTTP externo interceptado, home/siteurl sintéticos e gate de POST fechado.
- `template-preflight.json`: cadastro HTTP200 com template real, action e nonce.
  Os dois preflights aconteceram antes de abrir o gate para POST.
- Rede Docker internal=true, nenhuma porta publicada; credenciais efêmeras em
  memória, dumps/backup restritos fora do document root. Nenhum transporte de
  e-mail foi alcançado (`QA_MAIL_TRANSPORT_REACHED_STOP` ausente do log PHP).

## Provas HTTP

`http-before.json` reproduz perda de contexto no tema original sanitizado.
`http-after.json` e `run.log` comprovam formulário, login, nonce inválido403,
curso inválido e redirect externo, cadastro302 para curso614, ausência de
matrícula automática, matrícula gratuita pela rota nativa LearnPress com nonce,
duplicata rejeitada, exatamente uma linha persistida, estado enrolled/in-progress,
retorno do matriculado, sessão ausente403, cadastro sem curso em Minha Área,
erro de e-mail mantendo contexto, conteúdo restrito somente ao matriculado e
logout. `users_can_register=0` foi preservado. Nenhum SQL de matrícula foi usado.

O patch de aplicação não precisou mudar. A correção desta rodada é a preparação
de permissões e os gates verificáveis da infraestrutura descartável de QA.
Os 27 testes locais originais e o teste HTTP original permanecem inalterados.

## Integridade, hashes e rollback

Evidência privada no VPS:
`/opt/tds-learning-qa-20261017/backups/20261019T233038Z-registration-299-resume`.
Contém backup recuperável sanitizado e dumps-base restritos; não publicar dumps,
cookies, nonces, senhas ou o log PHP bruto. Arquivos aqui são recibos sanitizados.

| Artefato | SHA-256 |
|---|---|
| Banco-base antes e depois | `4dc75881fb3f2df0c01a9fa65f1e99973cb231a35ee84ddd0ee34a1ccbc81a16` |
| theme.patch inalterado | `a7d67bb7884f967d7ae108abe39f8563fb4e9e8596ba0d6b106fcec693d61c45` |
| theme-provenance.json | `32b5be5a88f40bcd04759c2266f222dd5ae4d67b477e1c9686318bacfa32b31d` |
| http-after.json | `ff76a9b26e3ca500372aeb033b85bedd1267a114365fe91d9dc46a33e66f3e3a` |
| preflight.py | `2ddecdf65de104527320afcc294d675556f4eff1f901de31e45763591131de47` |
| qa-isolation.php | `9d0a61ca62d792f6b1fe2c326457da4015d29fe0838c78f65737efdc47c49135` |
| run-qa-resume.sh | `030a3e8fe5997f49254b961a476ad1380a030a8edfd2910532ca616efa5a2530` |

Os três arquivos executados foram comparados por SHA com a worktree LARGeo.
Teardown: container, banco descartável (inclusive usuários sintéticos), usuário
MySQL e filesystem removidos e ausência verificada. Backup/recibos preservados.
Container-base sem restart; hash-base idêntico. Isso **não explica nem encerra**
a divergência histórica do primeiro M1 no PR #298.

## Gates remanescentes

| Gate | Estado |
|---|---|
| #299 tema fiel + cadastro/login/matrícula HTTP | PASS sintético |
| Preservação/rollback desta rodada | PASS |
| Implantação do patch institucional | HUMAN_GATE; não realizada |
| Adaptador editorial público | BLOCKED: plugin não instalado; não inferir rejeição editorial |
| Android integrado ao staging nesta rodada | UNKNOWN; evidências anteriores não são novo teste |
| #297 negativas HTTP500 / múltiplos pais | BLOCKED independente; sem novo bypass |
| Release/assinatura/Play | HUMAN_GATE; AAB anterior NOT_FOR_UPLOAD |

Promoção, se aprovada separadamente: revisar diff/helper, fazer backup recuperável
e revalidar hashes do tema ativo. Não instalar tema sanitizado, fixture ou MU-plugin
de QA. Rollback restaura somente arquivos alterados e remove o helper novo após
verificar consumidores; jamais apagar matrículas ou usuários produtivos.
Nenhuma VM contratada, nenhum custo incremental faturado observado nesta rodada.
