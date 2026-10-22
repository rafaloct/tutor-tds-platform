# Issue #327 — contrato de `sign_up` WordPress com consentimento

Estado em 22/10/2026: **IMPLEMENTED** como política pura e teste sintético; **BLOCKED** para instrumentação real. Escopo de uma única conversão de cadastro público WordPress. Nenhum arquivo do tema, plugin, app, API ou ambiente foi alterado por esta issue.

## OBSERVED

- O patch institucional #299 registra `tds_handle_cadastro_publico` em `admin_post_tds_cadastro` e `admin_post_nopriv_tds_cadastro`; nele o sucesso de `wp_insert_user` antecede notificação, login e redirecionamento. O helper de curso aceita `lp_course` publicado, público e de mesma origem. O tema institucional ativo não é idêntico aos temas legados versionados; aplicar patch nesses temas não atualiza produção.
- `docs/operations/EAD_ACCOUNT_ANALYTICS_BRIDGE.md` registra a tag do tema ativo `G-7B9JLYWLH4` como referência de ambiente e carga incondicional observada em `wp_head`. Isto não comprova consentimento válido, envio de `sign_up` nem recebimento pelo GA4. Não inserir ou ativar essa tag por este contrato.
- O app abre URLs públicas com UTM fixas. UTM informa atribuição declarada de campanha e pode ser falsificada no navegador; não comprova origem real, identidade, cadastro ou matrícula.
- A decisão EAD mantém WordPress/LearnPress como autoridade da conta e oferta EAD, e FastAPI como autoridade de identidade/vínculos institucionais. A Issue #272 / PR #273 mantém dois logins sem broker até prova de identidade.

## TARGET: fronteira de integração futura

1. No **handler público** `tds_handle_cadastro_publico`, validar nonce e todos os requisitos normais do cadastro. Obter a elegibilidade de curso publicado pelo helper existente. Depois de `wp_insert_user` retornar um ID positivo e não `WP_Error`, e **antes** de qualquer redirecionamento, montar no servidor o snapshot exigido por `tds_signup_analytics_event()` em `wordpress/institutional-patches/issue-327/signup-analytics.php`. Nunca montar esse snapshot em GET, no template, em `cadastro=ok`, em login ou em hook genérico de criação de usuário.
2. O adaptador futuro deve registrar `insert_status=created`, `trigger=insert_success`, `handler=tds_cadastro_publico`, timestamp do sucesso, nonce validado, inexistência anterior e correspondência entre conta criada e operação corrente a partir de resultados **server-side**. Não usar `$_GET`, URL, referrer, cookie ou parâmetro do browser como prova desses fatos. UTM só podem ser os quatro valores públicos exatos aceitos pela política; capturá-las do fluxo POST de forma controlada e validar contra a allowlist. `course_id` deve ser inteiro positivo e `course_public=true` apenas após verificação atual de curso público; sem curso, usar `null/false` e `welcome_signup`.
3. Um gestor de consentimento do portal, validado para LGPD pelo responsável, deve oferecer escolha explícita e revogável. Ler estado autoritativo atual do gestor **após** a criação da conta e imediatamente antes da possível emissão; `analytics=granted`, `explicit=true`, `revoked=false` e `checked_at` entre o sucesso e a emissão, com no máximo 30 segundos de diferença. Estado ausente, expirado, revogado, contraditório ou erro de leitura bloqueia. Revalidar também no instante de uso, pois um snapshot pode envelhecer entre avaliação e transmissão. O cadastro continua funcionando quando analytics falha.
4. Usar **Consent Mode básico**: tag GA4 bloqueada até opt-in, sem requisição ao Google antes disso. Consent Mode avançado com pings sem cookies sob `denied` não atende à regra desta issue. A tag já observada em `wp_head` precisa de auditoria e correção própria antes de instrumentar qualquer evento. Consentimento negado ou revogado deve impedir coleta futura, inclusive da tag geral; oferecer opt-out e tratar eventual eliminação de dados já coletados no processo de privacidade próprio.
5. Antes de emitir, fazer uma reivindicação **atômica, persistente e única por conta WordPress** para o marcador lógico `TDS_SIGNUP_WP_DEDUP_MARKER` (`_tds_ga4_signup_reported`), após conferir que ainda não foi reportado. Um simples `get_user_meta` seguido de `update_user_meta` não evita corrida; o mecanismo concreto exige revisão na implementação futura. Falha/duplicata na reivindicação bloqueia. Registrar a marca antes da tentativa pode perder uma conversão se navegador/bloqueador falhar; jamais reemitir automaticamente ou enfileirar offline para contornar consentimento. O identificador da conta e a marca ficam só no WordPress, nunca no payload GA4.
6. Encaminhar **somente** o retorno não nulo da política como dados do evento: `event_name=sign_up`, `method=wordpress`, `utm_source=tutor_tds_app`, `utm_medium=app`, `utm_campaign=ead_signup`, `utm_content=welcome_signup` ou `course_<ID público>`. Nenhum e-mail, CPF, nome, telefone, `user_id`, token, URL, referrer ou cookie. Antes de ligar uma tag, revisar também parâmetros automáticos e configuração da propriedade para não vazar PII por `page_location`/`page_referrer`. A política não chama tag, rede, WP write nem produz HTML.

