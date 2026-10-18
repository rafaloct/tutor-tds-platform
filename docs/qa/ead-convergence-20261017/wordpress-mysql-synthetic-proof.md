# EAD → Tutor TDS | WordPress real com MySQL sintético e API HTTP

**17/10/2026 · ensaio isolado da Issue #236 / PR #238.** Este relatório complementa o ensaio independente em SQLite já registrado no PR, sem substituí-lo.

## Identidade do ambiente e fronteiras de segurança

- Host VPS `srv1533541`, apenas como **ambiente Docker de teste**. Rede interna Docker `tds-learning-qa-20261017` (`Internal=true`); contêineres `tds-learning-qa-wp-20261017` e `tds-learning-qa-db-20261017` com `PortBindings=map[]`, sem endpoints públicos nem ligação ao Traefik/DNS.
- WordPress **6.7.2**, LearnPress **4.3.6**, PHP **8.2.28**, MySQL **8.0.45**, a partir das mesmas imagens e plugin LearnPress que estão no servidor, sem copiar a base operacional, usuários, matrículas, tentativas, certificados ou uploads.
- Banco `tds_learning_qa_synthetic` gerado do zero, armazenamento e credenciais QA dentro de `/opt/tds-learning-qa-20261017` com acesso restrito. Senhas, WP config, cookies e tokens não são parte deste documento ou repositório.
- Fixtures inteiramente inventadas: curso SAF QA ID 12; aula publicada 13; quiz publicado 15; aula e quiz em rascunho. Nada é uma avaliação real ou autenticação de participante.
- Instalação inicialmente aguardou a conclusão da inicialização do MySQL. Após retry, WordPress e LearnPress ativaram. A cópia inicial do plugin TDS tinha pasta com permissão 0700: funcionava em WP-CLI como root, mas não carregava no Apache. Corrigido **apenas no contêiner QA** por permissão de leitura/executável, e então REST respondeu HTTP 200.

## Resultados verificados

| Cenário | Resultado |
| --- | --- |
| WordPress + LearnPress inicializados e plugin TDS ativo | PASS |
| REST nativo LearnPress com seção e lição/quiz de QA | HTTP 200 |
| REST do adaptador, currículo de QA | HTTP 200 |
| Apenas dois itens publicados aparecem; aula e quiz draft omitidos | PASS |
| Conteúdo da aula sem opt-in | HTTP 404 |
| Mesmo ETag via `If-None-Match` | HTTP 304 |
| Aula liberada explicitamente por meta editorial sintética | HTTP 200 |
| Script ativo, seu corpo `alert(...)` e shortcode desconhecido removidos | PASS |
| URL de vídeo sem aprovação de direitos | Omitida |
| ID YouTube aprovado no banco QA | Exposto sem dado sensível |
| Revogação da liberação editorial | HTTP 404 |
| Suite via WordPress WP-CLI real | **23 verificações PASS, exit 0** |
| Stubs PHP de segurança (inclui HTML acima do limite) | **37 asserções PASS** |
| WordPress público e Traefik, após o ensaio | Ambos ativos; WordPress healthy |

**Importante:** a primeira execução real identificou que `wp_kses` isoladamente remove a tag `<script>` mas conserva o corpo, e que `strip_shortcodes` não elimina tags desconhecidas. A correção já havia sido publicada por outra sessão (commit `5093b9b`, consolidada no HEAD de PR #238), e foi aplicada no contêiner QA para repetir o teste. Não sobrescrever aquele commit.

## Limitações explícitas

- MySQL isolado e REST reais **não representam** toda a instalação WordPress de produção: tema Astra, outros plugins, contas de instrutores, reverse proxy HTTPS e política Cloudflare/403 ainda requerem homologação.
- A origem REST oficial retorna a sequência e os tipos publicados; o adaptador só divulga o **conteúdo da aula explicitamente liberado para acesso público**. Conteúdo restrito a matriculados exige fluxo de autorização separado.
- O QA sintético não contém 29 quizzes/282 questões reais. Nenhum gabarito, CPF, matrícula, prova ou nota foi copiado.
- O novo cliente Flutter do PR #240 foi testado em laboratório com contratos simulados; **este ensaio não prova ainda o app Android consumindo via HTTPS o adaptador instalado**.
- O vídeo YouTube aqui foi representado por um ID já conhecido e habilitado **somente no banco sintético**. Não comprovou player nativo, legenda VTT, analytics, consentimento nem homologação das 48 videoaulas.

## Continuação e rollback

Os contêineres internos foram deixados temporariamente ativos para ensaios complementares. Antes de uma janela de testes, conferir portas e integridade dos dois serviços de produção. Para rollback, parar/remover **somente** `tds-learning-qa-wp-20261017` e `tds-learning-qa-db-20261017`, remover a rede interna `tds-learning-qa-20261017` e decidir separadamente quando apagar o diretório sintético. Não usar `docker system prune`, não reiniciar Traefik e não modificar a base de dados de produção.

O avanço para produção depende de revisão editorial e autorização específica. `MERGE_ALLOWED=NO; WP_PRODUCTION_INSTALL=NO`.
