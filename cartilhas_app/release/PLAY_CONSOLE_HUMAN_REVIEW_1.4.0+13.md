# Revisão humana da Play Console — Tutor TDS 1.4.0+13

Auditoria técnica executada em 20/09/2026 sobre o código, o AAB final e os
endpoints públicos configurados. Este documento **não é parecer jurídico** e
não autoriza publicação. As respostas finais da Play Console dependem dos
contratos, das configurações dos provedores e das decisões do responsável pelo
tratamento dos dados.

## Artefato auditado

- pacote: `com.tutortds_cartilhas`;
- versão: `1.4.0` (`versionCode 13`);
- AAB: `release/Tutor-TDS-1.4.0+13-signed.aab`;
- tamanho: `64.716.303` bytes;
- SHA-256: `B93FAD21CE8AE92AB464FCAFE8FB69E66C07C6E712DB0DBFCA0AE580B2844B66`;
- configuração compilada: API e gateway produtivos, política e exclusão em
  HTTPS; tráfego HTTP desabilitado no manifesto.

## Conclusão objetiva

- O aplicativo trata dados pessoais, atividade no app e conteúdo fornecido
  voluntariamente. Portanto, a resposta técnica para “o app coleta dados?” é
  **sim**.
- Não há SDK dedicado de anúncios, atribuição, crash reporting ou analytics no
  `pubspec.yaml` nem no manifesto. A telemetria pedagógica própria é opcional,
  autenticada e depende da preferência de acompanhamento.
- Os eventos consentidos vão para a API TDS/PostgreSQL e o compose produtivo
  exige um worker que os espelha, com identificadores pseudonimizados, em
  Google Sheets. A classificação desse espelho como “compartilhamento” ou como
  prestador de serviço é uma decisão contratual/humana, não uma conclusão do
  código.
- Nome e telefone podem chegar ao Chatwoot somente com a preferência de
  acompanhamento; um identificador aleatório de suporte é transmitido ao abrir
  o suporte mesmo sem essa preferência. Mensagens são enviadas apenas quando a
  pessoa usa o canal.
- Pergunta/contexto do Tutor e temas para material de estudo passam pelo Worker
  Cloudflare e pelo AnythingLLM/provedor configurado. CPF e telefone não são
  adicionados automaticamente a essas requisições.
- O microfone é opcional e o app não grava arquivo. A fala é entregue ao
  serviço de reconhecimento disponível no Android; a retenção e o
  processamento desse serviço não podem ser provados pelo código do app.
- O fluxo de certificado envia o CPF completo ao Worker por HTTPS para gerar
  um HMAC de deduplicação. O KV guarda o HMAC da reivindicação e o certificado
  público, que inclui nome e conclusão, mas não o CPF nem o telefone.
- A exclusão de estudante apaga os dados transacionais da API e agenda a
  remoção dos eventos espelhados no Google Sheets. Certificados públicos já
  emitidos podem permanecer. Contas de equipe exigem atendimento assistido.
- As páginas públicas de política e exclusão responderam HTTP 200 e eram
  byte a byte iguais a `web/privacy.html` e `web/account-deletion.html` nesta
  auditoria.

## Estado efetivamente disponível no ambiente configurado

Leituras públicas, sem autenticação e sem mutação, mostraram:

| Destino | Evidência em 20/09/2026 | Estado técnico |
|---|---|---|
| Política de privacidade | HTTP 200; SHA-256 remoto igual ao arquivo do repositório | disponível |
| Exclusão externa | HTTP 200; SHA-256 remoto igual ao arquivo do repositório | disponível |
| API TDS | `/health` e `/courses` HTTP 200; OpenAPI público com 21 rotas | núcleo atual disponível |
| Gateway Cloudflare | `/health` HTTP 200 | disponível; chamada real de IA não foi feita nesta auditoria |
| Chatwoot | página base HTTP 200 | endpoint disponível; jornada autenticada não foi exercitada |
| Rotas novas no backend produtivo | OpenAPI não contém `/classes`, `/assessment-attempts`, `/assessment-contents`, `/media` nem rotas de sessões/importações Evidence | **não disponíveis no ambiente produtivo atual** |

Consequência: catálogo/vídeo remoto, retomada de simulado entre aparelhos,
capability da área de equipe e Evidence Engine existem no cliente, mas não
devem ser anunciados como funcionais em produção até a promoção compatível do
backend e um smoke pós-deploy. O AAB faz fallback honesto em parte dessas
jornadas, mas fallback não equivale à integração online habilitada.

## Matriz de permissões Android

