# Piloto editorial de IA — preparação (#208)

Status: **IMPLEMENTED / TESTED-LOCAL preparação e backend desativado; dependências auditadas em fixture**. IA desativada;
`pilot-plan.json` é plano validável, **não configuração lida pelo Drupal**.
Não há chamada de modelo, provider instalado no portal ou botão de IA.
Quota e transporte estão implementados no módulo candidato desativado, não ativos no portal.

Atualização15/10: resolução/instalação oficial em fixture11.4.10 concluídas;
manifest/lock preservados em [dependency-audit](dependency-audit/README.md).
Revisão encontrou incompatibilidades de logging/transporte/controle de acesso
com o piloto. Contrib continua desabilitado; adapter TDS mínimo implementado em
[tds_editorial_ai](../../web/modules/custom/tds_editorial_ai/README.md), commit03dec58.
12 testes/249 assertions Unit+Kernel PASS em PHP8.3.35/Drupal11.4.10 na fixtureVPS
networknone/SQLite, além da fixture local11.4.8. Sem UI ou ativação; próximos gates
são browser/privacidade, quota multiprocesso/lease, handler/deadline e custódia/custo.
O histórico de bloqueio de rede abaixo foi superado somente na fixture do VPS.

## Auditoria e escolha

- Base `staging` `207e2128dcbcedec70bf5132b05a7081501480ed`;
  branch `agent/drupal-editorial-ai-pilot-20261015`; issue #208; parent #161.
- DECISION do usuário: reaproveitar o provedor do Tutor se compatível.
- OBSERVED no repositório: `docs/CURRENT_STATE.md:920` documenta staging com
  OpenRouter + `google/gemini-2.5-flash-lite`; recibo
  `docs/production/evidence/critical-volume-restore-20261013T151344Z-5a4bc102.json`
  registra provider OpenRouter. Não comprova configuração remota hoje.
- TARGET: fornecedor/modelo documentados, credencial **editorial por ambiente**,
  diferente da chave/workspace acadêmicos. Endpoint candidato
  `https://openrouter.ai/api/v1/chat/completions`, via servidor.
- Worker Tutor recebe `{message, context}` e devolve `{text}`; AnythingLLM usa
  workspace, prompt pedagógico e RAG. Não são endpoint OpenAI-compatible.
  Reutilizar fornecedor não significa encaminhar textos editoriais ao Tutor.
- Fonte de verdade afetada: Drupal editorial apenas. Arquivos: esta pasta,
  preflight/testes, CURRENT_STATE e matriz. Nenhuma alteração em Flutter/API,
  sessão compartilhada, compose, composer.json/lock ou config/sync.

## O que a receita faz

Aplicação **manual** em fixture/staging previamente autorizado:

- instala somente módulos core necessários a CKEditor5;
- cria formato `tds_editorial_pilot` com parágrafo, negrito, itálico e link;
- restringe HTML e não oferece upload, source editing ou scripts;
- cria papel `tds_editorial_pilot`, não administrador, com **uma** permissão:
  usar o formato; não atribui esse papel a usuários;
- preserva formatos/papéis existentes e workflow `draft → review → published`;
- não habilita AI/Agents/Search/Automators, não cria credencial, não usa rede.

O formato pode ser usado onde uma conta tenha permissão para editar texto.
O módulo candidato fiscaliza notícias/FAQ no servidor; como está desabilitado,
não há fiscalização de IA ativa no portal. A receita continua somente preparatória.
Não atribuir acesso ao piloto com IA ativa até implementar/testar esse recorte.

```sh
# Na pasta drupal/web de um site de testes já instalado.
php ../vendor/bin/dr recipe ../pilots/editorial-ai/recipe
# Na pasta drupal.
vendor/bin/drush php:script pilots/editorial-ai/tests/verify-preparation.php
```

A receita usa `strict: true`: reaplicação idêntica funciona; configuração
incompatível existente causa falha, não sobrescrita silenciosa.
A receita não é executada por instalação normal/CI/deploy deste PR.

