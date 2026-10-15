# Integração Drupal — #161 / #166 / #167 / #168

## Contrato e fontes

DECISION: usuário aceitou continuar a rotação TDS e a integração dos fluxos.
Esta branch combina os candidatos, sem promover staging ou produção:

- #207: `7dc395e`, suporte/certificados, mutex e provas MariaDB/core cookie.
- Lifecycle TDS: #207 `0cfa05c`, incorporado ao candidato integrado `72e97d6`.
- #180: `40901a1`, área do participante e evento de limpeza da sessão.
- #181: `f70c8d9`, operações, confirmação humana e comandos idempotentes.
- Base publicada: staging `b0c39b2`, Drupal 11.4.10.

FastAPI permanece autoridade acadêmica. Nenhuma alteração em API, Flutter,
Worker, domínio, credenciais ou dados produtivos. Os módulos não foram instalados
na produção por esta integração; config/sync é apenas o candidato versionado.

## Reconciliação implementada

Preservados GETs do participante, métodos operacionais estritamente allowlisted,
mutex antes de ler a sessão, evento de limpeza e gate produtivo. O cliente mantém
`context_conflict` versus `operation_conflict` para HTTP409 conforme a superfície.
POST não recebe retry de transporte; replay após401 usa o mesmo payload.

Todos os quatro caminhos autenticados compartilham a política de refresh: uma
segunda recusa401/403 limpa tokens e notifica consumidores. Novo subscriber remove
prova de identidade, snapshot e comando operacional pendente ao limpar a sessão.
O subscriber do participante também é preservado. Dados editoriais permanecem.

O gate de produção inclui `/minha-area`, `/operacoes`, `/meus-certificados` e
identidade/frame de suporte, por path e nome de rota, além dos endpoints TDS.
Catálogo, suporte público manual e verificação pública continuam disponíveis.
Sem opt-in booleano explícito, as superfícies privadas retornam403/no-store.

## Evidência antes da integração do lifecycle

Fixture local: PHP8.3.29, Drupal11.4.8, SQLite em memória, rede desabilitada.
104 testes/446 assertions PASS, incluindo Form API real com gateway simulado,
evento de limpeza operacional e recusa de replay nas quatro superfícies.
Lint PASS:57PHP,56PHPCS,129YAML,7Twig. Gate ampliado:69 checks PASS.

O primeiro bootstrap local encontrou scaffold Composer ausente na nova worktree
(autoload e diretório profiles). A fixture foi completada com scaffold existente;
nenhuma mudança de dependências ou de código de negócio decorreu dessa falha.

## Limites e continuidade

Ainda não é aceite #170 nem liberação da autenticação em produção. Primeiro login
do participante sem sessão CMS e obtenção de cookie/CSRF ainda não comprovados.
Os checks TDS abaixo começam com uma sessão editorial. Provas sintéticas não
equivalem a jornada real de usuário no browser,
validação de autorização na API produtiva, SDK Chatwoot real, verificador Worker,
WCAG ou performance. Não usar esta branch como prova de IA: #209 é separado.

Rollback operacional: manter flag produtiva desativada; não remover o mutex como
suposta correção. Não há migração de dados ou criação de entidade acadêmica.

## Ensaio integrado no VPS — 15/10/2026

OBSERVED no código `72e97d6389edcec2379c912f17bb008fe36758aa`, PR #212:
Drupal 11.4.10, PHP8.3.35, MariaDB11.8.9; mesmas imagens PHP/DB do portal.
Banco temporário tmpfs, sem rede Docker, sem portas publicadas, sem volumes ou
credenciais de produção. Cópia isolada das dependências, módulos customizados
substituídos pelo snapshot exato do commit; API e contas sintéticas.

- 112 testes / 467 assertions PASS, incluindo kernel/Form API em SQLite.
- 69 verificações de configuração produtiva PASS.
- 15 verificações concorrentes com processos e MariaDB reais PASS.
- 5 verificações HTTP de refresh concorrente PASS.
- 11 verificações de regeneração/logout nativos Drupal PASS.
- 21 verificações de login/troca de conta/logout TDS PASS: CSRF obrigatório,
  destruição do ID anterior, rejeição dos cookies antigos, falha de login sem
  contexto anterior e preservação da conta editorial.

Runner `test-dr3-http-fixture.sh` com `TDS_SESSION_MUTEX_INTEGRATION=1` habilitou
participante, operador e suporte/certificados na fixture. Isso comprova wiring
e lifecycle integrados; não prova as jornadas acadêmicas reais desses módulos.
Review independente: sem regressão identificada na reconciliação dos contratos.
Consulta CI via watcher bloqueada por GraphQL HTTP403; CI verde não confirmado.
