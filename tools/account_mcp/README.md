# Tutor TDS — MCP de contas gerenciadas

Candidato da issue #199; base `dd928ff6b58788af930aa6722557728d74dfe97c`.
Branch `codex/managed-account-mcp-20261013`. Objetivo único: adapter de cadastro
via `POST /admin/accounts`, autoridade FastAPI/PostgreSQL existente. Sem
migração, novo cadastro mestre, matrícula ou alteração de assinatura Android.
Ambiente validado: testes locais com HTTP fake e handshake MCP stdio real.
Risco: cadastro com privilégios; operador revisa nome/papel/programa/ambiente.
Credenciais e dados reais ainda não fornecidos; nenhuma conta real criada.

## Contrato

- `preview_account(request_id)` lê um JSON privado preparado pelo operador e
  retorna nome, papel, programa, ambiente e digest; omite CPF, telefone e senha.
- `create_account(request_id, approval_digest)` envia o cadastro exato revisado
  à API. Somente token administrativo válido pode criar a conta. A API valida
  CPF, senha, programa, papel e política de ativação vigente; erros não são
  contornados pelo adapter.
- Origem: cliente MCP local autorizado; destino: API HTTPS fixa staging ou
  production. Autenticação: token de acesso de administrador em arquivo local
  protegido, atualizado pelo operador quando expirar. Não use refresh token.
- Protocolo: SDK MCP 1.x, negociado no initialize; contrato HTTP existente.
  Não recebe URL, token, senha ou caminho arbitrário em argumentos de ferramenta.
- Online only. Timeout 30s. Sem redirects, fallback, retry automático ou fila
  de envio offline. Variáveis de proxy do host continuam respeitadas.
- Recibo privado por request_id é reservado com criação exclusiva ANTES do POST.
  Repetição, concorrência ou reinício não repete esse ID. Resultado incerto
  exige conferir a API antes de qualquer nova tentativa: não mude o ID para
  contornar o recibo. Isto não substitui idempotência no servidor.
- Recibos não contêm CPF/senha/token. Estado `unknown` permanece após falha,
  crash ou resposta inválida. Resultado confirmado registra projeção segura.
- Retenção: operador remove o JSON com senha após conclusão confirmada e
  conserva recibos enquanto o cadastro puder ser reenviado. Não publique
  inbox/recibos/credenciais no Git, chat ou serviço remoto.
- Owner: administrador Tutor TDS. O host local e seus diretórios são confiáveis;
  ferramentas não devem ser compartilhadas com usuários não autorizados.

## Preparação local

Instale `uv` e execute dentro desta pasta:

```sh
uv sync --locked
uv run --locked --extra test python -m pytest -q
```

Crie fora do repositório diretórios privados de inbox e recibos e um arquivo
com o access token do administrador. POSIX: diretórios 0700, arquivos 0600.
Windows: configure ACL permitindo leitura/escrita apenas ao usuário operador;
a checagem de modo POSIX não verifica ACL Windows. Não cole token no chat.

Cada arquivo `<request_id>.json` da inbox contém:

```json
{
  "name": "NOME DA PESSOA",
  "cpf": "CPF VALIDADO PELO OPERADOR",
  "phone": "TELEFONE",
  "password": "SENHA INICIAL DEFINIDA PRIVADAMENTE",
  "role": "student",
  "program_id": "ID DE PROGRAMA EXISTENTE"
}
```

Papéis seguem a API: student, teacher, monitor, creator, coordinator,
program_operator, finance, admin. Revise concessões privilegiadas explicitamente.
Não use esses placeholders como dados de cadastro.

## Codex e Claude Desktop

Substitua os caminhos absolutos do exemplo pelo checkout e pelos diretórios
privados do host. Primeiro valide em staging. Claude Desktop, configuração MCP:

```json
{
  "mcpServers": {
    "tutor-tds-accounts": {
      "command": "uv",
      "args": ["run", "--directory", "/ABS/REPO/tools/account_mcp", "--locked", "tds-account-mcp"],
      "env": {
        "TDS_MCP_ENVIRONMENT": "staging",
        "TDS_MCP_INBOX": "/PRIVATE/inbox",
        "TDS_MCP_RECEIPTS": "/PRIVATE/receipts-staging",
        "TDS_MCP_TOKEN_FILE": "/PRIVATE/admin.token"
      }
    }
  }
}
```

Codex, seção no arquivo de configuração do cliente:

```toml
[mcp_servers.tutor_tds_accounts]
command = "uv"
args = ["run", "--directory", "/ABS/REPO/tools/account_mcp", "--locked", "tds-account-mcp"]

[mcp_servers.tutor_tds_accounts.env]
TDS_MCP_ENVIRONMENT = "staging"
TDS_MCP_INBOX = "/PRIVATE/inbox"
TDS_MCP_RECEIPTS = "/PRIVATE/receipts-staging"
TDS_MCP_TOKEN_FILE = "/PRIVATE/admin.token"
```

Para produção após os gates da release: configure `TDS_MCP_ENVIRONMENT=production`,
`TDS_MCP_PRODUCTION_ENABLED=true`, token da API de produção e diretórios
privados separados. O digest vincula o ambiente; preview staging não aprova
cadastro em produção. A flag habilita o adapter, não atesta prontidão da release.

## ChatGPT e publicação

**Ainda não conectado ao ChatGPT.** Este servidor fornece stdio local; ChatGPT
requer endpoint MCP remoto acessível, transporte HTTP e autenticação compatível
com o cliente. Não exponha este processo em HTTP usando token administrativo
compartilhado. Próxima etapa: gateway autenticado com identidade por operador,
autorização e armazenamento de segredos no servidor, homologação do fluxo de
cadastro e conexão do cliente real. Esse transporte não foi implementado nem
publicado nesta fatia. Codex/Claude também não foram configurados no desktop,
pois o Remote Desktop Commander não conseguiu executar comandos.

A release Android permanece no PR #198. Não houve tag, novo AAB, alteração de
assinatura, deploy da API ou upload Google Play nesta implementação.