O nome recomendado `sign_up` e o parâmetro `method` constam na [documentação oficial de eventos GA4](https://developers.google.com/analytics/devguides/collection/ga4/reference/events). O bloqueio da tag até consentimento no modo básico consta na [documentação oficial de Consent Mode](https://developers.google.com/tag-platform/security/concepts/consent-mode). A política local é mais restritiva: exige opt-in efetivo e zero requisições GA4 sem ele.

## NOT_IMPLEMENTED / BLOCKED

- **NOT_IMPLEMENTED:** hook no tema ativo, gestor de consentimento, persistência atômica do marcador, carga condicionada da tag, envio GA4, testes de browser/HTTP e reconciliação agregada. Não há prova de que o GA4 recebeu qualquer evento.
- **BLOCKED — HUMAN_GATE:** responsável pelo portal e privacidade deve validar aviso LGPD, escolha e revogação, auditoria da tag já existente, configuração da propriedade/parametrização sem PII, mecanismo de dedup e staging isolado. **Reason:** sem evidência de consentimento aplicável e tag bloqueada, a medição real pode transmitir dados sem autorização. **Exact human action:** aprovar por escrito esse desenho e liberar uma implementação separada no tema institucional exato, com hashes conferidos, em staging isolado. **What remains unblocked:** revisão do contrato e execução dos testes sintéticos locais; o cadastro EAD existente não depende desta medição.
- Promoção, merge, deploy, produção, Google real, assinatura e Play permanecem fora desta issue. Testes locais não mudam `PRODUCTION_READY` nem aceitam a release.

## Verificação local e gate posterior

No checkout desta issue, sem segredo, WP ou rede:

```text
php -n wordpress/institutional-patches/issue-327/test-signup-analytics.php
php -l wordpress/institutional-patches/issue-327/signup-analytics.php
python tooling/verify_wp_legacy_snapshot.py
```

O teste focal cobre sucesso e recusa de GET, UTM isolada/adulterada, nonce, conta existente/trocada, erro ou crash de inserção, replay, duplicata, consentimento negado/desconhecido/revogado/antigo, curso inválido e campos extras. Ele testa somente a função pura. Um gate posterior precisa provar no staging isolado zero tráfego Google antes de opt-in e após revogação, um evento no máximo por conta sob concorrência e replay, payload efetivo sem PII inclusive parâmetros automáticos, e comparação **agregada** com cadastros WordPress. Bloqueadores de browser e falha de rede podem produzir menos eventos que cadastros; não inferir entrega individual pelo retorno da política.
