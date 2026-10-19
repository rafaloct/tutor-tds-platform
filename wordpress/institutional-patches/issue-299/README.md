# #299 — patch contra TDS Child institucional 2.0.0

**IMPLEMENTED / TESTED-LOCAL; HTTP BLOCKED. Não implantar.**

Este diretório não substitui `wordpress/tds-child-theme` (WP-2) nem altera
o snapshot legado em quarentena. Contém um patch mínimo contra os arquivos instalados
inspecionados em 19/10/2026, sem copiar sua credencial de integração para Git.

## Alteração proposta

- `theme.patch`: preserva `tds_curso` no formulário, nos erros e no retorno;
  usa login WordPress existente com destino do curso; sem curso conserva Minha Área.
- `tds-registration-course.php`: validar inteiro positivo, `lp_course` publicado,
  sem senha e permalink na mesma origem. Entrada inválida retorna ao catálogo
  com `inscricao=curso-indisponivel`. Não aceita um redirect arbitrário.
- Nonce inválido do cadastro usa o terceiro argumento de `wp_die` para HTTP403.
- Usuário já autenticado retorna ao destino, sem criar outra conta.
- Nenhuma matrícula por SQL/API customizada. Após retorno, o usuário utiliza a
  matrícula nativa LearnPress. Redirect sozinho **não** confirma matrícula.

O login é composto com [wp_login_url](https://developer.wordpress.org/reference/functions/wp_login_url/)
e o destino passa por [wp_validate_redirect](https://developer.wordpress.org/reference/functions/wp_validate_redirect/).
O handler [admin_post_nopriv](https://developer.wordpress.org/reference/hooks/admin_post_nopriv_action/)
existente é preservado; não se modifica `users_can_register`.

## Proveniência e preparação offline

`acquire_theme.py` verifica os três hashes originais, copia somente código/assets
e remove o literal `TDS_CHATWOOT_TOKEN` da cópia. Não copia wp-config ou banco
produtivo. O manifesto relaciona hash original/sanitizado por arquivo.
`prepare_patch.py` exige cada trecho antigo uma única vez, recusa helper existente,
aplica as duas alterações à cópia e adiciona o helper. Normaliza os arquivos
alterados para LF. Nenhum desses scripts é um deploy automático autorizado.

O diff gerado no VPS e versionado aqui tem SHA256
`a7d67bb7884f967d7ae108abe39f8563fb4e9e8596ba0d6b106fcec693d61c45`.
Os três PHP resultantes passaram lint no PHP8.2 da imagem WordPress, sem rede/DB.

## STOP do runner HTTP

**Não executar novamente `run-qa.sh` nesta rodada.** Ele registra a receita
histórica das duas tentativas, não um runner homologado. As duas pararam antes
do primeiro POST, porque GET `/cadastro/` retornou200 sem formulário/template.
Uma investigação offline identificou diretórios700 e arquivos600 `root:root`
na cópia; `www-data` não consegue lê-la. Também não há comprovação de que o
MU-plugin de bloqueio de e-mail tenha sido carregado pelo Apache; a rede Docker
era interna e nenhum POST/usuário novo foi executado.

Antes de uma nova rodada **autorizada após o stop**, corrigir somente o ownership
da cópia sintética, não da origem nem dos backups. Confirmar leitura como
`www-data`, carga do MU-plugin, ausência de egress e template efetivo antes de
testar o cadastro. Preservar debug sanitizado e arquivos de diagnóstico antes
do teardown. Não conceder 777 nem tornar dumps/cookies legíveis pelo servidor.
O defeito de permissão está comprovado; sua correção ainda não foi testada e não
exclui outra diferença de configuração do runtime.

`test_http.py` implementa a matriz desejada com cookies, formulários e nonces
reais; até agora **somente o primeiro GET foi executado**. `fixture.php` cria
curso614 sintético e páginas; não insere matrículas. O histórico de matrícula
nativa no #298 não substitui os testes deste tema.

## Verificação local

```powershell
C:\php\php.exe -n wordpress/institutional-patches/issue-299/test-context.php
C:\php\php.exe -n wordpress/tds-learnpress-editorial/tests/test-contract.php
python tooling/verify_wp_legacy_snapshot.py
```

Resultado: contexto27/27; editorial63/63. São contratos locais, não HTTP.
Relatório de execução, hashes, isolamento e gates:
`docs/qa/ead-registration-context-20261019/README.md`.

## Promoção e rollback — HUMAN_GATE

Após HTTP aprovado, revisar apenas o diff e helper; não instalar a cópia de QA,
seu token vazio, `qa-isolation.php`, fixture, runners ou o tema WP-2.
Backup recuperável dos dois arquivos reais + hash e snapshot de configuração
antes de uma implantação autorizada. Revalidar hashes da origem; divergência
interrompe a aplicação. Rollback restaura os dois arquivos exatos e remove
somente o helper novo após confirmar que nenhum outro consumidor o utiliza.
Não restaura/apaga usuários ou matrículas produtivas. Produção não foi alterada.
