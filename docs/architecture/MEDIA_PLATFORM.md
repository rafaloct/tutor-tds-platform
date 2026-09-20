# Tutor TDS - arquitetura de mídia e vídeo

## Decisão

O aplicativo não conhece URLs fixas nem depende de um único provedor. A API
publica metadados pedagógicos e uma referência de reprodução por provedor.
Trocar YouTube por Cloudflare Stream ou HLS próprio não exige novo APK.

### Papéis de armazenamento e entrega

| Componente | Papel | Uso permitido |
|---|---|---|
| Google Drive institucional | master e acervo | originais, legendas, termos, evidências e cópias de preservação |
| YouTube não listado | piloto de baixo custo | conteúdo não sigiloso, com incorporação permitida |
| Cloudflare Stream | entrega escalável recomendada | conteúdo institucional/creator, bitrate adaptativo, analytics e URLs assinadas |
| R2 ou object storage | arquivos auxiliares | thumbnails, legendas, transcrições e downloads autorizados |
| VPS | API e metadados | nunca servir o arquivo master de vídeo diretamente em escala |

Google Drive não é CDN. Links de compartilhamento do Drive não devem ser
gravados como `playback_url` de produção. A VPS também não deve concentrar
tráfego de vídeo: isso concorreria com API, banco e Tutor IA.

## Contrato independente de provedor

Cada mídia publicada deve ter, no mínimo:

```text
id
institution_id
program_id
course_id
module_id
creator_user_id
title
description
competency_id
provider                 youtube | cloudflare_stream | external_hls
provider_asset_id
duration_seconds
thumbnail_url
captions[]               idioma, formato, URL/referência
visibility               public | unlisted | enrolled | institution
offline_policy           forbidden | allowed
status                    draft | processing | published | blocked | archived
master_drive_file_id      opcional; nunca enviado ao aluno
published_at
```

A API transforma `provider_asset_id` em uma fonte reproduzível. Quando a mídia
for protegida, a URL deve ser curta e assinada para o usuário matriculado. O
cliente não recebe token administrativo nem credencial do provedor.

## Endpoints-alvo

```text
GET  /media?course_id=&module_id=
GET  /media/{id}
POST /admin/media
PATCH /admin/media/{id}
POST /admin/media/{id}/publish
POST /admin/media/{id}/block
POST /admin/media/{id}/archive
GET  /admin/media/{id}/history
PUT  /media/{id}/rating
GET  /media/{id}/rating
POST /media/{id}/playback-authorizations
GET  /media/{id}/playback/{token}
GET  /creators/me/media
GET  /creators/me/analytics
```

Criação e publicação exigem RBAC e vínculo institucional. Um creator só pode
editar o próprio rascunho; publicação exige admin/coordenador até existir um
fluxo editorial completo.

Cada criação, publicação, bloqueio e arquivamento acrescenta uma linha em
`media_status_transitions`. Essa tabela é append-only inclusive no banco:
`UPDATE` e `DELETE` são recusados por trigger. Bloqueio só parte de conteúdo
publicado/em processamento; arquivamento é terminal. Ambos exigem motivo e
papel `coordinator` do programa ou admin global. O creator pode consultar o
histórico da própria mídia, mas não aprovar essas transições.

## Playback restrito

Para `enrolled` e `institution`, as respostas de catálogo nunca expõem a URL
do provedor. Um cliente autenticado solicita
`POST /media/{id}/playback-authorizations`; a API revalida a matrícula ou o
vínculo institucional e devolve uma URL interna com token opaco aleatório,
válida por 300 segundos. O banco guarda apenas o SHA-256 do token.
`GET /media/{id}/playback/{token}` revalida expiração, publicação e vínculo
antes de redirecionar (`307`) ao provider.
Bloqueio, arquivamento, exclusão do usuário ou perda do vínculo invalidam o uso
mesmo antes do vencimento.

A URL do grant nasce de `PUBLIC_API_BASE_URL`, nunca de `Host` ou
`X-Forwarded-*` fornecido pelo cliente. Em ambientes publicados, a base deve ser
HTTPS e incluir o prefixo removido pelo reverse proxy (`/tutor-api` ou
`/tutor-staging-api`). Em desenvolvimento direto, sem essa variável, a API pode
usar a própria URL da requisição.

Esse token autoriza a resolução no Tutor TDS; ele não finge ser assinatura do
Cloudflare/YouTube/HLS. Para proteção criptográfica de segmentos, o provider
real deverá fornecer URL assinada e sua credencial continuará somente no
backend. Até esse adapter existir, mídia sensível não deve usar YouTube ou HLS
público como se fossem DRM.

## Evidência pedagógica e analytics

Visualização isolada não é conclusão. O app registra eventos idempotentes e
sem texto livre:

```text
video_started
video_checkpoint          25 | 50 | 75
video_completed           >= 90% ou término confirmado pelo player
video_followup_completed  quiz, reflexão ou atividade associada
video_saved
```

Cada evento referencia `media_id`, `course_id`, `module_id`, matrícula e sessão.
O servidor calcula tempo validado, desconta intervalos sobrepostos e não aceita
segundos pedagógicos declarados pelo cliente.

Creator Score pode usar conclusão qualificada, salvamentos, avaliação e ganho
em atividade posterior. Pagamento nunca deve depender apenas de visualização.

A avaliação explícita é um inteiro de 1 a 5, sem comentário livre, e exige
matrícula ativa mais `video_completed` qualificado do próprio aluno. O `PUT` é
idempotente por `(media_id, user_id)`. O score `creator-score-v2` atribui até
1.500 basis points às avaliações dentro da janela. `video_started` sozinho
vale zero; a qualidade operacional só pontua quando há algum sinal pedagógico.

## Offline e baixa conectividade

- Metadados, thumbnail, legenda e progresso ficam em cache local.
- YouTube incorporado não oferece download controlado pelo Tutor TDS.
- Download offline só aparece quando `offline_policy=allowed` e o provedor
  fornecer arquivo autorizado, com expiração e armazenamento privado no app.
- Reentrada retoma a posição local e concilia com o servidor de forma
  idempotente.

## Estratégia de adoção

1. Publicar metadados e conteúdo não sigiloso por YouTube não listado.
2. Manter o master no Drive institucional com estrutura e permissões próprias.
3. Validar player, legendas, acessibilidade, eventos e atividade pós-vídeo.
4. Ativar Cloudflare Stream para mídia restrita ou quando o piloto justificar
   custo operacional.
5. Migrar cada item trocando somente `provider` e `provider_asset_id`.

## Gate humano e comercial

Antes de habilitar Cloudflare Stream/R2 ou qualquer plano pago, confirmar:

- conta Cloudflare e centro de custo;
- previsão de minutos armazenados e entregues;
- política de conteúdo e direitos de imagem;
- conta/Canal YouTube institucional e proprietários;
- Shared Drive institucional, grupos de acesso e retenção;
- termos do programa para creators e remuneração.

Nenhuma cobrança, publicação pública ou alteração de permissões deve ocorrer
automaticamente.
