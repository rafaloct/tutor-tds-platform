# Tutor TDS — Authentik open source, OIDC e identidade EAD v1

Data da investigação: 22/10/2026. Estado: **LAB instalado e saudável; provedores OIDC e migração ainda não configurados**.

## DECISION: padrão institucional futuro

- Authentik open source é o futuro OpenID Provider (OP). Seus apps clientes são: WordPress/LearnPress (confidential, OIDC), Flutter (public, Authorization Code + PKCE S256, sem client secret no APK) e FastAPI Tutor TDS (verificador de access tokens com issuer, audience, assinatura JWKS, expiração e controle de papéis).
- A conta é identificada por `(issuer, sub)` imutáveis e opacos, vinculados explicitamente após prova das identidades anteriores e consentimento. **Nunca ligar contas automaticamente por nome, CPF, WhatsApp ou e-mail, mesmo verificado**. OIDC fornece autenticação; atribuição de aluno/servidor, matrícula, frequência e certificado continuam sob RBAC e autoridades já definidas no domínio.
- **B0 continua válido:** até a migração e aceites, WordPress e FastAPI usam seus dois logins atuais. A abertura do Chrome para autenticar é aceitável como passo de segurança, mas a leitura de aulas e vídeos deve ficar em Flutter nativo e offline. Não embutir a tela de senha no WebView do app.
- O aluno sem rede pode abrir somente material público previamente baixado e ver progresso local não confirmado. Login, matrícula LearnPress, certificação e revogação remota exigem conexão/prova do servidor. Offline nunca converte eventos locais em direitos acadêmicos.

## OBSERVED: infraestrutura Authentik de laboratório

- VPS Hostinger `srv1533541`, Docker Compose 2026.8.5 no projeto isolado `tds_authentik_lab_20261022`. Arquivos locais fora do Git: `/opt/tds-labs/authentik-oidc-20261022/{compose.yml,compose.override.yml,.env}`, diretório privado com permissões restritas. `.env` contém valores aleatórios PG e AUTHENTIK_SECRET_KEY; **nunca copiar para Git/ChatGPT ou logs**.
- Os contêineres `server`, `worker` e `postgresql` foram iniciados e passaram `healthy`. PostgreSQL 16 próprio; sem banco de dados ou usuários do WordPress/FastAPI. Authentik `server:2026.8.5` e worker mesma versão.
- Bindings **somente 127.0.0.1:19200 → 9000 (HTTP)** e **127.0.0.1:19443 → 9443 (HTTPS local)**; sem DNS, rota Cloudflare ou exposição pública. Socket Docker foi explicitamente removido do worker; supervisão via projeto nomeado e override de memória. Os outros serviços do Docker foram preservados.
- A raiz respondeu HTTP 302, fluxo de autenticação respondeu HTTP 200; nos primeiros minutos o setup inicial retornou 404. É necessário concluir bootstrap seguro do `akadmin` e configurar clientes **somente no laboratório**. Estes testes não são login SSO.
- Servidor produtivo WordPress `ead.ipexdesenvolvimento.cloud`: inventário read-only do WP-CLI confirma **OpenID Connect Generic não instalado/ativo**. Não instalar plugin nem alterar `users_can_register` no site público nesta issue.

## PROTOCOLO TARGET, NÃO IMPLEMENTADO

| Cliente | Configuração e fronteira |
| --- | --- |
| Authentik OP | Um issuer HTTPS canônico, chaves rotativas, JWKS, fluxos de consentimento e MFA de administração, logs restritos, email de recuperação somente após homologação |
| WordPress (staging) | Plugin OpenID Connect Generic em clone, client confidential, segredo só no servidor, callback fixo HTTPS validado, manter break-glass admin local, sem linking automático de contas |
| Flutter | `flutter_appauth` estável 12.1.0 como candidato; cliente público, PKCE S256, state e nonce verificados, redirects Android controlados, tokens só em storage seguro; nenhuma senha WP no Flutter, sem credentials por query string |
| FastAPI Tutor TDS | Configuração estrita de issuer/audience/JWKS, fail-closed sob falha JWKS/clock skew ou conta desvinculada; papel institucional vem do RBAC existente, nunca de string de role arbitrária do token |
| Vinculação | Usuário A e B comprovam controle de ambas contas, vínculo `(issuer, sub)` único por ambiente e TDS/WP, consentimento registrado, revogação e troca de conta sem vazamento; testes com replay e account takeover |
| Desconexão | Público baixado continua legível em armazenamento privado após verificação SHA-256; conteúdo restrito segue política explícita de licença/grant, sem elevar privilégios offline |

