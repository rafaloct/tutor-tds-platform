# Reconciliação Chatwoot/FAQ — v1.4.1 para candidato 1.4.2

## Escopo e referências

- Issue: `#318`
- Base imutável do candidato: `0cda01731b19dce479700770d51d262e94c7b7ab`
- Tag anotada `v1.4.1`, commit alvo: `8eccbbbf9041bf229314c18922c25a71cd7ed861`
- Ancestral comum: `207e2128dcbcedec70bf5132b05a7081501480ed`
- PR `#206`, HEAD observado: `7da52f5db352ba3be8bdf16612866bc38f9e55a8`

O PR `#206` foi tratado somente como referência. Para os 16 arquivos de implementação e teste autorizados nesta tarefa, seu HEAD e o commit alvo da tag `v1.4.1` são byte a byte idênticos.

## Inventário por commit

| Estado | Commit | Efeito no fluxo autorizado |
| --- | --- | --- |
| OBSERVED | `c607754cca67554768fd7d1286708214026da7eb` | Adiciona configuração pública validada no FastAPI em `config.py`, `support.py` e `test_support.py`. |
| OBSERVED | `d5ce2d420b26c4a688e19db0c566852371455996` | Adiciona modelo/repositório de configuração, host isolado mobile/web, lifecycle da tela e os testes correspondentes. |
| OBSERVED | `7293a2ae56942e4e1c2979aadede592e3e150ea4` | Merge da linha de configuração em runtime; segundo parent `d5ce2d4`, sem delta direto adicional nos paths filtrados. |
| OBSERVED | `5fe0b4194d6f7fe4501fedc4a7eb12cab006e973` | Mantém o GET público CORS-safelisted, removendo header que provocava preflight negado. |
| OBSERVED | `3715601621b7952b94d3be5650e204dbc5369246` | Adiciona branding, FAQ offline e fallback acessível na tela de suporte. |
| OBSERVED | `9f6063bc1498341958b88454175928bd90218ed0` | Ajusta os testes widget de FAQ ao ambiente fake-async. |

## Inventário por arquivo

| Estado | Arquivo | Responsabilidade reconciliada |
| --- | --- | --- |
| IMPLEMENTED | `api/app/config.py` | Lê e valida somente URL pública e website token; configuração inválida desabilita apenas `/support/config`. |
| IMPLEMENTED | `api/app/support.py` | Expõe projeção pública mínima com `no-store`; mantém segredo HMAC exclusivamente no endpoint autenticado de identidade. |
| IMPLEMENTED | `api/tests/test_support.py` | Cobre projeção exata, ausência de segredos e validação fail-closed de URL/token. |
| IMPLEMENTED | `cartilhas_app/lib/features/support/chatwoot_config.dart` | Validação defensiva equivalente no cliente para host público e token. |
| IMPLEMENTED | `cartilhas_app/lib/features/support/chatwoot_config_repository.dart` | Novo fetch a cada abertura/reload, sem cache e com falha opaca. |
| IMPLEMENTED | `cartilhas_app/lib/features/support/chatwoot_host_html.dart` | Documento isolado do SDK e ponte de mensagens restrita à origem/sessão. |
| IMPLEMENTED | `cartilhas_app/lib/features/support/chatwoot_mobile_host.dart` | Ciclo WebView mobile, sinais de prontidão/erro, identificação posterior e teardown. |
| IMPLEMENTED | `cartilhas_app/lib/features/support/support_help_sections.dart` | Branding e FAQ estáticos/offline sem autoridade acadêmica. |
| IMPLEMENTED | `cartilhas_app/lib/screens/chatwoot_screen.dart` | Orquestra fetch, consentimento, identidade, timeout, retry, troca de sessão e fechamento. |
| IMPLEMENTED | `cartilhas_app/lib/services/chatwoot_web_impl.dart` | Isola cada abertura web em iframe com lease, callbacks de lifecycle e teardown. |
| IMPLEMENTED | `cartilhas_app/lib/services/chatwoot_web_stub.dart` | Mantém a mesma API nas plataformas não web. |
| IMPLEMENTED | `cartilhas_app/test/chatwoot_config_repository_test.dart` | Cobre fetch/configuração remota e política fail-closed. |
| IMPLEMENTED | `cartilhas_app/test/chatwoot_host_html_test.dart` | Cobre escaping e contrato do host isolado. |
| IMPLEMENTED | `cartilhas_app/test/chatwoot_screen_config_test.dart` | Cobre abertura, reload, timeout, teardown e guardas de autenticação. |
| IMPLEMENTED | `cartilhas_app/test/chatwoot_support_faq_test.dart` | Cobre branding/FAQ e disponibilidade sem nova chamada de rede. |
| IMPLEMENTED | `cartilhas_app/test/chatwoot_web_lifecycle_test.dart` | Cobre lease web, mensagens, falhas, fechamento e reinicialização. |

## Decisão de integração

O candidato não tinha commits próprios após o ancestral comum nos sete arquivos já existentes do fluxo; a linha `v1.4.1`/PR `#206` é a única que os alterou. Por isso a menor reconciliação verificável foi restaurar exatamente os 16 blobs finais da tag, sem cherry-pick, sem tocar nas branches de referência e sem incorporar arquivos fora da allowlist.

O contrato FastAPI entrou porque o candidato não possuía `/support/config` nem os campos/validação usados pelo repositório Flutter. Sem esses três arquivos, o cliente reconciliado falharia de forma permanente.

## Limites de autoridade e segurança

- Chatwoot permanece autoridade apenas da conversa.
- FAQ, clique, conversa e estado `resolved` não concedem matrícula, progresso, frequência ou certificado.
- Nenhuma credencial administrativa ou segredo HMAC foi movido para Dart, HTML, documentação ou logs.
- `cartilhas_app/pubspec.yaml`, `cartilhas_app/release/release_status.json`, assinatura, keystore, AAB, Play, produção e deploy não foram alterados.
- `release_build_allowed` permanece sob o gate do fluxo pai; esta tarefa não o abre.

## Evidência e incerteza

- OBSERVED: os blobs autorizados do HEAD do PR `#206` e da tag `v1.4.1` são idênticos.
- IMPLEMENTED: esses blobs foram aplicados sobre o HEAD exato do PR `#317` em branch/worktree nova.
- UNKNOWN: a igualdade da tag não prova que seus bytes correspondem ao AAB 14 atualmente servido pela Play. A proveniência binária continua no gate do `#197`.

## Testes

- TESTED-LOCAL: `uv sync --frozen --extra test` — concluído com o lock do repositório.
- TESTED-LOCAL: `uv run python -m pytest tests/test_support.py -q` — 71 testes, exit code 0; somente warnings de depreciação de dependências.
- TESTED-LOCAL: `uv run python -m pytest -q` — suíte API completa, exit code 0; testes condicionais foram skipped e não houve falhas.
- NOT_RUN: `flutter analyze` — o executor local não possui Flutter instalado.
- NOT_RUN: os quatro testes Flutter mobile/widget definidos na Issue — o executor local não possui Flutter 3.44.9.
- NOT_RUN: `flutter test --platform chrome test/chatwoot_web_lifecycle_test.dart` — Flutter e navegador não estão instalados localmente.

A suíte Flutter 3.44.9 deverá ser comprovada pelo CI do draft PR; até lá, sua situação é `PENDING`, não `PASSED`.
