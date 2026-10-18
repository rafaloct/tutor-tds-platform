# F3b | Controlador de leitura da Minha Área EAD (Issue #265)

**Status:** IMPLEMENTED e TESTED-LOCAL com fonte sintética injetada. **Não implementa SSO, HTTP real, login LearnPress ou consulta de conta produtiva.**
**Base:** PR #263 (tela F3a) empilhado sobre PR #260 (política de ações F2); arquitetura aprovada na ADR PR #250/Issue #249.
**Coordenação:** Devin mantém PR #261 F0b MariaDB; seus runners e credenciais sintéticos NÃO pertencem a esta fatia.

## Objetivo único

Entregar uma fronteira read-only e testável entre **uma futura sessão LearnPress verificada por broker** e o view model `EadMyAreaPreview`. O controlador não faz chamadas HTTP, não inventa matrículas/progresso e não interpreta um token WP/LP como identidade institucional TDS. O LearnPress continua sendo autoridade das ações EAD; FastAPI é autoridade de turmas, frequência e certificados oficiais.

## Interfaces e contratos

| Elemento | Fonte / obrigação | Resultado |
|---|---|---|
| `EadSessionProof` (PR #260) | Fornecido pelo broker futuro: WP user id, ambiente, emitido/expira, `brokerVerified`. Prova curta, no máximo 15 minutos. | Sem prova válida, nenhuma consulta; login institucional sozinho não serve |
| `EadMyAreaReader.read(proof)` | Interface injetada, não implementação REST | Futuro adaptador deve comprovar usuário e autorização no servidor |
| `EadAccountReadSnapshot` | wpUserId, environmentId, observedAt, origin verificada e cursos do usuário | Respostas de diretório público ou de outra conta são rejeitadas |
| `EadMyAreaController` | ChangeNotifier com geração para requisições concorrentes | Exibe estados corretos, limpa cache em logout/switch e ignora respostas tardias |
| `EadMyAreaPreview` (PR #263) | Tela read-only que não integra a Home | Renderiza somente dados verificados e diferenciados de TDS |

A flag `authenticatedLearnPressOrigin` é apenas um **campo de contrato** que deve ser marcado por adaptador confiável após verificar conta e sessão no backend; NÃO é prova criptográfica caso algum outro componente possa preenchê-la livremente. A autorização final é sempre a da API e a política F2, não o widget.

## Invariantes de segurança

- **Nunca** usar `/learnpress/v1/users` público para demonstrar quem está autenticado, nem armazenar ou repassar JWT LP na UI. O token LP observado (7 dias) não é equivalente à prova curta do futuro broker.
- Antes de publicar cursos: `snapshot.wpUserId == session.wpUserId`, `environmentId` igual, origem declarada autenticada, timestamp não futuro, observação posterior à verificação da sessão e lista consistente (IDs positivos e únicos, títulos válidos, progresso 0–100 ou nulo).
- `null` em progresso significa desconhecido; 0% só é mostrado quando o LMS retorna explicitamente zero. Falha HTTP/401/403 nunca vira matrícula negada, 0% ou certificado.
- Nova consulta cancela apresentação dos dados anteriores. Chamadas antigas são ignoradas por geração; troca A→B e logout limpam a lista imediatamente. Erro de autorização requer novo login; falha de rede exibe erro sem vazamento.
- Offline pode exibir apenas snapshot **em memória** que tenha sido anteriormente verificado para a mesma conta e ambiente, dentro do prazo e com sessão válida. O botão “Continuar aula” fica desativado. Não persistir dados privados no dispositivo nesta fatia.
- `EadMyAreaReader` **não** possui comandos de inscrição, quiz, conclusão, certificação ou outro POST. A política de ações do PR #260 continua em ramo distinto e precisa de comprovação de MySQL e permissão real antes de integração.
- Nenhum evento de cartilha ou vídeo vira presença, nota ou conclusão institucional. A UI mantém “Meus cursos EAD” e “Meus certificados TDS” em áreas separadas.

## Sequência futura, ainda TARGET

```text
Login institucional Tutor TDS (FastAPI) e consentimento
  -> autenticação LearnPress segura comprovada pelo broker
  -> EadSessionProof curta e escopada
  -> EadMyAreaReader implementado no backend/adapter homologado
  -> GET autenticado, sessão vinculada e snapshot validado
  -> Controller.refresh / EadMyAreaPreview
  -> ações solicitadas só sob EadLearnerActionPolicy do PR #260
  -> comando LP autorizado + recibo + refetch canônico
```

Nenhuma dessas etapas de rede é implementada por este PR. O status “source verified” nunca deve ser obtido a partir de ID de curso público do crosswalk #257.

## Como testar

```bash
cd cartilhas_app
flutter test --no-pub test/ead_my_area_controller_test.dart test/ead_my_area_preview_test.dart
flutter test --no-pub test/ead_my_area_controller_test.dart test/ead_my_area_preview_test.dart test/ead_learner_action_policy_test.dart
flutter analyze --no-pub lib/features/ead_account test/ead_my_area_controller_test.dart test/ead_my_area_preview_test.dart
```

Testes com `Completer` cobrem requisições sobrepostas, resposta A depois do logout/entrada de B, login/403, fonte não autenticada, curso duplicado, progresso inválido, dados stale, offline, sessão que expira enquanto aguarda rede, descarte do ChangeNotifier, e widget atualizado antes/depois da resposta. UI responde a estado de carregamento e erro sem expor cursos.

## Dependências, status e gates humanos

- **OBSERVED:** F0b no MariaDB sintético via PR #261 registrou paridade dos contratos e quiz aprovado após corrigir fixture. Há revisão de segurança do runner pendente, e isto não comprova produção.
- **IMPLEMENTED LOCAL:** apenas `EadMyAreaController` e ajustes pequenos de apresentação. Sem rede/backend/SSO/Flutter Home.
- **TARGET:** broker confiável com prova recente das duas contas, consentimento, revogação, isolamento A/B/ambiente, rota WP real auditada, E2E staging, testes de acessibilidade e emulador. Só depois reavaliar os assets aprovados #255/#259 e conectar a tela à navegação.
- **BLOCKED:** definição de protocolo de federação e autorização humana para qualquer escrita em staging, merge, instalação WP ou release oficial.

**MERGE_ALLOWED=NO. PRODUCTION_ALLOWED=NO. FORCE_PUSH_ALLOWED=NO.** Não gerar APK ou AAB a partir desta fatia isolada nem chamar Minha Área de funcional em produção.