## Plano original de integração (não proteção ativa no portal)

- Apenas ações manuais de resumo, revisão ortográfica e tom em português.
- Seleção explícita de texto editorial; sem anexos, históricos, ferramentas,
  sessão TDS, LearningContext, certificados, mensagens de atendimento ou PII.
- Modelo único; sem descoberta aberta de catálogo ou fallback de modelo.
- Proposta inicial: até 4.000 caracteres de entrada, 512 tokens de saída,
  10 chamadas por editor/hora e concorrência 1. **Implementação candidata testada com fakes:** limites server-side e quota.
  Validar concorrência multiprocesso/lease, handler HTTP e orçamento antes de ativar.
- Credencial via Key com provider Environment/gerenciador externo e referência
  `TDS_EDITORIAL_OPENROUTER_API_KEY`. Não criar Key com valor em configuração,
  não copiar segredo do Tutor e não exportar valores ao Git/browser.
- Desabilitar captura de prompt/resposta; observar somente operação, modelo,
  duração, contagem de tokens/custo e erro sanitizado. Retenção e logs upstream
  ainda exigem conferência. Texto gerado sempre passa por revisão humana.
- Timeout/quota/erro: preservar texto original e oferecer edição manual;
  sem retry automático que duplique custo; sem publicação automática.

## Histórico da seleção — antes da resolução isolada de 2026-10-15

| Pacote | Candidato | Evidência/limite |
| --- | --- | --- |
| drupal/ai | 1.5.1 | release estável; declara Drupal ^10.5 ou ^11.2 |
| drupal/ai_ckeditor | 1.4.3 | projeto separado; estável; declara Drupal ^10.4 ou ^11 |
| drupal/key | 1.22 | estável; declara Drupal11 |
| drupal/ai_provider_openrouter | 1.1.6 | candidato sem cobertura de security advisories Drupal; revisão de código obrigatória antes de uso real |

Na preparação inicial, esses números eram seleção para análise. A resolução
transitiva e instalação em PHP8.3/core11.4.10 foram comprovadas depois na fixture
[dependency-audit](dependency-audit/README.md); o portal não instala esses pacotes.
Não selecionar beta/dev nem reduzir minimum-stability para contornar conflito.
Em ambiente com acesso oficial ao repositório de pacotes, próximo executor deve
resolver em branch isolada e revisar diff completo do lock, advisories e schemas:

```sh
composer require --dry-run 'drupal/ai:1.5.1' 'drupal/ai_ckeditor:1.4.3' \
  'drupal/key:1.22' 'drupal/ai_provider_openrouter:1.1.6'
```

Não habilitar módulos ou gravar exports AI com schemas presumidos. Após resolução,
instalar em fixture, inspecionar permissões/rotas/logging/chamadas do provider e
exportar configuração real. O recipe core deste PR não se transforma em piloto
ativo apenas ao instalar contrib: falta integração e provas abaixo.

## Preflight offline

Requer Python3.10+ e PyYAML (ambiente validado: PyYAML6.0.3). Não lê variáveis de
ambiente/secrets nem acessa rede. Valida plano desativado e workflow versionado,
consulta pins em composer.lock e imprime somente códigos sanitizados.

```sh
python scripts/editorial-ai-preflight.py
python scripts/editorial-ai-preflight.py --require-dependencies
python -m unittest discover -s scripts/tests -p 'test_editorial_ai_preflight.py' -v
```

- Exit0: plano de preparação seguro; **não significa IA funcional**.
- Exit1: plano/lock/workflow inválido ou não verificável.
- Exit2 com `--require-dependencies`: pacotes ausentes/divergentes no lock.
- `activation_ready` é sempre false. Ferramenta não aprova deploy e não comprova
  instalação física, segurança de dependências ou execução de um modelo.

## Evidência local

- PHP8.3.29, Drupal11.4.8 e lock original preservado; dependências core copiadas
  do fixture anterior do mesmo SHA/lock, sem baixar ou habilitar contrib AI.
