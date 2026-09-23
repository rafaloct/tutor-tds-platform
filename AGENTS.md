# Tutor TDS — contrato operacional

Ler primeiro `docs/CURRENT_STATE.md`, `docs/DOMAIN_CONTRACT.md`,
`docs/ARCHITECTURE.md` e `docs/DECISIONS.md`. Depois carregar apenas a feature,
seus testes e digest Stitch. Código descreve implementação; documentos descrevem
intenção; Stitch descreve referência visual, somente após inspeção dos artefatos.

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