A URL de issuer, redirect URI e clients só serão fixadas depois do domínio HTTPS staging, auditoria WP e provas. Não publicar um redirect `http://127.0.0.1` para login móvel real.

## Escolhas tecnológicas e compatibilidade

- Authentik docs oficiais de provider OAuth2/OIDC e PKCE: https://docs.goauthentik.io/add-secure-apps/providers/oauth2/ .
- WordPress/OpenID Connect Generic: https://docs.goauthentik.io/integrations/services/wordpress/ (a documentação pode redirecionar para o catálogo de integrações). Revisar semântica de criação/associação de usuário antes de habilitar.
- Flutter: https://pub.dev/packages/flutter_appauth (12.1.0, Android minSdk 24 conforme changelog; validar no Flutter 3.44.9 em QA isolado antes de adicionar ao pubspec).
- Instalação oficial Docker Compose: https://docs.goauthentik.io/install-config/install/docker-compose/ . O arquivo oficial publicado em 22/10 pinava 2026.8.5 e incluía docker.sock no worker; a cópia local removeu o mount.
- O Authentik não substitui LearnPress nem dispensa o plugin TDS Content API offline; é serviço de identidade independente. Não usar Authentik para sincronizar vídeos.

## Verificação e rollback do laboratório (sem tocar produção)

Operações exclusivamente na VPS autorizada, acesso SSH administrativo e dentro do diretório privado:

1. `docker compose -p tds_authentik_lab_20261022 -f compose.yml -f compose.override.yml ps` — conferir 3 serviços healthy.
2. `docker compose -p tds_authentik_lab_20261022 -f compose.yml -f compose.override.yml config --format json | python3 /CAMINHO_LOCAL/authentik_lab_policy.py`. **Atenção:** config expandida contém segredos; sempre canalizar diretamente ao validador e não imprimir JSON nem enviar logs.
3. `curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:19200/` — código HTTP 302 indica serviço. Não expor porta.
4. Rollback de processo, se necessário: `docker compose -p tds_authentik_lab_20261022 -f compose.yml -f compose.override.yml down`. Nunca utilizar `-v` antes de backup/verificação; não parar outros projetos Docker.

## Gate antes de conectar WordPress ou alunos

- Aprovar o domínio HTTPS e controle de acesso do estágio; inicializar `akadmin` com senha e MFA fora do chat; backup e restore Authentik/Postgres isolados, envio seguro de emails e recovery.
- Testar em clone WordPress, explicitamente sem mudanças do EAD produtivo. Administrador local break-glass, logout, revogação, senhas existentes preservadas e rollback exercitado.
- Provar com contas sintéticas A/B: PKCE inválido, state/nonce, troca de usuário, contas duplicadas, issuer/audience, expiração, token revogado, consentimento, MFA admin, OpenID discovery e JWKS. `EadSessionProof` não é resultado de boolean enviado pelo cliente.
- Só então enviar implementação backend/app em PRs pequenos com testes. Merge, assinatura AAB e alteração de login produtivo continuam em HUMAN_GATE. `MERGE_ALLOWED=NO`, `PRODUCTION_ALLOWED=NO`.
- O plugin `blob_flutter` é decisão de UX separada: candidato para Tutor IA somente após benchmarks reais, fallback estático e respeito a reduzido movimento; não é parte do stack Authentik e não deve carregar em telas de vídeos.
