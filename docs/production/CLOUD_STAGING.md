# Staging gerenciado — FastAPI Cloud + Supabase

Configuração de staging da Wave 1. O pacote local e a allowlist Android possuem
evidências próprias; deployment e jornada completa exigem validação específica.
Escopo autorizado: hospedar a API existente no FastAPI Cloud e seu PostgreSQL
em um projeto Supabase de staging isolado. Flutter continua usando a API;
login, autorização, tabelas, Alembic e contratos de domínio permanecem existentes.
Supabase Auth, Storage e Realtime não fazem parte desta migração de hospedagem.

## Identidade confirmada no provedor

Verificação do painel em 2026-09-23:

| Recurso | Identidade |
| --- | --- |
| FastAPI Cloud app | `dfd6d736-4da8-4586-b9de-1f08aa94d82e` |
| FastAPI Cloud team | `f659d528-141d-49cd-964b-e4be3b275757` |
| URL atribuída ao app | `https://tutor-tds-staging.fastapicloud.dev` |
| Região da API | `us-east-1` |
| Novo projeto Supabase staging | `lgtphbbpgqnzduhtyate` |
| Região do banco | `sa-east-1` |

Atribuição de URL não comprova que exista um deployment saudável. API e banco
estão em regiões diferentes; medir latência antes de concluir ganho de desempenho.
O projeto Supabase anterior permanece fora deste experimento.

A allowlist Android de debug e o instalador de desenvolvimento aceitam somente
essa URL e a rota anterior
`https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`. Ambos exigem ambiente
`staging`, HTTPS e igualdade entre `TUTOR_API_URL` e `TUTOR_STAGING_API_URL`.
Outro subdomínio FastAPI Cloud não é aceito. O pacote `.dev`, a assinatura e as
regras/congelamento de release permanecem preservados.
Verificação: `evidence/cloud-android-environment-gates.json` registra quatro
casos Gradle reais e oito do instalador; os demais casos da matriz Gradle não
foram executados. Nenhum APK/AAB foi produzido por essa verificação.

## Entradas de build e runtime

| Entrada | Configuração |
| --- | --- |
| Raiz do upload CLI | `api/` |
| Entrypoint | `[tool.fastapi] entrypoint = "app.main:app"` |
| Python | `.python-version`: `3.13`, mesma série do Docker validado |
| Dependências | `pyproject.toml`; faixa atual preservada, extra `fastapi[standard]` acrescentado para CLI/build Cloud |
| Build Cloud | instalação nativa Python; o Dockerfile existente continua servindo VPS/local |
| Arquivos enviados | `app/`, `migrations/`, `pyproject.toml`, `.python-version`, `alembic.ini`, lockfile se existir |
| Excluídos | virtualenv, testes, scripts operacionais, arquivos locais de banco, secrets, exemplos `.env`, Docker/compose |
| Processo | API; não iniciar `sync_worker` ou integração Sheets neste staging |
| Liveness / DB | `/live` / `/health` existentes |

`.fastapicloudignore` restringe o upload ao necessário, inclusive quando o
diretório for preparado fora do checkout Git. Nunca copiar secrets para `app/`.
O extra `standard` não altera rotas nem substitui o servidor atual; verificar
a resolução das dependências no build antes de aprovar o candidato. `uv.lock` fixa o runtime existente e as ferramentas novas; instalação isolada
Python 3.13.9 passou em 281 testes. Confirmar uso do lock nos logs do build Cloud.
O Docker legado ainda usa pip/pyproject; não confundir seu build com o lock Cloud.

O primeiro deploy CLI deve enviar somente `api/` com diretório da aplicação
vazio na configuração remota. Se futuramente vincular o monorepo inteiro via
GitHub, configurar **Application Directory = `api`** e revisar a política de
upload na raiz. Não misturar `deploy api/` com diretório remoto também `api`.

## Recursos e isolamento

1. Inspecionar times/apps FastAPI Cloud e projetos Supabase antes de criar.
2. Selecionar/criar um app explicitamente identificado como staging e um projeto
   Supabase sem dados reais. Registrar IDs e região na evidência, sem senhas.
3. Manter produção e o staging VPS existente enquanto o candidato é validado.
   Não apontar o aplicativo publicado para o candidato.
