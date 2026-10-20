# Continuidade goldenrod-argon — revalidação PHP #303

Base: PR305 `2402365bd517d3d5abab95e5d99499dd075b37fc`.
Executor atual: Codex/LARGeo, worktree exclusiva
`D:/AI-Shared/work/tds-issue303-server-etag-20261020`,
branch `agent/issue-303-server-etag-20261020`.
Pedido humano: continuar a sessão interrompida. A worktree Devin não foi editada.

## OBSERVED — recuperação do trabalho anterior

A sessão goldenrod-argon terminou depois dos recibos de 20/10 03:42 UTC,
antes de publicar o handoff. Não terminou antes da reativação:

1. Primeira ativação revertida por falha no verificador operacional:
   `active_plugins` veio como objeto JSON com índices não sequenciais, não lista.
2. Segunda ativação passou no verificador corrigido. GET1298 retornou gzip200,
   ETag fraco coerente com revision, 8 seções,13 itens,13 aulas sem opt-in,
   zero mídias expostas. Reenvio literal do ETag fraco retornou200 com corpo
   idêntico em vez de304. Rollback nativo imediato, exit0.
3. Dumps protegidos antes/depois mudaram somente em wp_options;29 blocos de
   tabelas não vazias idênticos. Arquivos e serviços preservados segundo o
   recibo Devin. Isso não é nova execução nem prova de banco vivo imutável.
4. Android anterior/posterior ao rollback: editorial404 → LearnPress200;
   percurso1298 renderizou13 itens sem acesso interno. Fallback PASS não é
   integração editorial PASS. Capturas/readbacks preservados.

Recibos originais:
`D:/AI-Shared/test-results/tutor-tds/issue303-etag-20261019/institutional/`.
Backups protegidos no VPS:
`/opt/tds-institutional-backups/issue303-reactivation-20261020` e
`/opt/tds-institutional-backups/issue303-reactivation-20261020-attempt2`.
Não copiar dumps produtivos para Git. Evidências sanitizadas copiadas neste
diretório são históricas; hashes em `SHA256SUMS.txt`.

Readback desta retomada,20/10 09:30 UTC: hostname srv1533541 e WP-CLI confirmou
plugin **inactive**. Aviso preexistente WP_DEBUG duplicado, não alterado.
Nenhuma terceira ativação, mutação produtiva, repetição #299/#302 ou build.

## Causa e correção candidata

Observed: `respond()` comparava If-None-Match literalmente com ETag forte.
Expected: o validador fraco da mesma revisão deve revalidar GET.
Responsible boundary: adaptador PHP, separado da correção Flutter PR305.
Evidence: `http-smoke.json` recuperado, código e novos testes.
Root cause: comparação forte no servidor impede o304 quando o cliente conserva
o W/ recebido. O componente que enfraquece o header continua UNKNOWN.
Affected files: classe REST, testes focais e workflow PHP.
Structural fix: aceitar exatamente `"revision"` e `W/"revision"` após construir
a projeção autorizada; apenas espaço/tab externos são removidos.

Contrato de recorte: validador único usado pelo cliente atual; listas e wildcard
continuam recebendo resposta completa200, como antes. Não se reivindica parser
geral de precondições HTTP. Nenhum substring match ou bypass de autorização.
ETag não é assinatura nem aprovação editorial.
Referência: [RFC9110,13.1.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-13.1.2).
Offline/cache cliente, fingerprints e capacidades não foram alterados.

## TESTED-LOCAL

PHP8.4.6 CLI no LARGeo, `-n` isola configuração global de extensões:

```text
php -n wordpress/tds-learnpress-editorial/tests/test-etag.php
python wordpress/tds-learnpress-editorial/tests/test-etag-http.py
```

- 63 verificações existentes PASS,47 novas verificações focais PASS.
- 13/13 requisições HTTP loopback com resultados esperados: gzip/identity200,
 fraco/forte304 sem corpo, revisão diferente200, opt-in revogado404.
- Lint PHP PASS. Servidor PHP temporário encerrado pelo finally do harness.

O transporte HTTP é real; WordPress/LearnPress são **stubs**. Isso não comprova
WordPress6.7.2/LearnPress4.3.6/Apache reais nem promoção institucional.
A transformação forte→fraco é simulada explicitamente no router de teste.
Não instalar nenhum arquivo de tests/ em produção.

## Gates e próximo passo

| Gate | Estado |
|---|---|
| Recuperação de handoff/rollback Devin | PASS evidência histórica; inactive reconfirmado |
| PHP focal e HTTP local | PASS |
| Runtime WP/LP real com o novo PHP | UNKNOWN |
| Smoke institucional gzip200/304 + Android editorial | BLOCKED |
| Promoção do PHP novo após STOP | HUMAN_GATE |
| Direitos, tutores, #297, Xiaomi, Play | Pendências anteriores preservadas |

Próxima fatia: clone sintético isolado validado, plugin com hash do novo commit,
HTTP200/304 e autorização negativa; só então promoção controlada especificamente
aprovada. Preservar backup/hash dos três arquivos antigos. Se a promoção falhar,
desativar nativamente apenas o adaptador e confirmar editorial404/LP200,
sem restaurar banco inteiro nem remover patch299. Reverter o código exige
restaurar somente o arquivo alterado após hash, com plugin inativo.

Sem nova assinatura, AAB, upload, merge ou criação de contas nesta retomada.
O APK PR305 continua o candidato Flutter; não foi reconstruído ou re-homologado.
