# WP-1 — Contrato de métricas, contato e suporte do portal

## Princípio

Separar três domínios:
1. analytics público sanitizado;
2. suporte operacional;
3. jornada acadêmica.

Nenhum evento de site concede matrícula, presença, capacitação, certificado ou elegibilidade.

## Analytics público

Eventos candidatos:
- `portal_page_view`
- `course_card_click`
- `catalog_filter_used`
- `course_public_view`
- `course_participation_click`
- `app_access_click`
- `news_view` / `news_click`
- `event_view` / `event_registration_click`
- `material_view` / `material_download_click`
- `support_cta_click`
- `support_intake_submitted`
- `certificate_verify_started`
- `certificate_verify_result`

Payload permitido:
- event_name;
- timestamp;
- source=`portal`;
- rota/slug público;
- tipo de conteúdo;
- CTA/tópico categórico;
- integration_state;
- campaign/referrer sanitizado;
- identificador efêmero/pseudônimo somente quando necessário.

Proibido no analytics:
- nome, e-mail, telefone;
- texto da mensagem, pesquisa livre ou conversa;
- CPF/NIS;
- user_id/membership_id/enrollment_id;
- progresso, presença, baseline;
- hash/código de certificado;
- tokens/credenciais.

## Suporte operacional

Fluxo alvo:
`Portal -> PortalSupportAdapter -> Chatwoot`.

Fallback de e-mail só é usado quando Chatwoot estiver indisponível/configurado para manutenção. Não duplicar a mesma solicitação simultaneamente em Chatwoot e e-mail.

Tópicos de suporte:
- app/acesso;
- curso;
- frequência/certificado;
- mentoria;
- dados/conta/privacidade;
- outro/incerto.

Contato institucional separado:
- parceria;
- imprensa;
- geral.

A mensagem e os dados de contato permanecem no sistema operacional de suporte conforme retenção aprovada. BI não recebe transcrição.

## Métricas derivadas de suporte

Do Chatwoot/webhook para a camada analítica:
- origem=portal;
- tópico;
- canal;
- status;
- criado_em;
- primeira_resposta_em;
- resolvido_em;
- handoff_humano;
- fallback_usado;
- resultado categórico.

Para correlação posterior com jornada acadêmica, usar mecanismo explícito e revisado de identidade/pseudônimo. Não usar e-mail/telefone como chave analítica.

## Formulário legado

O formulário atual envia e-mail com cópia para atendimento e não cria caso estruturado. Na nova versão:
- mostrar aviso de privacidade;
- criar caso no adapter de suporte;
- medir somente o evento sanitizado;
- conferir resultado real do envio;
- implementar anti-spam/rate-limit;
- nunca ecoar PII em query string, HTML de retorno ou logs públicos.

## GA4

O ID atual é público e está hardcoded no tema legado. Em WP-2, mover analytics para configuração central/adapter. Staging deve ficar sem coleta real. Produção só habilita eventos após validação de privacidade/consentimento aplicável.

## Power BI

Power BI recebe projeções agregadas/sanitizadas do portal e suporte. Não consulta Chatwoot para reproduzir mensagens, nem WordPress para inferir presença ou capacitação.
