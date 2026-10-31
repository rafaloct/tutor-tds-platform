# PROPOSTA — Funil CadÚnico + Chatwoot + Bots RAG por material

**Status:** PROPOSTA para aprovação — nada implementado.
**Sessão:** complemento operacional (funil + atendimento + filtragem por IA).
**Princípio do modelo:** o EAD público NÃO vira loja. Aluno elegível CadÚnico
não paga nada — basta **manifestar interesse** para liberar acesso. O portfólio
pago (não-CadÚnico) vive em outro caminho (WooCommerce), sem contaminar o EAD.

---

## 1. Decisão de modelo

| Público | Caminho | Preço | Porta de entrada |
|---|---|---|---|
| CadÚnico (B2G/social) | EAD público | **Gratuito** | Manifestação de interesse → acesso liberado |
| Não-elegível | Portfólio pago | Pago | WooCommerce (fora do EAD) — **não implementar no EAD** |

Elegibilidade CadÚnico = **declaração de interesse + validação institucional**
(não verificação automática de cadastro federal — API do CadÚnico não é pública;
tratar como fluxo de autodeclaração com conferência humana/leve).

## 1.1 Os três canais funcionais (não confundir)

| Canal | Função | O que NÃO faz |
|---|---|---|
| Portal EAD / app | Acesso ao conteúdo (aulas, cartilhas) | não registra presença |
| Instrumento da turma | Registro oficial de atividade presencial | não é atendimento |
| Central de Ajuda (Chatwoot) | Solicitação de apoio | não substitui registros acadêmicos |

O Chatwoot organiza o **terceiro** fluxo apenas — nunca concede matrícula,
frequência ou certificado.

## 2. Funil de aquisição

```
Descoberta (site EAD, WhatsApp, QR, parceiros, campanha)
   └─► Landing do curso/trilha  →  "Quero participar (grátis p/ CadÚnico)"
        └─► Manifestação de interesse: nome + CPF + telefone + município + curso
             ├─► Registro de intenção (nova tabela interest_leads ou n8n lead)
             ├─► Abre conversa Chatwoot (WhatsApp/in-app)
             ├─► Bot RAG responde FAQ do curso (carga, requisitos, certificado)
             ├─► Se elegível (autodeclarado CadÚnico) → provisiona acesso:
             │     conta API + membership + enrollment + wp_user (Opção B)
             └─► Se dúvida/elegibilidade → fila humana (coordenação)
```

Estados do lead: `novo → engajou_bot → interesse_confirmado → acesso_liberado → matriculado → ativo` (+ `handoff_humano`, `inelegível→redirecionar portfólio`).

**Decisões aprovadas (usuário):**
1. **3 canais de interesse**: botão no app + landing por curso + palavra-chave WhatsApp `QUERO + <curso>`.
2. **Validação CadÚnico = humana**: manifestação gera **lead na fila dos estagiários** no Chatwoot — eles verificam, orientam e marcam `elegível` → só então o acesso é provisionado. Nada de auto-grant.
3. **FAQ ~20 por cartilha** gerado para revisão humana (`docs/operations/faq-rag/`).
4. **Embrapa Responde Agro API** como fonte RAG adicional nos cursos agro (`agricultura-sustentavel`, `saf`, `cooperativismo`, `sim-sima`, `economia-lar`) — acesso fornecido pelo usuário na F4.
5. **Oportunidade passiva E ativa**: passiva = inbound (site/app/WhatsApp orgânico); ativa = outbound (campanhas por curso/município, listas de contato via estagiários/broadcast — ver §6).

## 3. Chatwoot — preparação

| Peça | Configuração |
|---|---|
| Inbox WhatsApp | número oficial TDS — mensagem "QUERO + <curso>" dispara funil via webhook n8n; também recebe campanhas ativas (broadcast por estagiários) |
| Fila estagiários | `estagiarios-elegibilidade` — todo `interesse_confirmado` cai aqui: verificam orientação, marcam `elegível` → dispara provisionamento |
| Inbox in-app | já existe `chatwoot_screen.dart` — conectar ao mesmo account com tag `app` |
| Teams | `atendimento-aluno` (humano), `bot-rag` (agente bot por material), `estagiarios-triagem` |
| Autoridade do estagiário | triagem, classificar, responder 1º nível, encaminhar — **nunca** altera matrícula, frequência, certificado ou decisão acadêmica |
| Roteamento por demanda | `dúvida simples→FAQ` · `pedagógica→instrutor` · `agropecuária especializada→encaminhar Embrapa Responde Agro` · `matrícula/frequência/certificado→coordenação autorizada` · `técnica→suporte` |
| Etiquetas | `faq_resolvido` `duvida_pedagogica` `duvida_tecnica_rural` `embrapa_encaminhamento` `suporte_app` `matricula_coordenacao` `certificacao_coordenacao` `retorno_pendente` |
| Uso do FAQ pelo estagiário | identificar→consultar→responder (adaptar linguagem sem alterar sentido)→encaminhar→registrar — não é auto-resposta indiscriminada |
| Atributos | `lead_status`, `curso_interesse`, `elegibilidade`, `cpf_mascarado` |
| Labels | `cadunico`, `faq-resolvida`, `handoff-humano`, `matriculado` |
| Roteamento | bot primeiro; `handoff` por confiança baixa, palavra-chave ou pedido explícito |

