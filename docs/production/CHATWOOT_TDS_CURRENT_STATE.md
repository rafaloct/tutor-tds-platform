# Chatwoot TDS — estado atual CW-0

Diagnóstico dirigido em 02/10/2026 (America/Sao_Paulo). Documento candidato;
não representa aceite da coordenação nem PASS de produção. Escopo encerrado
em CW-0, sem implementação, dados reais ou inspeção administrativa do Chatwoot.

## Proveniência e preservação

- Base: `origin/codex/onda-0-consolidacao`, SHA
  `0e34aa37ff2b1b8911f0e0841b184370507063ca`, conferido pela API GitHub nesta sessão.
  O tracking local apontava ao mesmo SHA; não foi usada uma referência histórica.
- Principal: branch `codex/onda-0-consolidacao`, HEAD igual à base; única pendência
  observada `Cloudflare_Bindings_Explorer/` não rastreada, preservada.
- Checkout auxiliar consultado: `agent/issue-3-preflight-20261002`, HEAD
  `b8bf822ae1a1bbbc4bf235a4293ba630cf6814ee`, tracking homônimo, árvore limpa.
- Nova branch `codex/cw-0-support-contract-20261002`, worktree exclusiva `cw-0`.
  Os dois documentos de saída não existiam na base. Nenhum documento central,
  arquivo sincronizado, evidência histórica ou checkout anterior foi alterado.
- Plano de entrada: `PLANO_CHATWOOT_TUTOR_TDS_CODEX.md`, seção 14 (prompt integral),
  recuperado do anexo da conversa de referência; `/mnt/data` não é o filesystem
  deste host. CW-0 a CW-6 são etapas, não números de Issues.

## Evidências no código

Todas as fontes abaixo pertencem ao SHA da base; leitura não equivale a execução.

| Fonte / símbolo | Fato comprovado | Limite / reaproveitamento |
| --- | --- | --- |
| `cartilhas_app/lib/screens/chatwoot_screen.dart`, `ChatwootScreen` | SDK web ou HTML em WebView; origem genérica; abertura na inicialização; erro/retry; alternativa externa na UI web | Sem assunto/contexto por atendimento neste recorte. Abrir widget não prova criação/recebimento de conversa. Não copiar identificadores públicos ou contato externo para este diagnóstico |
| Mesmo arquivo, `_getSupportContactId`, `_resolveSupportId` | Caminho legado persiste ID aleatório local; caminho assinado consulta AuthRepository | ID legado não comprova pessoa nem separação entre contas/dispositivos. Falha assinada leva a erro, sem fallback silencioso |
| `services/chatwoot_web_impl.dart`, `chatwootClose` | Limpa callback tardio, fecha e chama reset; reabertura atualiza identidade antes de abrir | Reutilizar; teste simulado não comprova cookies/storage reais. Mobile não apresenta limpeza explícita equivalente no recorte |
| `services/chatwoot_web_stub.dart` | Stub sem operação nas plataformas não web | Mobile usa WebView na tela, não este stub como transporte |
| `services/chatwoot_script_value.dart` | JSON com escape de delimitadores HTML e separadores Unicode | Já existe proteção de interpolação; não recriar |
| `api/app/support.py`, `support_identity` | Autenticação; identidade deriva de `claims.sub` + namespace; HMAC SHA-256; no-store/no-cache; configuração ausente/inválida retorna 503 | Não recebe pessoa arbitrária nem perfil. Assinatura do identificador não valida atributos de contexto do navegador |
| `config/app_config.dart` | `SIGNED_SUPPORT_IDENTITY` opt-in, false na ausência de define; comentário exige inbox e QA de troca de conta | Existência não comprova valor do binário publicado nem configuração instalada |
| `features/auth/data/auth_repository.dart`, `authorized`, `supportIdentity`, `logout` | Confere geração/dono antes e depois das requests; refresh; timeout; formato de assinatura; sem cache de assinatura; logout avança geração | Preservar estas barreiras; ciclo real tela/widget/conta exige QA próprio |
| `services/privacy_preferences.dart` | Chaves geral/jornada; leitura dependente de flag; tela condiciona nome/telefone ao consentimento | ID ainda é resolvido; negar consentimento não implica anonimato total. Finalidade necessária versus opcional precisa de decisão explícita |
| `api/app/learning_context.py`, `resolve_student_context` | Confere matrícula/vínculo ativos, turma, edição, programa/oferta e linhagem; expõe contexto v2; consulta de equipe tem autorização | Reusar resolver. Permissões de aprendizagem não concedem automaticamente direitos de suporte |
| `api/app/models.py` | Institution, Program, Classroom, CohortMembership, ClassEnrollment, CertificateRequest/Reference, EvidenceItem, ClassCheckin, ReviewDecision, MentorshipCase/Revision existem | Não duplicar entidades. Request aprovada, check-in, anexo ou caso fechado não substituem decisão acadêmica |

## Contratos e divergências

