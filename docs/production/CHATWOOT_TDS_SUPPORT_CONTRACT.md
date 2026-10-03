# Central TDS — contrato candidato de atendimento (CW-0)

Versão proposta 1, 02/10/2026. Complementa `CHATWOOT_TDS_CURRENT_STATE.md`;
não ativa integração, não concede acesso nem aprova lançamento. Fontes de código,
base exata, evidências e limites estão nesse diagnóstico. Decisões abaixo são
propostas para revisão da coordenação; instalação permanece BLOCKED.

## Autoridade e fluxos

Flutter oferece entrada e acompanhamento; Chatwoot guarda conversa, mensagens,
fila, responsável, notas e estado operacional. FastAPI/PostgreSQL resolve vínculos,
autorizações e decisões oficiais. BI recebe projeções minimizadas, nunca transcrição
integral. Dokploy opera serviços e não é interface do participante.

Abrir ajuda ≠ enviar ≠ servidor receber ≠ humano responder ≠ resolver.
Conversa resolvida ≠ presença ≠ capacitação ≠ mentoria realizada ≠ certificado.
Baseline permanece papel → digitação → planilha oficial. Não criar login acadêmico
paralelo, tabela de pessoa/curso/mentoria duplicada ou fork do Chatwoot.

| Assunto | Entrada mínima / contexto | Responsável e desfecho permitido |
| --- | --- | --- |
| Ajuda técnica | Tela, versão/plataforma e erro declarado; contexto acadêmico apenas se pertinente | Monitor orienta; infraestrutura recebe diagnóstico mínimo. Registrar orientação ou encaminhamento, sem crédito acadêmico |
| Dúvida pedagógica | Curso/material/atividade e turma/edição validados | Docente/monitor autorizado; resposta ou pendência pedagógica rastreável |
| Frequência/certificado | Matrícula/turma e referência de pendência, sem baseline integral | Equipe competente encaminha aos domínios existentes; #6 define frequência, #5 emissão. Macro não aprova nem emite |
| Interesse em mentoria | Declaração explícita e breve objetivo voluntário | Triagem; coordenação decide elegibilidade/convite; `MentorshipCase` somente por comando autorizado de `student_followup.py` em fatia futura |
| Dados/conta/privacidade | Tipo de pedido, identidade conferida proporcionalmente ao pedido | Responsável institucional conduz processo; chat não exclui automaticamente nem revela dados de terceiro |
| Ainda não sei | Texto breve opcional | Triagem sem erro ou seleção silenciosa de turma |

Anexo enviado não é `EvidenceItem` validado. Mensagem de interesse não é vaga,
designação ou sessão de mentoria. Sem resposta não significa resultado negativo.

## Contato, atendimento e confiança

Contato: identificador estável assinado pelo backend existente, derivado da pessoa
autenticada e namespace do ambiente. Não gerar HMAC no cliente; segredo somente no
backend/configuração autorizada. Não persistir assinatura em logs, URLs, telemetria
ou screenshots. Nome/contato opcionais dependem de finalidade explícita; consentimento
geral/jornada não autoriza compartilhar tudo. Atendimento necessário e telemetria
opcional têm fundamentos e controles distintos a definir pelo responsável por dados.

Atendimento: referência opaca, ID de conversa, assunto, origem, contrato de contexto,
instituição/programa/membership/matrícula/turma/curso/edição quando aplicáveis,
material/atividade, versão/plataforma, timestamps, responsável/estado e encaminhamento.
São campos propostos, não schema ou atributos nativos já instalados.

Servidor resolve/valida pessoa e vínculos via `resolve_student_context`; seleção
local é intenção, não autorização. Duas turmas exigem escolha explícita ou contexto
válido da origem. Sem vínculo, ajuda técnica/visitante continua disponível sem acesso
acadêmico. Não salvar turma atual no contato e reescrever contexto histórico.
HMAC do identificador não autentica atributos livres do widget. Mapeamento interno
protegido; referências opacas no Chatwoot, apenas dados mínimos para atendimento.

Não enviar CPF/NIS/renda/baseline, senha/token, localização precisa, transcrição de IA,
print automático ou dados de terceiros. Anexo exige ação explícita, aviso, tipo/tamanho,
autorização de download e retenção definidos; fora do primeiro MVP.

## Competências e visibilidade propostas

