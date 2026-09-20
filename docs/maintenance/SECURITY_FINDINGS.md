# Tutor TDS — Achados de Segurança

> **Onda 0 — Auditoria Técnica**
> Data: 2026-09-19
> Agente: Antigravity

---

## Legenda de Severidade

| Símbolo | Nível | Descrição |
|---|---|---|
| 🔴 | Crítico | Risco imediato de exposição de dados ou comprometimento |
| 🟠 | Alto | Deve ser resolvido antes de escalar a plataforma |
| 🟡 | Médio | Importante, pode ser resolvido na onda correspondente |
| 🟢 | Baixo | Melhoria defensiva sem urgência imediata |
| ✅ | OK | Proteção confirmada e adequada |

---

## Achados Confirmados

### ✅ CPF não armazenado no servidor de certificados

O número do CPF é convertido em HMAC-SHA256 antes de ser gravado no Cloudflare KV.
O CPF não aparece no PDF, no QR Code nem na página pública de verificação.

**Evidência:** `cloudflare/tutor-tds-gateway/src/index.js` linha 118
```js
const claimDigest = await hmacSha256Hex(env.CERTIFICATE_SIGNING_SECRET, `claim|${cpf}|${courseId}`)
```

---

### ✅ Chaves do modelo não estão no APK

O app Flutter não contém `ANYTHINGLLM_API_KEY`, `OPENAI_API_KEY` nem nenhuma chave de modelo.
Todas as credenciais de upstream permanecem exclusivamente no Cloudflare Worker (secrets gerenciados pelo Wrangler).

**Evidência:** `lib/config/app_config.dart` — apenas as URLs públicas do gateway e da API.

---

### ✅ Keystore Android não versionado

O arquivo `android/upload-keystore.jks` existe no diretório mas está (e deve continuar) fora do controle de versão.

**Status do `.gitignore` Flutter:** contém exclusões para `*.jks`, `*.keystore` e `key.properties`.
**Status do novo `.gitignore` raiz do monorepo:** ✅ adicionado na Onda 0.

---

### ✅ HTTPS obrigatório para emissão de certificados

O `CertificateService` valida que a URL do gateway começa com `https://` antes de qualquer requisição.

**Evidência:** `lib/features/certificates/data/certificate_service.dart` linha 59
```dart
if (base == null || base.scheme != 'https' || base.host.isEmpty) {
  throw const CertificateException('Serviço de certificados não configurado.');
}
```

---

### ✅ Consentimento LGPD antes de analytics

O `AppTelemetryService` verifica `PrivacyPreferences.hasConsent()` antes de
persistir qualquer evento de uso. Se negado, o evento é ignorado.

---

### ✅ Validação de integridade do certificado no cliente

O Flutter recalcula o SHA-256 do payload canônico do certificado e compara com o hash recebido do servidor antes de aceitar e salvar o registro.

---

### ✅ Analytics não envia CPF ao Google Apps Script

O emissor legado `DataSyncService` e sua variável de build foram removidos.
Eventos autenticados aceitam apenas IDs técnicos tipados e rejeitam texto livre,
nome, telefone, CPF e campos extras. O Apps Script permanece apenas como artefato
histórico, sem chamada pelo aplicativo.

---

### ✅ Autenticação server-side para eventos e analytics

Eventos usam access token e a API deriva a identidade do JWT, sem aceitar
`user_id` enviado pelo cliente. Consultas agregadas aplicam o escopo de aluno,
professor, monitor, turma e administrador.

---

### ✅ CPF removido do SharedPreferences

O CPF local passou a usar `flutter_secure_storage`, apoiado pelo
keystore/keychain da plataforma. A leitura executa migração única da chave
legada `user_cpf` e só a remove depois que a gravação protegida conclui.

O fluxo de suporte deixou de usar CPF como identificador do Chatwoot; utiliza
um identificador aleatório local sem dado pessoal. Exclusão de conta também
apaga o valor protegido.

**Evidência:** `lib/features/profile/data/profile_data_store.dart` e
`test/profile_data_store_test.dart`.

---

### ✅ Webhook legado desconectado do aplicativo

