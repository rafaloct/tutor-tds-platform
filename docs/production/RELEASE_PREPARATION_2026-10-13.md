# Preparação de produção — 2026-10-13 (#197)

## Escopo e decisão

Base: staging `dd928ff6b58788af930aa6722557728d74dfe97c` (PR #194 já
integrado). O usuário informou que Google Analytics do domínio e Cloudflare
bastam para observação geral. A configuração externa não foi verificada nesta
sessão. Firebase do draft #196 fica fora desta candidata.

## OBSERVED

- `tooling/build_production.ps1` usa agora `uv run --locked --extra test
  python -m pytest -q`. A invocação anterior falhou em ambiente novo com
  `ModuleNotFoundError: ops`; a nova instala dependências de teste do lock e
  mantém o diretório da API no caminho de importação.
- API: `uv run --frozen --extra test python -m pytest`: 601 passed,
  30 skipped, 5 subtests passed, três avisos de depreciação.
- Ferramentas de recuperação: 29 testes aprovados, um opt-in não executado.
  Seleção de ambiente/bindings: oito aprovados.
- PostgreSQL descartável 17.11: 30 testes aprovados (lifecycle, certificados,
  presença e operador). Primeira execução em 16.15: 28 passaram e dois
  rejeitaram a versão do servidor; repetição com 17.11 passou integralmente.
  Container com tmpfs e bancos sintéticos removido ao concluir.
- Configuração gerada por `tools/ci/tds_env.py` para `refs/tags/v1.4.0`
  fora do repositório: `ENVIRONMENT_SELECTION=PASS`, sem credenciais,
  endpoints de produção e flags novas desligadas. Não criou uma tag.
- Nenhuma alteração de runtime, migração ou dependência nesta candidata.

## UNKNOWN/BLOCKED — promoção

O verificador real de recuperação, com schema `20261007_0030` e árvore Git
da API candidata, retorna `RECOVERY_EVIDENCE_PROVENANCE=FAIL: acceptance
schema does not match the candidate`. O ensaio histórico de migração de dump
ao vivo não substitui a restauração comprovada do backup agendado offsite.
Não alterar recibos ou booleanos para contornar o gate.

Acesso HTTP ao domínio de produção e download do Dart foram recusados pelo
proxy do workspace (`CONNECT 403`); isso não demonstra indisponibilidade do
serviço. O LARGeo respondeu ao ping e depois retornou ENOENT para o caminho
histórico de Flutter; a descoberta de diretórios ainda estava pendente.
Comandos remotos anteriores expiraram. O SDK local não ficou utilizável.

Permanecem necessários: restauração offsite com proveniência e volumes
críticos, compatibilidade/schema atual de produção, Flutter 3.44.9 com testes,
versionCode publicado verificado, novo AAB com assinatura preservada e
manifesto vinculado ao commit/tag. O artefato histórico está superseded.
Nenhum AAB, tag, deploy, migração de produção ou upload Play foi realizado.

## Continuação operacional

Reason: a promoção depende de evidência real de recuperação e de um ambiente
de build/acesso a produção funcional.
Exact human action: disponibilizar ao operador autorizado o local da identidade
age já custodiada para o restore, sem copiar a chave para chat/Git; confirmar
que comandos do Desktop Commander executam no LARGeo, além do status online.
What remains unblocked: revisão da correção do runner e CI da candidata;
os testes locais não alteram produção nem a assinatura Android.