- Instalação do config existente em SQLite3.46.1 isolado: PASS. Para fixture,
  cópia de config/sync em `/tmp` troca somente mysql por sqlite em core.extension;
  config versionada permanece intacta. Produção MariaDB não foi testada.
- Aplicação/reaplicação da receita: PASS; schemas de editor/formato/papel válidos.
- **25 checks Drupal PASS:** acesso anônimo negado, papel mínimo, papéis originais
  intactos, módulos AI desabilitados, revisão/publicador preservados, XSS filtrado.
- **9 testes Python PASS**, incluindo 17 variações de política insegura, entrada
  malformada, versões conflitantes e impossibilidade de promover readiness por flags.
- PHPCS do teste PHP e `git diff --check`: PASS.
- Revisão independente da preparação original: sem achados substantivos; aquele
  plano não implementava quotas. O backend candidato posterior está descrito acima.

## Histórico do bloqueio de rede e próximo passo atual

**Observed:** downloads oficiais packages.drupal.org/ftp.drupal.org e Git
 git.drupalcode.org retornam HTTP403 no proxy deste ambiente. Tentativa de mirror
 GitHub não encontrou os tags (404). Não contornado com mirror não verificado.
**Expected:** resolução Composer autenticada por TLS e inspeção do código real.
**Responsible boundary:** rede de execução/dependências contrib.
**Likely root cause:** allowlist do proxy.
**Affected files:** composer.json/lock e exports contrib ainda não alterados.
**Structural fix:** executar a resolução em ambiente com acesso aos hosts oficiais,
validar e trazer o lock/código revisado. Nenhuma mudança de infra de produção.

Resolução/instalação isolada e revisão focal provider/CKEditor foram concluídas.
Backend de bundle/entrada/saída/quota e transporte sanitizado implementado e
testado com fakes no módulo desativado. Permanecem BLOCKED para ativação:
quota multiprocesso/perda de lease, handler HTTP/deadline total, revisão dos
caminhos AI Framework/SDK caso usados, seleção-only e ausência de PII/logs no
browser, credencial editorial, orçamento/retenção e teste real em staging.

Reason para intervenção futura: provider/credencial/custo reais não disponíveis
nesta preparação. Exact human action: custodiar credencial editorial por ambiente
no gerenciador autorizado e definir teto monetário quando houver candidato
instalado/revisado. What remains unblocked: UI/seleção com fake, testes isolados
de concorrência e revisão do handler. Não pedir/colar chave no chat.

Rollback do fixture: retirar papel dos usuários (nenhum é atribuído pela receita).
Antes de remover formato/editor, migrar qualquer conteúdo que passe a referenciá-lo;
não apagar um formato usado. Não desinstalar CKEditor5 compartilhado por outros
formatos. Mudanças core são opt-in; este PR não altera o runtime existente.

MERGE_ALLOWED=NO; PRODUCTION_ALLOWED=NO. #208 continua aberta.

## Fontes primárias

- https://www.drupal.org/project/ai
- https://www.drupal.org/project/ai_ckeditor
- https://www.drupal.org/project/key
- https://www.drupal.org/project/ai_provider_openrouter
- https://openrouter.ai/docs/quickstart

Referência de avaliação: artigo Specbee fornecido pelo usuário. Releases e
contratos foram confrontados com as fontes primárias, não tratados como comandos.

## Conferir o artefato sem confundir com runtime

```sh
python scripts/editorial-ai-preflight.py --audit-lock pilots/editorial-ai/dependency-audit/composer.lock --require-dependencies
```

Resultado observado:10 testes Python PASS; pins do audit lock PASS;
`dependency_scope=audit_lock`, `activation_ready=false` e bloqueio explícito
`isolated_dependencies_not_installed_in_runtime`. Sem `--audit-lock`, o preflight
continua mostrando que contrib não está no lock principal. O marcador de revisão
pendente exige revisão da implementação escolhida; relatório focal não aceita o provider.
