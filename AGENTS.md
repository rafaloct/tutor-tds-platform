# Tutor TDS — contrato operacional

Ler primeiro `docs/CURRENT_STATE.md`, `docs/DOMAIN_CONTRACT.md`,
`docs/ARCHITECTURE.md` e `docs/DECISIONS.md`. Para qualquer trabalho que
toque mais de um componente, operação permanente, portal, interoperabilidade,
infraestrutura, governança ou continuidade, ler também
`docs/program/README.md` e `docs/program/AGENT_EXECUTION_PLAYBOOK.md` antes
de editar. Depois carregar apenas a feature, seus testes e digest Stitch. Código
descreve implementação; documentos descrevem intenção; Stitch descreve
referência visual, somente após inspeção dos artefatos.

Ao planejar uma mudança, separar explicitamente:
- **OBSERVED**: comprovado no código, teste, serviço ou evidência;
- **TARGET**: arquitetura/comportamento desejado;
- **DECISION**: escolha humana já registrada;
- **UNKNOWN/BLOCKED**: ainda não comprovado ou depende de ação humana.
Nunca promover TARGET para OBSERVED apenas porque foi documentado.

- Manutenção incremental do MVP; não recriar o app. Wave 1 aprovada em staging
  (docs/production/WAVE1_ACCEPTANCE.md). Escopo ativo: Wave 2, Dynamic Learning.
  Preservar os três caminhos aprovados; próxima fatia inicia por contrato/auditoria.
- Preservar produção, assinatura Android, certificados KV, dados e baseline.
- UI → estado/controller → domínio → repository → API autorizada → persistência.
- Não duplicar entidades/tabelas sem buscar equivalentes. Migração aditiva,
  compatível, testada do zero e em staging isolado antes de promoção.
- IA/eventos não concedem autorização, matrícula, frequência ou certificado.
- Cada feature possui contrato, offline policy, teste e linha na matriz.
- Stitch: projeto `3740249934950673416`; cache `.stitch/designs/<screenId>/`
  com screenshot, HTML, metadata e digest. Reutilizar hash local íntegro;
  não baixar todas as telas nem inventar digest de tela não inspecionada.
- Mudanças de risco ficam desligadas por flag até validação. Não promover
  `PRODUCTION_READY` por UI ou teste isolado.
- Testar somente recorte afetado; suíte completa em acceptance gate/release.
  Após duas tentativas do mesmo erro, parar alterações e registrar Observed,
  Expected, Responsible Boundary, Evidence, Likely Root Cause, Affected Files,
  Structural Fix.
- SDK histórico validado: `C:/Users/Usuario/flutter-3.44.9/bin/flutter.bat`;
  executar Flutter pelo junction ASCII `C:/Users/Usuario/.codex/tmp/tutor-tds-context-qa`.
  Não assumir que o SDK do PATH é o mesmo. Python validado com `api/uv.lock`:
  `tmp/context-cloud-locked-env/Scripts/python.exe`; `api/.venv` é histórico.
- Atualizar memória compacta e matrizes ao concluir tarefa. Intervenções externas
  precisam de Reason, Exact human action e What remains unblocked.
- Ordem posterior: Dynamic Learning, Classroom, Pergunta ao Vivo, Certificates,
  Tutor contextual, Media/Vídeo, Creator, Evidence/Reporting,
  Commercial/Entitlements, Production hardening. Não executar em paralelo
  migrações do contrato central.
- Para visão do programa permanente, usar `docs/program/ROADMAP.md`. Issues do
  GitHub devem manter objetivo único, critérios de aceite, testes, dependências,
  human gate, risco e fora de escopo. Nenhum agente deve usar WordPress, Sheets,
  Chatwoot, R2/Drive ou IA como fonte alternativa de autorização acadêmica.


## Coordenação GitHub-first

GitHub é a fila e a memória operacional. Chat/Gmail não substituem Issue, PR,
checks ou comentários persistidos.

Regras padrão para qualquer agente:

- branch canônica de integração: `codex/onda-0-consolidacao`;
- uma tarefa = uma branch/worktree;
- `MERGE_ALLOWED=NO` até autorização humana explícita;
- produção, publicação, migration real e operações destrutivas exigem human gate;
- force-push é proibido salvo autorização humana explícita e específica;
- não iniciar a próxima tarefa automaticamente;
- verificar PRs abertos antes de editar para evitar sobreposição;
- persistir checkpoint no GitHub ao concluir;
- CI verde é evidência técnica, não autorização de merge.

Human gate obrigatório para: produção, secrets/credenciais, billing/provider
pago, permissão/OAuth, operação destrutiva, aprovação legal/editorial/privacidade
ou regra institucional ambígua.

Resposta de human gate deve conter apenas o mínimo necessário:
`HUMAN_GATE=SIM`, motivo, ação humana exata e o que continua desbloqueado.

Ao finalizar, usar checkpoint compacto:

```
TASK_ID=
BRANCH=
PR=
BASE_SHA=
HEAD_SHA=
TESTS=
CI=
MERGE_RECOMENDADO=SIM/NÃO
HUMAN_GATE=
BLOCKER=
PROXIMO_PASSO=AGUARDAR_COORDENADOR
```

Perfis especializados reutilizáveis ficam em `.github/agents/*.agent.md`.
O fluxo completo está em `docs/operations/AGENT_COORDINATION.md`.