| Permissão efetiva no AAB | Uso observado | Obrigatória | Relação com dados |
|---|---|---:|---|
| `INTERNET` | API, gateway de IA/certificados, Chatwoot, mídia e links | sim para recursos online | permite as transmissões descritas abaixo |
| `RECORD_AUDIO` | ditado da pergunta no Tutor após ação e aviso | não | fala entregue ao serviço de reconhecimento do Android |
| `com.tutortds_cartilhas.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | permissão interna gerada pelo AndroidX | interna | não representa uma categoria de dado solicitada à pessoa |

Não há permissões de câmera, localização, contatos, calendário, telefone,
SMS, fotos, vídeos, armazenamento amplo ou notificações no manifesto final.

## Matriz técnica de dados

“Coletado” abaixo significa transmitido para fora do aparelho pelo app ou por
um componente invocado por ele. Não decide, por si só, a coluna “compartilhado”
da Play.

| Categoria candidata na Play | Dado e destino | Finalidade observada | Gatilho/controle | Retenção e exclusão tecnicamente demonstradas |
|---|---|---|---|---|
| Informações pessoais — nome | API TDS no cadastro; Worker/KV no certificado; Chatwoot com acompanhamento autorizado | conta, identificação pedagógica, certificado e suporte | conta e certificado são opcionais; suporte é aberto pela pessoa | API apaga para estudante; cópia pública do certificado pode permanecer; Chatwoot depende de política/contrato externo |
| Informações pessoais — telefone | API TDS; Chatwoot somente com acompanhamento autorizado | conta e suporte | conta opcional; controle de acompanhamento em Configurações | API apaga para estudante; retenção do Chatwoot não está definida no repositório |
| Outras informações pessoais — CPF | API de cadastro/login; Worker de certificado | autenticação/deduplicação de conta e emissão única | conta/certificado opcionais, com avisos próprios | API guarda HMAC, não o número; Worker guarda HMAC da reivindicação; CPF local fica no armazenamento seguro; não há CPF no certificado público |
| Credencial | senha enviada à API no cadastro/login; tokens de sessão no armazenamento seguro | autenticação | conta opcional | senha vira hash Argon2 no servidor; refresh token expira em 30 dias; logout/exclusão remove tokens locais |
| Identificadores | UUID de usuário, matrícula, turma, evento e sessão; identificador aleatório de suporte | autenticação, autorização, idempotência, auditoria e suporte | conta/vínculo; o identificador de suporte nasce ao abrir a tela | registros da API são removidos no fluxo de estudante; Sheets recebe HMACs; suporte depende do provedor |
| Atividade no app — interações | curso, início/conclusão, página, recurso, funcionalidade, tempo ativo, checkpoints/posição de vídeo e ação posterior | progresso, carga horária, retomada e analytics pedagógico | fila/sync exige acompanhamento autorizado e sessão para envio | API apaga para estudante; exclusão no Sheets é assíncrona e deve ser monitorada |
| Atividade no app — avaliação de mídia | mídia e nota inteira de 1 a 5 | avaliação pedagógica do conteúdo | conta, matrícula e conclusão qualificadas | API apaga a avaliação na exclusão de estudante |
| Atividade no app — quiz/simulado | tema, questões/opções/gabarito gerado, respostas, marcações, posição, tempo restante, estado e revisão | autosave, correção no servidor e retomada entre aparelhos | envio exige conta/matrícula; progresso local continua offline | fila e tentativa local são apagadas pela exclusão no app; API apaga conteúdo/tentativas do estudante; backend produtivo atual ainda não expõe essas rotas |
| Atividade pedagógica — presença/evidência | turma, sessão, check-in, digests, códigos de decisão e metadados limitados | presença, validação humana e relatório auditável | conta e vínculo; importação de equipe | o Flutter proíbe conversa/arquivo bruto; `retention_until` existe, mas não foi localizado job de purge; backend produtivo atual ainda não expõe as rotas |
| Conteúdo gerado pelo usuário | pergunta e contexto do Tutor; mensagens digitadas no Chatwoot/WhatsApp | resposta pedagógica e atendimento | ação explícita da pessoa | app não persiste conversa do Tutor; retenção/logs do Cloudflare, AnythingLLM, provedor do modelo, Chatwoot e WhatsApp exigem confirmação |
| Áudio | fala durante o ditado | transcrição da pergunta | botão de voz, aviso e permissão Android | o app não cria arquivo; comportamento do serviço de reconhecimento instalado exige confirmação |
| Certificados/documentos | nome, curso, data, progresso, ID, hash e assinatura no KV e no PDF local | emissão e verificação pública | confirmação específica antes da emissão | PDF/índice na área privada; cópias exportadas ficam no destino escolhido; registro público pode permanecer sem TTL definido |
| Metadados de mídia | catálogo, autorização efêmera, fonte e legenda; requisição de playback ao provedor | reprodução de vídeo | ação de abrir/reproduzir; algumas visibilidades exigem matrícula | grant interno usa token opaco curto; logs/cookies/IP no YouTube, Cloudflare Stream ou HLS dependem do provedor; integração produtiva atual não está exposta pela API |
| Dados locais não enviados por padrão | tema, preferências, progresso offline, resumos, filas pendentes, cache de catálogo e PDFs | funcionamento offline e retomada | uso normal do app | `allowBackup=false`; exclusão no app limpa preferências e certificados após sucesso remoto; logout não apaga o perfil/progresso local |

### Categorias sem coleta explícita encontrada no código

- localização precisa ou aproximada por API/permissão do Android;
- contatos, e-mail cadastral, calendário, SMS e histórico de chamadas;
- saúde, atividade física e informações financeiras;
- fotos ou vídeos do aparelho;
- arquivos brutos de WhatsApp/Drive para Evidence;
- identificador de publicidade;
- dados de anúncios, atribuição ou crash por SDK dedicado.

Endereços IP, cabeçalhos de rede, cookies/WebView e diagnósticos podem ser
processados automaticamente pelos servidores/provedores. Isso não é visível
de forma suficiente no código e deve ser verificado antes de marcar essas
categorias como ausentes na Play.

## Criptografia e armazenamento

| Camada | Evidência | Limite da afirmação |
|---|---|---|
| Em trânsito | todos os destinos compilados são HTTPS; `usesCleartextTraffic=false`; URLs HLS/playback são validadas como HTTPS | não comprova políticas internas dos provedores depois do recebimento |
| Segredos no aparelho | CPF local e tokens em `FlutterSecureStorage` | nome, telefone, progresso, cache e filas ficam em armazenamento privado comum, não em armazenamento seguro criptográfico pelo app |
| Credenciais no servidor | senha com Argon2; CPF e refresh token com digest/HMAC | HMAC é pseudonimização, não anonimização nem criptografia reversível |
| Banco/serviços externos | acesso autenticado/RBAC no código; Google Sheets recebe identificadores HMAC | criptografia de disco, chaves, logs e controles organizacionais não foram provados nesta auditoria |
| Backup | backup Android desativado; backup lógico da API documentado com retenção local de 14 dias | exclusão não remove imediatamente cópias em backups; destino externo e restauração exigem regra operacional |

## Integrações e estado

| Integração | Dados possíveis | Estado no código/configuração | Revisão humana necessária |
|---|---|---|---|
| API TDS/PostgreSQL | conta, hierarquia, eventos, avaliações, tentativas e evidências | endpoint produtivo compilado; núcleo responde | confirmar promoção das rotas novas antes do teste interno |
| Google Sheets | eventos, timestamps, curso/tipo/payload e identificadores HMAC | worker obrigatório no compose de produção | confirmar planilha, acessos, região, contrato, retenção e fila de exclusão sem falhas esgotadas |
| Cloudflare Worker | pergunta/contexto, tema de estudo e dados de emissão | endpoint produtivo compilado e health disponível | revisar logs, região, DPA e retenção |
| AnythingLLM + provedor do modelo | pergunta/contexto e tema/material solicitado | encaminhamento implementado; documentação aponta OpenRouter/Gemini | confirmar no painel o modelo permitido, ausência de DeepSeek e política de retenção/treino na data da publicação |
| Cloudflare KV | certificado público e HMAC de deduplicação | binding no Worker, sem TTL no `put` | aprovar finalidade pública, prazo e procedimento de correção/revogação |
| Chatwoot | suporte ID; nome/telefone com consentimento; mensagens voluntárias | URL/token público no cliente; endpoint responde | confirmar inbox, agentes, retenção, exportação/exclusão e base contratual |
| WhatsApp | número do suporte, mensagem e dados que a pessoa decidir enviar | app externo aberto por ação da pessoa | aprovar canal e orientar a não enviar documentos/senha |
| Reconhecimento/TTS do Android | áudio para transcrição; texto para síntese | provedor instalado no aparelho | testar Android alvo e revisar tratamento de rede/retenção do engine adotado |
| YouTube/Cloudflare Stream/HLS | IP/cookies/device/playback conforme provedor | cliente provider-agnostic; API produtiva de mídia ausente nesta auditoria | definir provedores realmente publicados e revisar consentimento/políticas |
| Compartilhamento/impressão do sistema | PDF ou resumo escolhido pela pessoa | somente ação explícita via share/print sheet | nenhuma transmissão automática pelo app; destino passa ao controle da pessoa |
| Pagamentos/comercial | nenhum dado financeiro no cliente | `PAYMENT_ADAPTER=disabled`; simulação comercial desativada por padrão | não declarar pagamentos ativos |

Google Drive não é usado como playback e o Flutter não envia conversa ou
arquivo bruto de WhatsApp/Drive; Evidence aceita somente digests, referências
privadas e metadados enumerados.

## Comparação com política e exclusão publicadas

### Pontos coerentes com o código

- conta opcional com nome, telefone, credenciais e CPF transformado em HMAC na
  API;
- atividade pedagógica e analytics condicionados à preferência de
  acompanhamento;
- Tutor envia pergunta/contexto e não anexa automaticamente CPF/telefone;
- microfone opcional e sem gravação de arquivo pelo app;
- certificado público sem CPF/telefone, mas com nome e conclusão;
- exclusão dentro e fora do app, preservando a possibilidade de manter o
  registro público do certificado;
- HTTPS e controles locais descritos.

### Lacunas que exigem decisão antes da declaração final

1. A política fala genericamente em provedores, mas não explicita o espelho
   pseudonimizado de eventos no Google Sheets.
2. O identificador aleatório enviado automaticamente ao abrir o Chatwoot não
   está descrito; nome/telefone estão corretamente condicionados ao
   acompanhamento no código.
3. YouTube, Cloudflare Stream e HLS não aparecem na política; se houver mídia
   publicada, o tratamento do provedor deve ser incluído.
4. Não há prazo concreto para conta, eventos, tentativas, suporte, IA e
   certificado público. `retention_until` de Evidence não tem purge demonstrado.
5. A remoção do espelho no Sheets é assíncrona e limitada a tentativas; é
   necessário monitoramento e procedimento para falha esgotada.
6. A política não define como pedidos de contas de equipe, correção/revogação
   de certificado público ou restauração de backup serão tratados.
7. O repositório contém as páginas canônicas em `cartilhas_app/web`, mas o
   compose monta `api/public`, diretório ausente neste checkout. O conteúdo
   publicado está correto hoje, porém o deploy não é reproduzível apenas pelo
   compose versionado sem uma etapa de cópia documentada.

Não alterar a política publicada apenas com base nesta lista: o responsável
deve aprovar o texto e verificar contratos/rotinas antes do deploy.

## Perguntas humanas obrigatórias

- [ ] Google, Cloudflare, Chatwoot, OpenRouter/provedor do modelo e provedores
  de vídeo qualificam-se como prestadores de serviço nas condições reais? Se
  não, quais categorias devem ser marcadas como compartilhadas?
- [ ] Quais retenções contratuais valem para Sheets, logs Cloudflare,
  AnythingLLM/modelo, Chatwoot, vídeo e reconhecimento de fala?
- [ ] O provedor do modelo continua na allowlist aprovada e sem DeepSeek?
- [ ] O monitor de exclusão confirma também a remoção no Sheets e trata itens
  que excederem o limite de retry?
- [ ] Qual é o prazo aprovado para certificados públicos e como funcionam
  correção, revogação e contestação?
- [ ] A retenção operacional deve incluir os 14 dias de backup local e eventual
  cópia externa?
- [ ] O público-alvo/classificação indicativa foi aprovado pelo Programa TDS?
- [ ] A revisão da Play usará somente funcionalidades realmente habilitadas no
  backend produtivo na data do envio?
- [ ] O Data Safety, a política, a tela interna de privacidade e os contratos
  foram revisados pela mesma pessoa responsável antes do upload?

## Notas curtas sugeridas para a versão atual

Texto conservador enquanto as rotas novas ainda não estiverem promovidas:

> Atualização da jornada de estudo com Tutor contextual, flashcards, resumos,
> quizzes e simulados com salvamento local. Também melhora leitura offline,
> acessibilidade, login/logout e estabilidade.

Após deploy e smoke das rotas novas, pode-se mencionar vídeos, retomada entre
aparelhos e área de equipe/evidências em uma versão posterior das notas.

## Evidências de código/configuração

- `android/app/src/main/AndroidManifest.xml` e manifesto extraído do AAB;
- `lib/features/auth`, `profile`, `learning_events`, `study_ai`, `media`,
  `evidence`, `certificates` e `analytics`;
- `lib/screens/chatwoot_screen.dart`, `privacy_screen.dart` e
  `settings_screen.dart`;
- `cloudflare/tutor-tds-gateway/src/index.js`;
- `api/app/auth.py`, `events.py`, `sync_worker.py`, `evidence.py` e modelos;
- `api/docker-compose.production.yml`;
- `web/privacy.html`, `web/account-deletion.html` e URLs compiladas no AAB.