A URL e o emissor foram removidos do build Flutter. A API Tutor TDS autenticada
é a fonte primária de eventos e analytics.

---

### 🔴 Log Docker de aproximadamente 235,9 GB

**Risco:** O log JSON do container `kreativ-postgres` ocupa a maior parte do disco e já causou falha do `logrotate` por falta de espaço.

**Ação necessária:** janela controlada para preservar amostra, identificar a origem, configurar rotação Docker e somente depois reduzir o arquivo com autorização.

---

### 🟠 Serviços administrativos e de dados publicados

**Risco:** UFW inativo, política INPUT permissiva e portas como 3000, 3001, 8090 e 11434 publicadas em todas as interfaces.

**Ação necessária:** mapear consumidores, limitar bindings e aplicar firewall gradualmente, sempre com segundo acesso SSH e rollback testado.

---

### 🟠 Backup de aplicação não demonstrado

**Risco:** não foram encontrados dumps ou cópias locais de bancos/volumes; `/var/backups` contém apenas dados padrão do sistema.

**Ação necessária:** definir RPO/RTO, automatizar backup externo e testar restauração em staging.

---

### ✅ AnythingLLM ativo não usa DeepSeek

A instância `anythingllm` usada pelo app está em OpenRouter com `google/gemini-2.5-flash-lite`. Há um modelo DeepSeek baixado em um Ollama compartilhado, mas ele não está selecionado pelo Tutor TDS. A restrição sem DeepSeek foi adicionada ao plano.

---

### 🟡 Token Dokploy não versionado mas em .env.deploy local

**Risco:** O arquivo `.env.deploy` contém `DOKPLOY_API_TOKEN` e outras credenciais.
Está excluído do Git, mas existe no diretório de trabalho.

**Ação recomendada:** Mover para um secret manager ou variável de CI/CD quando o pipeline for automatizado.

---

### 🟢 Sem validação de assinatura do APK no servidor (Play Integrity)

**Risco baixo atual:** Não há verificação de que o cliente é o APK legítimo da Play Store.
Isso abre espaço para clientes modificados abusarem do gateway.

**Ação futura (Pós Onda 5):** Implementar Google Play Integrity API conforme mencionado no `PRODUCTION_RELEASE.md`.

---

### 🟢 Cloudflare Worker sem autenticação de origem no /v1/chat

**Risco:** Qualquer cliente que conheça a URL do worker pode fazer requisições de chat.
O CORS limita origens no browser, mas não protege clientes nativos ou curl.

**Ação futura:** Adicionar token de aplicação (ex: HMAC com timestamp) para requisições do app Flutter.

---

## Resumo Executivo de Segurança

| Achado | Severidade | Status |
|---|---|---|
| CPF não no servidor de certificados | ✅ OK | Resolvido no design atual |
| Chaves de IA não no APK | ✅ OK | Resolvido no design atual |
| Keystore Android protegido | ✅ OK | gitignore confirmado |
| HTTPS obrigatório | ✅ OK | Verificado no código |
| Consentimento LGPD | ✅ OK | Implementado |
| Integridade do certificado no cliente | ✅ OK | SHA-256 local |
| CPF em plaintext para Google Sheets | 🟠 Alto | Resolver na Onda 1 |
| Sem autenticação JWT no servidor | 🟠 Alto | Resolver na Onda 1 |
| CPF em plaintext no SharedPreferences | ✅ OK | Migrado para armazenamento seguro |
| Rate limiting webhook ausente | 🟡 Médio | Resolver na Onda 1 |
| Log Docker com aproximadamente 235,9 GB | 🔴 Crítico | Correção controlada pendente |
| Serviços internos publicados / firewall permissivo | 🟠 Alto | Hardening planejado |
| Backup de aplicação não demonstrado | 🟠 Alto | Implementar e testar |
| AnythingLLM sem DeepSeek ativo | ✅ OK | Provider/model confirmados |
| .env.deploy com credenciais locais | 🟡 Médio | Boa prática: usar CI secrets |
| Play Integrity não implementada | 🟢 Baixo | Pós Onda 5 |
| Auth de origem no Worker | 🟢 Baixo | Melhoria futura |

---

_Atualizar após cada onda de implementação._