## 4. Bots RAG por material

| Componente | Decisão |
|---|---|
| Motor | **AnythingLLM** (containers já em prod/staging) |
| Unidade de RAG | 1 workspace por cartilha/curso (`ws-agricultura`, `ws-ia`, …) — documentos: cartilha PDF+JSON, FAQ gerado, regras da oferta (frequência 70%, certificação) |
| Guarda-chuva | workspace `ws-geral` (metodologia, CadÚnico, "como funciona") para antes do curso |
| FAQ seed | gerar por material: ~20 perguntas (o que é, carga horária, quem pode, certificado, custo=grátis CadÚnico, materiais, prazo) — **revisão humana antes de publicar** |
| Integração | AnythingLLM API → n8n webhook → Chatwoot (bot responde como agente na conversa) |
| Embrapa Responde Agro | **referência de encaminhamento** — equipe identifica a dúvida, verifica material oficial disponível e orienta o canal; NÃO integração técnica garantida nem promessa de resposta |
| Handoff | confiança baixa, fora de escopo, pedido humano, ou 2 falhas seguidas → transfere p/ `atendimento-aluno` com resumo do histórico |

Regras duras do bot (já no prompt): nunca prometer certificado automático;
frequência ≥70% conforme oferta; vídeo/cartilha não comprovam presença;
preço para CadÚnico = sempre gratuito; nunca processar pagamento.

## 5. Provisionamento de acesso (manifestação → liberação)

`POST /interest-leads` (novo endpoint ou n8n→API) → status `interesse_confirmado`:
- Cria `users` (se não existir) + `program_memberships` + `enrollments` no curso pedido
- Aciona Opção B: provisiona `wp_user` projeção (resolve `user-by-phone`)
- Retorna deep link/WhatsApp "seu acesso está pronto — entre com CPF+senha"
- **Tudo feature-flagado** (`FUNIL_CADUNICO_ENABLED`), auditado, idempotente

## 5.1 Funil ativo — controles obrigatórios

Contato iniciado pela equipe exige **antes de qualquer disparo**:
finalidade definida · autorização compatível com o contato · equipe
responsável identificada · registro de cada tentativa · mecanismo de saída
(opt-out). **Proibido disparo indiscriminado.**

## 6. Responsabilidades + campanhas (para o quadro)

| Papel | Responsável por | Mede |
|---|---|---|
| Dono do funil | landing, copy, taxa interesse→acesso | leads, conversão |
| Dono do bot | FAQ por material, confiança do RAG | % resolvido sem humano |
| Atendimento | fila `atendimento-aluno` | SLA 1ª resposta, resolução |
| Instrutor TDS | conteúdo, regras de oferta | FAQ sempre fiel ao material |
| Campanha/curso | quem promove cada trilha/curso | leads por curso/canal |

## 7. LGPD / limites

- CadÚnico é dado sensível-adjacente: coletar **mínimo** (CPF+telefone p/ acesso, município p/ oferta); nunca íntegra do cadastro federal.
- Bot/RAG só recebe material público/curricular — nunca dados pessoais do aluno no prompt/RAG.
- Lead ≠ consentimento de marketing: opt-in separado para campanhas.

## 8. Implementação em fases (gate por fase)

1. **F1** (doc): aprovar modelo + FAQ por material + texto do "manifestar interesse"
2. **F2** (dados): `interest_leads` + provisionamento (staging, flag off)
3. **F3** (Chatwoot): inbox WhatsApp + teams + roteamento bot→humano
4. **F4** (RAG): workspaces + FAQ revisado + n8n bridge
5. **F5** (funil): landing "Quero participar" por curso + deep link de acesso
6. **F6** (métricas): funil → quadro de campanhas