4. Manter a Data API do Supabase desativada para este projeto, ou retirar o schema
   transacional dos schemas expostos. Acesso a estas tabelas passa pela FastAPI;
   grants/RLS precisam de verificação explícita antes de qualquer exposição.
5. Escolher conexão direta PostgreSQL quando a rede disponibilizar IPv6; caso
   contrário, usar o **session pooler**, porta 5432, informado pelo painel
   Supabase. Não usar transaction pooler para Alembic nesta primeira migração.

A integração oficial requer OAuth da conta Supabase e a senha do banco para
anexar o projeto ao app. Guardar os valores no mecanismo de secrets do provedor;
nunca em histórico de comandos, documentos ou chat. Uma chave Supabase anon/
publishable/service-role não substitui a senha PostgreSQL e não é necessária
no Flutter neste desenho.

## Configuração do candidato

| Variável | Valor/critério |
| --- | --- |
| `DATABASE_URL` | URL PostgreSQL do projeto de staging, com TLS e driver psycopg3; ver compatibilidade abaixo |
| `JWT_SECRET` | Secret novo, aleatório, pelo menos 32 caracteres; exclusivo deste staging |
| `CPF_PEPPER` | Secret novo, aleatório, pelo menos 32 caracteres; exclusivo deste staging |
| `PUBLIC_API_BASE_URL` | Base HTTPS canônica real retornada pelo FastAPI Cloud, sem credenciais ou query |
| `ALLOWED_ORIGINS` | Origens web exatas de QA, ou vazio para o teste Android nativo |
| `LEARNING_CONTEXT_ENABLED` | `true` somente no candidato isolado após migration/preflight |
| `PAYMENT_ADAPTER` | `disabled` |
| `COMMERCIAL_SIMULATION_ENABLED` | `false` |
| `CERTIFICATE_APPROVAL_REQUIRED` | `true` |
| `GOOGLE_SHEET_ID`, credenciais Google/IA/Chatwoot | Ausentes; nenhuma integração com produção |

O driver instalado é `psycopg` 3. Uma configuração explícita compatível usa
`postgresql+psycopg://` e preserva usuário, senha codificada, host, porta e banco
fornecidos pelo Supabase. `normalize_database_url` em `app/database.py` normaliza
URLs nativas `postgresql://`/`postgres://` para esse driver; o Alembic usa a
mesma função. A normalização preserva credenciais/query e não acrescenta TLS.
Não instalar psycopg2 para contornar esse problema. Exigir TLS na URL
(`sslmode=require` no mínimo); a verificação completa de CA/hostname pode usar
o certificado fornecido pelo Supabase. Não desativar TLS para resolver rede.

## Predeploy: migração única antes do servidor

Não existe um hook `prestart` configurado neste pacote. O fluxo usa Alembic
como etapa explícita, uma vez por candidato, antes do deploy. Rodá-lo em cada
startup faria múltiplas instâncias/autoscaling concorrerem pela mesma migração.
Não há `create_all()` novo nem migração executada durante import de `main.py`.

Na raiz `api/`, com a URL exclusiva de staging injetada no ambiente da sessão:

```powershell
# O valor de DATABASE_URL deve vir de um secret; não digitá-lo em comandos salvos.
# Inspecionar o destino real e confirmar que pertence ao projeto staging antes.
.venv/Scripts/python.exe -m alembic current
.venv/Scripts/python.exe -m alembic heads
.venv/Scripts/python.exe -m alembic upgrade head
.venv/Scripts/python.exe -m alembic current
```

Qualquer falha encerra o predeploy. Não enviar novo código para um banco com
migration incompleta. Em banco vazio, todas as migrations devem executar.
Se a base já contiver dados, executar o preflight contextual existente e guardar
backup/evidência antes do upgrade. A migração 0019 é aditiva; não remover vínculos,
eventos ou colunas legadas para facilitar o primeiro deploy.

Seed deve criar somente usuários sintéticos e a turma/edição do gate. O helper
`ops/seed_context_android.py` mantém a validação de banco próprio da VPS e aceita
o novo projeto Supabase somente com argumento explícito. Injetar
`TUTOR_ENVIRONMENT=staging`, `DATABASE_URL`, `QA_STUDENT_PASSWORD` e
`QA_TEACHER_PASSWORD` por secrets e executar, ainda em `api/`:

