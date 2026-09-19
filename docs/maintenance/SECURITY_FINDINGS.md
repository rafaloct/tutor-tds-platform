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

**Evidência:** `lib/config/app_config.dart` — apenas `tutorGatewayUrl` e `analyticsWebhookUrl` (URL pública sem credencial).

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

O `DataSyncService` verifica `PrivacyPreferences.hasConsent()` antes de enviar qualquer evento.
Se negado, o evento é ignorado silenciosamente.

---

### ✅ Validação de integridade do certificado no cliente

O Flutter recalcula o SHA-256 do payload canônico do certificado e compara com o hash recebido do servidor antes de aceitar e salvar o registro.

---

### 🟠 CPF trafega em plaintext para o Google Apps Script

**Risco:** O `DataSyncService` envia o CPF do usuário (texto, sem hash) via HTTP POST para a URL do Google Apps Script.

**Impacto:** Potencial violação da LGPD. O Google Apps Script salva o CPF na aba `Alunos` da planilha Google Sheets.

**Ação recomendada (Onda 1):**
- Substituir envio do CPF bruto por HMAC-SHA256 ou pseudônimo
- Ou remover CPF do payload e usar apenas identificador interno
- Garantir que a planilha não seja compartilhada publicamente

**Evidência:** `lib/services/data_sync_service.dart` linha 39
```dart
'cpf': cpf,
```
E `google_apps_script.js` linha 48:
```js
sheet.appendRow([new Date(), data.name, data.phone, data.cpf, ...])
```

---

### 🟠 Ausência de autenticação server-side para acesso ao app

**Risco:** O aplicativo não possui sistema de autenticação real no servidor. O usuário é identificado apenas por dados locais (SharedPreferences). Qualquer manipulação local pode falsificar identidade.

**Impacto:** Impossível garantir multi-usuário seguro, controle de turmas ou perfil de professor sem autenticação real.

**Ação recomendada (Onda 1):** Implementar JWT com refresh token na API Tutor TDS.

---

### 🟡 CPF armazenado em plaintext no SharedPreferences

**Risco:** O CPF é armazenado localmente na chave `user_cpf` sem criptografia.
Em dispositivos com root ou backup ADB habilitado, o dado pode ser exposto.

**Ação recomendada:** Avaliar uso de `flutter_secure_storage` para dados pessoais sensíveis na Onda 1.

**Evidência:** `lib/screens/welcome_screen.dart` linha 57
```dart
await prefs.setString('user_cpf', _cpfController.text);
```

---

### 🟡 Ausência de rate limiting no webhook do Google Apps Script

**Risco:** A URL do webhook é pública. Um ator malicioso pode enviar requisições em massa e inflar a planilha com dados falsos.

**Ação recomendada:** Migrar analytics para a API Tutor TDS (Onda 1) com autenticação e rate limiting.

---

### 🟡 Auditoria direta da VPS não realizada

**Risco:** O estado real dos serviços, configuração do firewall, versões e possíveis vulnerabilidades da VPS 46.202.150.132 são desconhecidos.

**Ação necessária:** Acesso SSH → auditoria de leitura → inventário completo.
Ver [SSH_ACCESS.md](../infrastructure/SSH_ACCESS.md).

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
| CPF em plaintext no SharedPreferences | 🟡 Médio | Avaliar na Onda 1 |
| Rate limiting webhook ausente | 🟡 Médio | Resolver na Onda 1 |
| VPS não auditada | 🟡 Médio | Pendente SSH |
| .env.deploy com credenciais locais | 🟡 Médio | Boa prática: usar CI secrets |
| Play Integrity não implementada | 🟢 Baixo | Pós Onda 5 |
| Auth de origem no Worker | 🟢 Baixo | Melhoria futura |

---

_Atualizar após cada onda de implementação._
