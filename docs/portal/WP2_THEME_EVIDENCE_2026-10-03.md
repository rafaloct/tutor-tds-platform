# WP-2 — evidência local do child theme

Status: **IMPLEMENTED / TESTED-LOCAL**. Staging externo, aprovação editorial e
publicação continuam **UNKNOWN**.

## Escopo implementado

`wordpress/tds-child-theme/` é um child theme do Astra. Ele entrega a camada
visual pública da Issue #42: home, listagens/notícias, busca, 404, cabeçalho,
rodapé, navegação responsiva, patterns e os templates institucionais de
Programa, Acessar, Privacidade, Direitos e exclusão, Acessibilidade e Contato.

O tema só lê `TDS_Public_Config::get()` e a rota REST pública já exposta pelo
`tds-portal-core`. Sem o plugin, ou sem configuração válida, catálogo e acesso
ao app mostram estado explícito de indisponibilidade. Não há endpoint, option,
cadastro, matrícula, progresso, certificado, analytics, suporte remoto ou
chamada HTTP novos no tema.

## Verificação executada em 03/10/2026

Base: `b9028c238c0049b4e728a29ba3a9d6cd9179a28a`.

| Comando | Resultado | Ambiente |
| --- | --- | --- |
| `php -n tests/lint.php` | PASS — 34 arquivos | PHP 8.4.26 NTS, Windows |
| `php -n ... tests/smoke-theme.php` | PASS — 180 assertivas, 0 falhas | WordPress 7.1.2 + Astra 4.13.1 + SQLite descartável, `127.0.0.1` |
| `php -n wordpress/staging/tests/test-wp2-foundation.php` | PASS — 65 assertivas | dublês explícitos de WordPress; contrato do plugin |
| `git diff --check` | PASS | worktree local |

O smoke usa uma instalação marcada como descartável e conteúdo sintético. Ele
verifica status HTTP, templates, única hierarquia `h1`, skip link, `main`
focável, menu expansível, viewport, estados de catálogo/acesso, ausência de
analytics/e-mail/identidades de QA no HTML e degradação com plugin inativo.
O resultado sanitizado está em
`wordpress/tds-child-theme/tests/evidence/smoke-results.json`.

## Correções no harness de QA

O lint agora aplica a varredura de conteúdo distribuível apenas fora de
`tests/`; fixtures precisam conter exemplos inseguros e os próprios padrões de
detecção. O smoke passou a iniciar o listener na origem canônica da instalação
descartável, evitando redirects para uma porta diferente. A limpeza do processo
agora tolera o comportamento de processos já encerrados no PHP para Windows.

## Limites e próximos gates

- Não houve browser visual, Lighthouse, leitor de tela, dispositivo móvel ou
  teste de contraste manual.
- Não houve MySQL, provedor público real, DNS, suporte, analytics, e-mail,
  staging externo, deploy, backup/restore ou produção.
- A configuração de URLs e a integração real com FastAPI dependem da revisão e
  aceite de `tds-portal-core` e da configuração institucional autorizada.
- A branch ainda requer revisão independente, decisão editorial sobre o mapa
  de páginas e gate humano para staging/merge. Rollback de uma instalação
  futura: reativar o tema anterior; o plugin e suas opções permanecem inertes.
