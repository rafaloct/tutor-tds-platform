# Homologação de autenticação e ativação de CPF — staging

Data: 2026-10-04
Ambiente: Tutor TDS staging, API interna do contêiner ativo e PostgreSQL de
staging.
Escopo: ETAPA 1 do plano de operação segura. Nenhuma alteração de código ou de
interface foi feita nesta homologação.

## Método e segurança dos dados

- Foi usada a conta administrativa já gerenciada pelo ambiente exclusivamente
  para emitir convites de teste.
- Os CPFs foram sintéticos, válidos e gerados apenas para a execução; nomes de
  conta traziam o prefixo identificável `QA CPF Activation 20261004`.
- Tokens, CPFs, senhas, IDs, cabeçalhos de autorização e valores de variáveis
  não foram impressos nem gravados neste relatório.
- Ao final, a conta QA foi excluída pelo seu próprio `DELETE /auth/me`; os dois
  convites e o bucket de rate limit criados na rodada foram removidos pelo
  procedimento de limpeza restrito aos seus digests/chave.

## Resultado

| Endpoint | Cenário | Esperado | Obtido | Status |
| --- | --- | --- | --- | --- |
| `POST /auth/login` | Administrador de staging autentica para emitir convite | `200` | `200` | aprovado |
| `POST /auth/activation-invites` | Admin emite convite para CPF QA | `201` | `201` | aprovado |
| `POST /auth/register` | CPF correspondente usa o convite uma vez | `201` | `201` | aprovado |
| `POST /auth/register` | Mesmo convite tenta ativar um segundo CPF após o uso | `403` | `403` | aprovado |
| `POST /auth/activation-invites` | Admin emite convite para outro CPF QA | `201` | `201` | aprovado |
| `POST /auth/register` | CPF sem correspondência usa convite de outro CPF | `403` | `403` | aprovado |
| `POST /auth/login` | Aluno recém-ativado entra | `200` | `200` | aprovado |
| `GET /auth/me` | Access token recém-emitido acessa rota protegida | `200` | `200` | aprovado |
| `POST /auth/logout` | Logout revoga `sid` e refresh token no servidor | `204` | `204` | aprovado |
| `GET /auth/me` | Mesmo access token após logout | `401` | `401` | aprovado |
| `POST /auth/login` | Onze tentativas inválidas para o mesmo CPF/IP, na mesma janela | 10 × `401`, 11ª `429` | 10 × `401`, 11ª `429` | aprovado |
| Alembic no contêiner `tutor-tds-staging-api-staging-1` | Migração aplicada | `20261003_0026 (head)` | `20261003_0026 (head)` | aprovado |

## Lacunas e limites desta evidência

1. A chamada foi feita pela rede interna do contêiner. Ela comprova o contador
   persistido no PostgreSQL e a política da API, mas não substitui uma medição
   de proxy/WAF por um dispositivo externo.
2. O fluxo ainda não foi executado pelo aplicativo Flutter: o cadastro não
   possui, nesta revisão, o campo para informar o código de ativação. Isto é o
   próximo escopo autorizado (ETAPA 02), não uma falha da API homologada aqui.
3. Esta rodada não valida isolamento offline, troca de contas nem autorização
   por perfil; esses itens permanecem nas ETAPAS 03 e 04.