```powershell
.venv/Scripts/python.exe -m ops.seed_context_android --approved-supabase-project lgtphbbpgqnzduhtyate --preflight-only
.venv/Scripts/python.exe -m ops.seed_context_android --approved-supabase-project lgtphbbpgqnzduhtyate
```

O guard exige projeto/host/usuário corretos, TLS, banco `postgres`, schema na
revision Alembic atual e ausência de usuários. Se falhar, diagnosticar; não
remover a proteção. Nunca executar contra o projeto anterior. Não importar
credenciais nem dados pessoais reais.

## Deploy reproduzível

Executar a CLI por um ambiente de ferramentas separado, com
`fastapi[standard]`, enquanto o runtime de QA continua preservado. Os comandos
abaixo usam `fastapi` desse ambiente. Consultar `--help` da versão instalada
antes de ações; preferir JSON. Substituir IDs pelos retornados pelo provedor.

```powershell
fastapi cloud whoami --json
fastapi cloud teams list --json
fastapi cloud apps list --team-id <TEAM_ID> --json
fastapi cloud apps get <STAGING_APP_ID> --json
# Com working directory = api/, após predeploy e secrets configurados:
fastapi cloud deploy . --app-id <STAGING_APP_ID> --json
fastapi cloud deployments get <DEPLOYMENT_ID> --app-id <STAGING_APP_ID> --json
```

Se ainda não houver app, criar/linkar somente o staging aprovado. Autenticação
de usuário/OAuth pode exigir ação humana; não requer compartilhar senha no chat.
Envio aceito não significa deploy bem-sucedido: acompanhar até estado terminal;
em falha, preservar ID, mensagem e build logs sanitizados. Não criar integração
GitHub/autodeploy ou tokens de CI enquanto esse candidato não estiver validado.

## Validação e promoção

Registrar app ID, deployment ID, projeto Supabase, região, revisão/source hash,
versão de Python/dependências, revision Alembic, flags e data na evidência.
Não guardar connection strings, tokens, CPFs reais ou passwords.

1. HTTPS: `/live` e `/health`; `/health` deve consultar o PostgreSQL real.
2. Contrato: OpenAPI do candidato comparado com a API existente.
3. Autorização: login sintético; contexto do aluno; rejeição de outra turma;
   instrutor permitido lê a mesma matrícula e o mesmo progresso.
4. Persistência: atividade, evidência e progresso sobrevivem ao reinício do app.
5. Offline: fila durável, reconexão e replay sem duplicata.
6. Android: usar a URL HTTPS identificada acima em arquivo de defines exclusivo
   para o candidato. A allowlist do build de desenvolvimento já contém essa
   identidade; não aceita qualquer host/HTTP. Health e gate seguem obrigatórios.

As três jornadas da Wave 1 permanecem obrigatórias. Não declarar
`PRODUCTION_READY`, publicar AAB ou substituir a produção por sucesso de build,
healthcheck ou teste isolado. Medir tempos HTTPS/DB nesse candidato para avaliar
o ganho; hospedagem gerenciada não comprova melhora por si só.

Rollback do experimento: manter/restaurar o build `.dev` apontando ao staging
anterior; preservar dados e evidências cloud para diagnóstico. Não fazer
downgrade destrutivo do banco como rollback da API. O app publicado permanece
no destino atual durante todo o experimento.

## Fontes verificadas em 2026-09-23

- [Migrar projeto existente](https://fastapicloud.com/docs/getting-started/existing-project/)
- [Entrypoint](https://fastapicloud.com/docs/builds-and-deployments/configuring-fastapi/)
- [Python e dependências](https://fastapicloud.com/docs/builds-and-deployments/install-dependencies/)
- [Arquivos de upload](https://fastapicloud.com/docs/builds-and-deployments/fastapicloudignore/)
- [Migrations com deploy gradual](https://fastapicloud.com/docs/builds-and-deployments/database-migrations/)
- [Integração Supabase](https://fastapicloud.com/docs/integrations/supabase-integration/)
- [Diretório da aplicação](https://fastapicloud.com/docs/builds-and-deployments/application-directory/)
- [Conexões PostgreSQL Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [Proteger a Data API](https://supabase.com/docs/guides/api/securing-your-api)