| Papel | Pode tratar / visualizar | Limite e prova necessária |
| --- | --- | --- |
| Participante | Suas conversas públicas e seus vínculos autorizados | Sem nota interna, dados de outro usuário ou conta de agente |
| Monitor | Triagem e conversas atribuídas no contexto autorizado | Sem aprovação de frequência/certificado/elegibilidade; negativos fora do escopo |
| Docente | Dúvidas/pendências das turmas autorizadas | Sem acesso a turma alheia por papel global ou etiqueta |
| Mentor | Caso formal atribuído e contexto mínimo correspondente | Interesse não concede acesso; validar atribuição no domínio oficial |
| Coordenação | Distribuição, exceções e comandos institucionais autorizados | Fechamento operacional não valida jornada; registrar ator/motivo/revisão |
| Infraestrutura | Diagnóstico técnico sanitizado e administração estritamente necessária | Sem acesso irrestrito a baseline/transcrições por padrão; acesso excepcional auditado |
| Responsável por dados | Solicitações verificadas de dados/conta e processo de retenção | Conferir identidade, tratar sincronização parcial, preservar obrigações institucionais |

Papéis TDS e Chatwoot são distintos. Teams/inboxes/etiquetas/filtros organizam filas,
não provam isolamento. Testar outra conta/instituição/turma, mensagens e notas internas.
Se a instalação não isolar, avaliar accounts separadas ou reduzir escopo; não promover
todos a administrador. Horário, substitutos, prazos e inatividade dependem de aceite;
não prometer atendimento 24h nem fechamento automático por silêncio.

## Compatibilidade, estados e privacidade

- Preservar cliente publicado e manutenção como estados diferentes. Não exigir HMAC
  na inbox legada antes de provar compatibilidade do binário distribuído. Preferir
  homologação isolada; eventual nova inbox exige mapeamento, histórico e reversão.
- Visitante sem login obtém ajuda de acesso sem histórico acadêmico. Passagem para
  conta exige verificação; nunca fundir por nome/telefone. Falha assinada não vira
  identidade de outra pessoa nem fallback autenticado silencioso.
- Reusar reset web; testar logout/exclusão/troca A→B, sessão expirada/refresh, retorno
  assíncrono tardio, aparelho compartilhado e reinstalação. Verificar cookies/storage
  da WebView. Nenhum rascunho/assinatura/mensagem de A pode aparecer a B.
- Sem consentimento opcional, nome/telefone/diagnóstico extra não são enviados;
  ajuda básica permanece. Explicar minimização da identidade necessária sem prometer
  anonimato que o fluxo autenticado não oferece.
- Rascunho local, envio pendente, recebido pelo servidor, em atendimento, aguardando,
  encaminhado, resolvido e reaberto são estados do contrato a mapear aos recursos reais.
  Encaminhado pode ser atributo/equipe, não enum nativo inventado. Ack precede “recebido”.
- Offline: ajuda curta/rascunho somente; sem promessa de chat offline. Persistência
  futura requer dono/API/ambiente/contexto, revalidação de sessão, idempotência e retenção.
  Falha Chatwoot/API tem retry e retorno à atividade; alternativa externa precisa de
  cobertura autorizada e não comprova recebimento pela equipe.
- Excluir User no TDS não prova eliminar mensagens/anexos/contatos no Chatwoot.
  Inventariar retenção, anonimização e obrigações; falha parcial fica pendente,
  com reconciliação segura e sem apagar histórico legítimo no rollback.

## Integrações e métricas futuras

Reusar `/support/identity`, resolver v2 e domínios de certificado/evidence/mentoria.
Antes de propor persistência de referência contato/conversa/encaminhamento, localizar
equivalente no recorte da fatia CW-4; a leitura de CW-0 não prova ausência global.
Mensagens ficam no Chatwoot. API administrativa é servidor-servidor, nunca Flutter,
WordPress, WebView ou logs. Conferir autenticação real de webhook na versão instalada,
sem inventar headers; sem transporte confiável, bloquear ingestão e considerar
reconciliação autenticada. Validar account/inbox/evento/tamanho/origem; deduplicar,
reconciliar ordem/timeouts, evitar loops. Resolvido só muda estado operacional.

Métricas: pedido recebido deduplicado; primeira resposta pública humana (excluir bot
e nota); pendência sem responsável; duração/reabertura; dificuldades por contexto
validado; interesse separado de caso/sessão; satisfação voluntária do suporte.
Definir fonte, denominador, cobertura, janela, timestamps e fuso America/Sao_Paulo.
BI sem texto integral; faltante desconhecido, sem inferir turma ou resultado acadêmico.

## Fatias posteriores e READY/BLOCKED

READY significa que o recorte indicado pode ser preparado; não autoriza ativação.
Paths novos abaixo são propostas; localizar/reusar equivalentes antes de criá-los.

