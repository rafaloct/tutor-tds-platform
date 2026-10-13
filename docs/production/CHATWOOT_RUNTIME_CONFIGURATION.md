# Configuração remota do Chatwoot — Issue #205

## Contrato e compatibilidade

O aplicativo consulta `GET /support/config` na API configurada ao abrir ou
recarregar o atendimento. A resposta 200 contém exatamente `base_url` HTTPS e
`website_token`, identificador público do widget. A rota não exige login, não
recebe parâmetros e não retorna credenciais administrativas, HMAC ou dados
pessoais. Respostas 200 e 503 usam `Cache-Control: no-store` e `Pragma: no-cache`.
Configuração ausente ou inválida retorna 503 genérico, sem impedir as demais
rotas da API de iniciar.

O cliente não persiste a configuração nem usa token compilado como fallback.
Falhas mostram nova tentativa e a alternativa de atendimento existente. O
estado de abertura depende da confirmação do SDK; carregar o HTML sozinho não
comprova que o widget abriu. Fechamento e troca de conta invalidam callbacks
anteriores. As regras existentes de consentimento e identificação permanecem;
`SIGNED_SUPPORT_IDENTITY` continua false na configuração desta release.

Nenhuma migration, tabela, autorização acadêmica ou flag de risco é acrescentada.
Apps antigos continuam usando seu widget compilado; esta alteração não corrige
retroativamente esses binários. Não exigir HMAC na inbox legada durante o rollout.

## Preparar e conferir a API

No ambiente privado do operador, configure `CHATWOOT_BASE_URL` com a origem
HTTPS do serviço e `CHATWOOT_WEBSITE_TOKEN` com o token público da inbox WebWidget.
Os templates versionados deixam os dois valores vazios. Não usar um token de
agente, administrador, Platform API ou segredo de verificação de identidade.
Preservar JWT, CPF pepper, conexão do banco e as demais variáveis existentes.

Antes de recriar somente o serviço API, guardar cópia protegida da configuração
e identificar a imagem anterior. Aplicar o procedimento de promoção e recuperação
do repositório; não reiniciar banco, Chatwoot ou outros serviços por essa mudança.
As variáveis são carregadas no início do processo: salvar o arquivo sem recriar
a API não aplica os novos valores.

Depois da promoção, verificar `health`, `version` e a rota pública. A inspeção
abaixo imprime apenas o resultado dos controles, sem o token:

```python
import requests

base = "https://ead.ipexdesenvolvimento.cloud/tutor-api"
response = requests.get(base + "/support/config", timeout=15)
response.raise_for_status()
config = response.json()
assert set(config) == {"base_url", "website_token"}
assert config["base_url"].startswith("https://")
assert config["website_token"]
assert response.headers.get("Cache-Control") == "no-store"
assert response.headers.get("Pragma") == "no-cache"
print("SUPPORT_CONFIG_VALID")
```

Validar em ambiente QA próprio que o widget inicia e uma conversa sintética é
recebida. Saúde HTTP e token aceito não comprovam resposta humana ou cobertura
de atendimento. O teste não deve enviar mensagens a pessoas reais nem usar
usuários/contas acadêmicas para simular atendentes.

## Trocar o token sem reconstruir o app

1. Obter o token público correto da inbox WebWidget autorizada; conferir a origem
   HTTPS e preservar histórico, permissões e configuração de identidade da inbox.
2. Atualizar somente as duas variáveis públicas na configuração privada da API.
3. Recriar somente o serviço API com a imagem aprovada e conferir os controles
   acima, a saúde, o schema e a compatibilidade com os apps suportados.
4. Fechar e reabrir o atendimento ou usar a opção de recarregar no aplicativo.
   Uma sessão que já abriu pode manter a configuração anterior até essa ação.
5. Em caso de falha, restaurar os dois valores anteriores e recriar a API.

Não é necessário novo AAB para mudanças nesses valores nos apps que implementam
este contrato. Mudanças de código ou de protocolo do SDK seguem exigindo release.

## Evidência e limites

IMPLEMENTED/TESTED-LOCAL: rota e validação pública com 100 testes focais; contrato
OpenAPI aditivo, com 134 operações e nenhum contrato comum removido/alterado.
Documentação gerada e exemplos conferidos offline. A execução na Play, o AAB da
nova candidata e a promoção desta configuração devem ter recibos próprios;
não são inferidos desses testes nem dos artefatos históricos de `v1.4.0`.

OBSERVED em 13/10/2026: instalação Chatwoot 4.17.0, serviço web saudável e worker
em execução. Uma conta WebWidget isolada, sem usuários/atendentes ou integrações,
recebeu duas mensagens HTTP; uma resposta criada em Rails foi lida pelo widget.
O verificador de limpeza retornou NoMethodError; consulta independente confirmou
todos os registros próprios removidos e saúde200. Não houve repetição de deletes.
[Recibo e limites](evidence/chatwoot-candidate-20261013T225559Z-7abf62f5/chatwoot-functional-http-qa.json).
Isso não comprova resposta humana, WebSocket ou widget Android dentro do AAB.
A configuração desta candidata ainda não foi promovida na API produtiva.
Restores de PostgreSQL e
AnythingLLM anteriores não comprovam backup específico de conversas/anexos do
Chatwoot. Referências: [contrato de suporte](CHATWOOT_TDS_SUPPORT_CONTRACT.md),
[matriz da API](API_MATRIX.md) e [API completa](../api/README.md).