`AGENTS.md` exige leitura dos compactos `docs/CURRENT_STATE.md`,
`docs/DOMAIN_CONTRACT.md`, `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`: concluída.
O usuário limita a saída a dois documentos novos; por isso memória/matrizes centrais
não foram editadas. `docs/production/TDS_MEASUREMENT_CONTRACT_V1.md` mantém
baseline papel → digitação → planilha oficial, separa pessoa/matrícula/edição,
produção de evidência e validação, e preserva desconhecidos como null.

CURRENT_STATE contém notas históricas sobre ausência de remote e CLI. A consulta
GitHub atual comprova repositório/tracking e supera essas notas apenas quanto à
proveniência observada. Seu registro de manutenção `1.4.0+13` e produção histórica
`1.2.0+11` não comprova a versão hoje distribuída na Play. Nenhum gate de release
ou flag foi promovido. O contrato alvo de domínio não prova implantação integral.

## Frentes concorrentes (GitHub consultado nesta sessão)

| Registro | Estado observado / efeito sobre CW-0 |
| --- | --- |
| Issues #3 e #5; PRs #12 e #14 | Issues OPEN, PRs MERGED. Integrações parciais não encerram preflight/release nem emissão API→Worker/KV |
| Issue #2; PRs #19 e #11 | Issue OPEN; backups agendados relatados, alertas por e-mail pendentes; PRs OPEN. Restauração TDS/Dokploy não prova restore de Chatwoot/anexos. Não tocar SMTP, backup, R2 ou Dokploy |
| Issue #20 / PR #21 | OPEN; proposta de gitleaks incremental com redaction. Não incorporar workflow/config nem ampliar exceções nesta sessão |
| Issues #6, #7, #8 | OPEN; frequência, mentoria longitudinal e follow-up mantêm seus próprios contratos/gates |

Fontes: [#2](https://github.com/rafaloct/tutor-tds-platform/issues/2),
[#3](https://github.com/rafaloct/tutor-tds-platform/issues/3),
[#5](https://github.com/rafaloct/tutor-tds-platform/issues/5),
[#21](https://github.com/rafaloct/tutor-tds-platform/pull/21).
São registros de outras frentes, não novos testes de instalação.

## INSTALADO / hipóteses / decisões / bloqueios

**Fato comprovado na instalação nesta sessão: nenhum.** Inventário remoto BLOCKED:
não foi fornecido acesso administrativo autorizado para este recorte; não procurar
secrets. URL em código e registro histórico de SMTP não comprovam saúde atual.

| Inventário a obter em homologação autorizada | Evidência mínima / responsável |
| --- | --- |
| Versão, edição, licença e capacidades | Build identificado; APIs de conta/cliente/plataforma e limites; infraestrutura |
| Account/inbox e widget legado/publicado | Mapeamento sanitizado, identidade/HMAC, canais e histórico preservado; infraestrutura |
| Agentes, teams, permissões e isolamento institucional | Matriz testada com contas sintéticas, negativos de outra turma/inbox/conta e notas internas; coordenação + infraestrutura |
| Automations, macros, horários, substitutos e roteamento | Export/manifesto sanitizado, cobertura aprovada, efeitos colaterais identificados; coordenação |
| Workers, WebSocket, SMTP/TLS, anexos/storage, retenção e backups | Ensaio/restauração específica do Chatwoot e canal alternativo; infraestrutura, coordenada com #2 |
| Webhook e APIs disponíveis | Autenticação real suportada, eventos, account/inbox permitidos, repetição/ordem; backend |

Hipóteses a testar: contexto de suporte reaproveitável do resolver; segregação
real do widget mobile; compatibilidade do publicado com assinatura; capacidades
nativas suficientes. Não declarar vazamento, isolamento ou recurso ausente sem prova.

Decisões de produto propostas: cinco assuntos + triagem, envio deliberado,
ajuda offline com rascunho e autoridade acadêmica preservada. Bloqueios humanos:
coordenação define cobertura, competências, encaminhamento, nomenclatura;
responsável por dados define minimização/retenção/direitos; infraestrutura libera
homologação isolada e inventário. CW-1 simulado continua desbloqueado.

## Testes localizados e validação de CW-0

- API: `api/tests/test_support.py` (auth, configuração, pessoa ignorada na query,
  HMAC, namespace e cache); `test_learning_context.py`, `test_context_access_revocation.py`,
  `test_certificate_requests.py`, `test_certificate_reference_context.py`,
  `test_evidence.py`, `test_student_followup.py` localizados para fatias futuras.
- Flutter: `cartilhas_app/test/support_identity_test.dart`,
  `chatwoot_script_value_test.dart`, `chatwoot_web_lifecycle_test.dart` (browser,
  SDK fake); `auth_repository_test.dart`, `journey_privacy_preferences_test.dart`
  e testes de learning context/certificados/evidence/follow-up localizados.
- Não rodar suíte funcional para documentação. Validar somente os dois arquivos:
  diff --check, revisão de escopo e scanner incremental com valores redigidos.
  Resultado efetivo pertence ao PR; testes existentes não foram repetidos.
- TESTE LOCAL: validações documentais apenas. STAGING: não executado.
  INSTALADO: BLOCKED. PRODUÇÃO: não verificada, sem PASS.

Contrato e primeiro recorte executável: `CHATWOOT_TDS_SUPPORT_CONTRACT.md`.
