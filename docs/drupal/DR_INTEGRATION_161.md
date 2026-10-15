# Integração Drupal — #161 / #166 / #167 / #168

## Contrato e fontes

DECISION: usuário aceitou continuar a rotação TDS e a integração dos fluxos.
Esta branch combina os candidatos, sem promover staging ou produção:

- #207: `7dc395e`, suporte/certificados, mutex e provas MariaDB/core cookie.
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

Ainda não é aceite #170 nem liberação da autenticação em produção. Resta executar
o conjunto com lifecycle TDS integrado no runtime11.4.10/MariaDB11.8.9 e registrar
o SHA exato. Provas sintéticas não equivalem a jornada real de usuário no browser,
validação de autorização na API produtiva, SDK Chatwoot real, verificador Worker,
WCAG ou performance. Não usar esta branch como prova de IA: #209 é separado.

Rollback operacional: manter flag produtiva desativada; não remover o mutex como
suposta correção. Não há migração de dados ou criação de entidade acadêmica.