| Etapa | Arquivos-alvo e dependências | Aceite e testes mínimos | Estado |
| --- | --- | --- | --- |
| CW-0 | Estes dois documentos; plano e fontes dirigidas | Fontes, fatos/hipóteses separados, sem segredos/conversas; validação documental | READY para revisão; contrato candidato concluído |
| CW-1 | `cartilhas_app/lib/screens/chatwoot_screen.dart`; proposta `lib/features/support/` controller/model/fake; entrada/rotas existentes a localizar no recorte | Visita sem envio; assunto/contexto; toque duplo; offline/retry; duas turmas; texto ampliado/TalkBack/teclado/retorno; testes fake localizados abaixo | READY somente protótipo offline; ativação BLOCKED |
| CW-2 | `api/app/support.py`, `learning_context.py`; `auth_repository.dart`, web impl, tela/WebView; config apenas em fatia autorizada | HMAC reutilizado; auth/namespace/expiração, A→B, resposta tardia, visitante, consentimento, storage real e publicado; ampliar testes de suporte existentes | READY desenho/testes sintéticos; inbox/publicado BLOCKED |
| CW-3 | Manifesto proposto em `docs/production/chatwoot/`; sem editar configuração real | Inventário versão/licença, competências, macros, horários, substitutos; isolamento com negativos por papel | READY manifesto candidato; aplicação BLOCKED por inventário/coordenação |
| CW-4 | `api/app/support.py`, `student_followup.py`, domínios existentes; models apenas após busca de equivalente | Referência mínima, autorização, replay/ordem/timeouts, webhook falso, inbox alheia, nota interna; testes de learning context/certificado/follow-up/evidence existentes | BLOCKED integração por CW-2/transporte; decisões acadêmicas seguem #5/#6/#7 |
| CW-5 | Projeção API e export existentes a localizar na fatia; contrato/fixtures sanitizadas | Dedup, humano versus bot, turma histórica, faltantes, consentimento e denominador; sem transcrição no BI | READY contrato; integração BLOCKED por CW-4 e política de dados |
| CW-6 | Runbook/ensaio próprio, coordenado com #2; ops existentes só em autorização posterior | Contas sintéticas, mensagem/resposta real, WebSocket/TLS/worker, restore conversas+anexos, escopos, publicado/manutenção e rollback | BLOCKED acesso/homologação/infra; sem deploy nesta sessão |

### Primeiro diff executável de CW-1 (não implementado)

1. Localizar chamadas/rota de `ChatwootScreen` e componentes de contexto somente nessa
   fatia. Acrescentar entrada de cinco assuntos + triagem, resumo corrigível de contexto
   e ajuda textual local, reaproveitando a tela de origem e retorno.
2. Separar UI → controller/estado → interface de suporte. Injetar fake explicitamente
   no protótipo/testes; sem SDK, request, token ou criação de conversa. Não alterar
   `SIGNED_SUPPORT_IDENTITY`, freeze nem rota produtiva para habilitar o protótipo.
3. Estados determinísticos do fake: carregando, pronto, rascunho, pendente, confirmação
   simulada claramente identificada, erro/retry. Enviar somente por ação deliberada;
   trava durante envio evita toque duplo. Rascunho em memória, segregado por sessão,
   descartado em troca/logout; sem outbox persistente nesta primeira fatia.
4. Novo teste proposto `cartilhas_app/test/support_entry_test.dart`: visita não envia,
   duas turmas não escolhem primeira, correção de contexto, toque duplo um comando,
   offline não diz recebido, falha recuperável, visitante e consentimento negado,
   retorno à atividade, texto ampliado/tela pequena. Teste de controller para A→B
   e resposta tardia. Sem repetir suites globais ou E2E histórico.
5. Gate de ativação permanece fechado até CW-2/CW-3/CW-6, revisão de produto e
   comprovação do publicado. Adaptação real reaproveitará widget/serializador/reset;
   protótipo não é evidência de envio real nem aprovação de produção.

## Intervenções e custo

| Motivo | Ação humana exata | Continua desbloqueado |
| --- | --- | --- |
| Cobertura e competência não aprovadas | Coordenação aprova assuntos, responsáveis/substitutos, horário, encaminhamento e política de inatividade | CW-1 fake e manifesto candidato |
| Inventário remoto não autorizado | Infraestrutura concede recorte de homologação isolada e identifica versão/account/inbox sem transmitir segredo em chat | Documentação e testes locais |
| Minimização/retenção/direitos pendentes | Responsável por dados define dados necessários/opcionais, prazo e processo de exclusão parcial | Ajuda local sem dados adicionais |
| Legado/publicado sem prova | Responsável pela release identifica binário publicado e autoriza ensaio sintético de compatibilidade antes de exigir HMAC | Caminho legado preservado |

Nenhuma capacidade foi comprovadamente necessária e indisponível nesta sessão;
portanto nenhum custo/licença é recomendado. Classificar requisitos após inventário
como nativo disponível, integração necessária, dependente de licença ou fora do MVP.
Não contratar Pro/Enterprise/Captain nem habilitar recursos pagos por banco/flags.

STOP: CW-0 termina no PR draft destes documentos. Sem CW-1 implementado, deploy,
merge, infra, flags, migração, AAB ou alteração de dados reais.
