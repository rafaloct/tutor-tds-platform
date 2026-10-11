# Plano de execução — #138 → #139 → #140 (ciclo de vida da turma)

> Documento para o próximo agente. Redigido 2026-10-10 na branch
> `codex/rc-reconverged-20261009` (PR #194). Ler `AGENTS.md`,
> `docs/CURRENT_STATE.md`, `docs/DOMAIN_CONTRACT.md` e os corpos
> completos das issues antes de qualquer edição.

## 0. Estado da plataforma ao iniciar

- Staging íntegro ponta-a-ponta: app → Worker `tutor-tds-gateway-staging`
  → túnel `tds-ai-staging` → AnythingLLM isolado → OpenRouter dedicado.
- EAD staging autenticável; contas sintéticas existem
  (run `54a5b5f81dfd112ca1cb08bdff35a4a6`: student/teacher/monitor em
  `staging-qa-program`; ledger privado no VPS).
- Harness de E2E determinístico (`7626402`, `af0b5ba`) e gate Android
  corrigido (`a80aca6`) já na branch.
- Produção congelada: nenhuma mutação sem gates de tag/evidência.

## 1. Ordem e dependências

```text
HUMAN_GATES (seção 2)          #139 pode avançar ANTES com fake gateway
        │
        ▼
#138  CLASS_LIFECYCLE_API   ──►  #139  CLASS_LIFECYCLE_APP  ──►  #140  E2E
(backend, migrations, contrato)   (Flutter, capability-driven)      (prova)
```

- **#138 primeiro**: define o contrato (capabilities, transições, campos
  aditivos). Sem ele, #139 só avança contra fake gateway — o que a própria
  issue permite e é o caminho recomendado para paralelizar.
- **#140 por último**: consome os dois HEADs; o harness pode ser escrito
  antes, mas a execução final exige os dois fronts estáveis.

## 2. HUMAN GATES a coletar ANTES de codificar autorização

Perguntar ao titular (não inventar):

- **CLASS_AUTHORITY**: quem cria/ativa/encerra turma no app?
  `program_operator`? `coordinator`? `teacher`? combinação?
- **CAPACITY_POLICY**: hard cap de 30 ou alerta suave?
- Registrar cada resposta como DECISION em `docs/DECISIONS.md` e no corpo
  da issue correspondente.

Enquanto os gates não chegam: #139 avança 100% com fake gateway
capability-driven (nunca presumir papel global local).

## 3. #138 — backend (ciclo de vida da turma)

Escopo mínimo aditivo:

- `Classroom` + campos aditivos: `offer_municipality`, `offer_location`
  (estruturado; NUNCA misturar com município de residência do participante).
- Serviço/contrato de lifecycle: `planned → active → closed` com
  ator + motivo + idempotência/CAS + auditoria contextual.
- Endpoints de readiness/ativação/encerramento respeitando a autoridade
  decidida no HUMAN_GATE; cross-program/cross-institution → denied.
- Equipe (professor/monitor) via `ClassMonitor`/entidades existentes.
- CourseVersion travada após início; fechamento não fabrica certificado
  nem infere frequência.

Verificação mínima: testes de transição (válida/inválida/idempotente),
migração aditiva testada do zero, sem rota admin paralela.

## 4. #139 — app (wizard preparar/encerrar)

- Gateway interface + fake gateway com capabilities parametrizáveis.
- Wizard em 6 passos conforme issue (onde → formação → quando → equipe →
  participantes via fluxo existente → revisão). Nada de ID técnico como
  ação principal; servidor decide capacidades.
- Superfície "Encerrar turma" orientada por readiness (sessões abertas,
  pendências, certificados) com aviso de que encerrar ≠ emitir certificado.
- Reusar `ManagementWorkspaceScreen`/`ClassroomDashboard`/Operations.
- Testes: widget/controller para loading/error/denied/capability.

## 5. #140 — E2E da jornada

- Compor worktree isolado sobre os HEADs de #138/#139; dados 100%
  sintéticos; `TARGET_MACHINE=avellaria`, sem mutação em staging nem merge.
- Provas obrigatórias da issue (oferta≠residência, cross denied, version
  pin, QR≠presença, offline/reconnect sem duplicar presença, certificado
  bloqueado sem gate institucional).
- Atenção ao conhecimento novo desta rodada: em AVD, o serviço de autofill
  do emulador trava InputConnection no login —
  `adb shell settings put secure autofill_service null` antes do E2E
  (evidência em `docs/production/evidence/cloudflare-staging-chain-20261010.txt`
  e CURRENT_STATE 2026-10-10).
- Saída no formato exigido (`E2E_*` + `BLOCKER` + `NEXT`).

## 6. Riscos e fora de escopo

- Não recriar entidades; procurar equivalentes antes de cada tabela/campo.
- Não editar app/API de produção para fazer teste passar.
- Certificado emitido ≠ aprovado — emissão institucional segue bloqueada.
- IA/Drupal/WordPress fora de escopo neste recorte.

## 7. Definition of done

- #138: contrato+migração+testes+doc atualizado; gates respondidos.
- #139: wizard capability-driven, testes focais verdes, sem regra de
  autorização hardcoded.
- #140: jornada completa reproduzível em worktree isolado com evidências
  sanitizadas e `NEXT` registrado.
