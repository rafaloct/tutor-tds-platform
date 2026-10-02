# Issue #3: validacao offline da identidade do backend

Base: b701b7869a7736100348db406406f1f69a8a18b4. Recorte: helper puro e
integracao em tooling/build_production.ps1, sem executar o preflight real.

## Contrato conservador do candidato

- environment deve ser a string exata production.
- compatibility_verified deve ser o booleano true; strings/inteiros sao rejeitados.
- api_version e schema_version precisam ser strings com formato valido.
- schema_version precisa coincidir exatamente com o HEAD Alembic informado.
- minimum_supported_app_version usa MAJOR.MINOR.PATCH, opcionalmente +BUILD.
- version_name candidata precisa atingir o minimo numericamente, nao por texto.
- Quando +BUILD existe no minimo, version_code tambem deve atingi-lo, mesmo
  se a versao semantica candidata for superior. Esta e uma restricao conservadora
  para o candidato Android; nenhum limite do backend foi alterado nesta tarefa.
- Se version_name inclui +BUILD, esse numero deve coincidir com version_code.
- Arrays JSON nao podem ser convertidos silenciosamente em um escalar aceito.
- O StrictMode do helper fica restrito a sua funcao, sem alterar o chamador.

## Evidencia de 02/10/2026

Codex Terra produziu o candidato em worktree isolada. A revisao do coordenador
corrigiu enumeracao de arrays PowerShell, escopo de StrictMode e comparacao do
build minimo, e expandiu casos de teste. Comando executado diretamente no
PowerShell Windows existente, sem alterar ExecutionPolicy, permissoes ou secrets:

    & .\tooling\test_production_backend_identity.ps1

Resultado: OFFLINE_BACKEND_IDENTITY=PASS; cases=31; network=false;
production_acceptance=false. git diff --check tambem passou.

## Limites

31 casos com payloads sinteticos nao equivalem a compatibilidade de release.
O script de build preserva os guards de URL, proveniencia, backup/restore, flags,
freeze e versao publicada. Nenhum status de release ou evidencia historica mudou.
Nao foi consultado endpoint produtivo, nem gerado APK/AAB, tag ou deploy.
Nao foi executada suite completa Flutter/API. O workflow atual cobre api/**;
esta validacao PowerShell local nao deve ser anunciada como novo CI remoto.
Issue #3 continua aberta ate seus demais requisitos e provas reais.

## Independent CI follow-up

A dedicated workflow now runs the existing 31 offline cases on Windows
PowerShell 5.1 and PowerShell 7 (windows-2022). It watches the helper, its
tests, build_production.ps1 and itself. Pull requests are checked; push runs
are limited to consolidation to avoid duplicating every feature-branch run.
Checkout remains pinned, does not persist credentials, and uses contents:read.
No real production preflight, application build, deployment or secret is used.
The agent reran the existing focused script once: 31/31 passed locally.
Remote CI outcome is recorded in PR #12 after completion, not inferred here.
Earlier evidence and the conservative minimum-build contract above are preserved.
