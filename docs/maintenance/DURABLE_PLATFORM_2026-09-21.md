# Plataforma durável — decisões e execução de 21/09/2026

## Escopo e decisões do usuário

Esta rodada amplia o gate anterior de rastreabilidade. A versão 1.4 não está
liberada para a Play. Produção, certificados KV e o app separado de baseline
devem ser preservados. Não usar DeepSeek. Incorporar do baseline somente itens
de baixa complexidade; registrar os demais para manutenção futura.

O usuário escolheu **planilhas separadas para produção e staging**. Staging é
homologação técnica, não um segundo cadastro obrigatório de cursos reais.
O destino é publicação editorial no servidor, sem recompilar o app para cada
novo conteúdo. Isso não elimina futuras correções/manutenção de software.

## Planilhas novas

- Produção: https://docs.google.com/spreadsheets/d/1AshF-drgHCb4NEsI2f_DCLDXk75Olp1pdfUG1p7cj6k/edit
  - aba `EventosAPI`, intervalo `A:J`, sheetId `211666266`.
- Staging: https://docs.google.com/spreadsheets/d/1YpEF-1zdbLwjbkff5fyqYo9FhdPDwFQBA2Uwl0Gsy14/edit
  - aba `EventosAPI-Staging`, intervalo `A:J`, sheetId `1670215127`.
- Conta de serviço institucional existente recebeu writer somente nos novos
  arquivos: `tdsipex@tdsipex.iam.gserviceaccount.com`.
- Pasta criada `ChatGPT` na raiz do Drive conectado, ID
  `1sJpzJTM_YYa8-ycNVH5CZlHlxaK2X12E`.
- Cabeçalhos do contrato preservados, guia LeiaMe, importação nativa e inspeção
  visual no Google Sheets. Sem dados pessoais do baseline nos novos arquivos.
- PostgreSQL é a fonte transacional. Sheets recebe eventos com IDs HMAC; não
  editar manualmente a aba sincronizada. Relatórios podem usar outras abas.
- Produção: destino preparado; worker ainda NÃO ativado em produção.

## Entregas de código desta rodada

| Fluxo | Implementação | Evidência / limite |
|---|---|---|
| Catálogo público | GET `/courses` já existente, sem login | Correção Flutter: catálogo vazio válido não ressuscita assets/cache antigos |
| Inclusão em turma | GET `/classes/{id}/eligible-students`; PUT `/classes/{id}/students/{user}` | Professor/monitor vinculados ou admin; somente matrícula ativa da mesma oferta; sem criar conta ou elevar papel |
| Tela de inclusão | Área da equipe → Incluir estudantes | Busca por nome, paginação, confirmação, atualização do painel; rota `classroom_roster` com telemetria |
| Sheets | Worker com rede de saída dedicada, sem publicar portas do banco | Correção de cabeçalho duplicado e A1 `!A:A` com título da aba entre aspas |
| Operação | `api/ops/configure_staging_sheets.py` | Credencial reaproveitada dentro do VPS; backup e escrita atômica do env; sem imprimir segredos |

O primeiro teste real de Sheets retornou HTTP 400 por intervalo A1 incorreto.
Worker interrompido para corrigir antes de continuar; não considerar tentativa
de deploy como evidência de sincronização. Resultado final abaixo após readback.

## Baseline — inspeção somente leitura

Fonte local: `C:\Users\Usuario\Downloads\FORMULÁRIOS-20260409T214310Z-3-001\FORMULÁRIOS`.
O código inspecionado usa Flutter → backend Python / SQLite outbox → Sheets;
não foi identificado PostgreSQL nesse fluxo. Não inferir compartilhamento de DB
com Tutor só porque ambos estão no mesmo VPS.

- `flutter_app/lib/main.dart:1047`: `local_record_id` identifica o formulário,
  não a pessoa. `sync_store.py:75` aplica unicidade para entrega.
- `backend.py:244`: `_id` analítico depende de nome/CPF/nascimento; não usar como
  identidade durável, pois correções mudam seu valor.
- `flutter_app/lib/form_schema.g.dart`: área `campo_93`, capacitações
  `campo_95..98`, expectativa `campo_99`, aplicação `campo_100`.
- Cursos no formulário estão em texto, sem equivalência garantida de IDs.
- A configuração Google existente foi validada por metadados, sem ler respostas:
  planilha baseline com `DADOS_CONSOLIDADOS`, `REGISTROS_SCANEADOS` e outras abas.
- O código do backend admite ausência de Bearer configurado; isso é um risco
  de código, NÃO uma afirmação de exposição verificada no serviço publicado.

Próxima fatia de baixa complexidade: vínculo humano no Tutor
`user_id + origem + local_record_id + responsável + data`, sem escrita no
baseline, com contexto pedagógico mínimo e revisão de mentoria por pessoa.
Não associar automaticamente por nome, não reutilizar senhas, não exportar
perfil socioeconômico inteiro para analytics/IA. Ainda não implementado.

## Matriz restante — não confundir infraestrutura com funcionalidade pronta

| Necessidade | Base atual | Falta para aceite |
|---|---|---|
| Cursos sem nova versão | Leitura remota/cache e importador técnico | Editor/publicação/revisão por equipe, histórico editorial e atualização no app aberto |
| Encontros acessíveis | Sessões e evidências/check-in/out existentes | Revalidar linguagem e fluxo com público; presença assistida pela equipe, sem impor QR/token ao aluno |
| Baseline e mentoria | Schema de origem mapeado | Vínculo revisado, histórico, relatório longitudinal e sinalização no painel |
| Analista/Cloudflare | API de analytics e Worker gateway | Painel autenticado com escopo; KV não deve virar réplica de dados pessoais do PostgreSQL |
| Certificados | KV assinado e carteira/referências existentes | Regressão de atualização/reinstalação e comprovação de resgate de certificados antigos; não trocar namespace/chave/IDs |
| Chatwoot mensagens | WebWidget no Flutter | Identidade estável autenticada, entrega/leitura e notificações fora da tela de suporte |
| IA de atendimento | AnythingLLM existente com chaves de API | Adapter bot, dedup de webhook, proteção contra loops, limite de custo, transferência humana testada |
| Design system | Componentes e auditoria de branding existentes | Cobertura visual/estados de todas as novas telas; não declarar completo por mockup |
| Vídeos | Plataforma de media e documento MEDIA_PLATFORM | Titularidade/direitos e decisão canal/CDN; Drive como origem, não tratar como CDN garantida |

Chatwoot: leitura somente confirmou usuários Paulo (12) e Evellyn (13).
O token público configurado em `chatwoot_screen.dart` resolve para a caixa
`Ipex - TDS` (13), que já contém ambos. A caixa `Tutor TDS — Site` (7, sem agentes)
não é a usada pelo app. Nenhuma conta criada, atribuição alterada ou bot ativado.

Adiados do segundo app: migração de identidade, deduplicação entre tablets/Forms,
sincronização bidirecional, previsão automática de mentoria, integração analítica
com dados sensíveis. Manter decisão humana e não confundir falta de conexão com
baixo desempenho.

## Validação incremental

- API local: 15 testes direcionados passaram na execução final, incluindo
  o novo caso A1.
- Flutter: 20 testes de turma/equipe e 5 de catálogo passaram.
- Análise Dart de turma/equipe limpa. SDK correto:
  `C:\Users\Usuario\flutter-3.44.9\bin`; SDK do PATH era incompatível.
- Não foi gerado/instalado novo APK nesta rodada. Validação física pendente.
- Não promover produção nem gerar AAB até atualizar e cumprir o preflight.

## Resultado operacional final

- **Sheets staging validado:** PostgreSQL 421 eventos / Sheets 421 eventos;
  0 ausentes, 0 desconhecidos, 0 duplicados. Todos os 421 em `synced` no banco.
- Readback do sentinela `1789996700697338-6noKE7GFuU9DUYd9:page_viewed:2`
  na linha 420: nove campos de conteúdo idênticos após pseudonimização; usar
  `valueRenderOption=UNFORMATTED_VALUE` para comparar segundos numéricos.
  Replay explícito do mesmo registro manteve as 421 linhas de eventos.
- Durante recuperação do erro A1, 200 eventos de staging com falha HTTP 400
  foram recolocados na fila; payloads e os 400 logs de tentativas anteriores
  preservados. Nenhum registro de aprendizagem excluído/reescrito.
- API e worker staging executam a mesma imagem
  `sha256:fe9828ac00a3050ed1e677d5d1ad0818203421ff8c15fdc4ef5bf709d8a9b2cd`.
  Código `3def64d2f2f8e3421b803d039f1b73327f3fc01e`; arquivo de fontes SHA256
  `ddde9a2268f6b4c0db533d2e95fa3cbaaaec5bfb6fea400d76b18b6a57b197f9`.
  OCI created real `2026-09-21T14:23:54Z`.
- Artefato VPS: `/opt/tutor-tds-sheets-3def64d2f2f8e3421b803d039f1b73327f3fc01e/source.tar`.
- Backup da configuração anterior: `/opt/tutor-tds-staging/.env.before-sheets-20260921T142007727888`
  e `/opt/tutor-tds-staging/docker-compose.before-sheets-20260921.yml`.
- Para retorno à situação anterior a Sheets: parar apenas `sync-worker-staging`,
  restaurar os dois arquivos de configuração preservados e usar a imagem
  `tutor-tds-api:staging-01efa5404919c8c177b7605894b0075a80a5ba6e`.
  Não apagar eventos nem planilhas para efetuar rollback.
- Schema permanece `20260920_0014`; esta rodada não adicionou migrations.
- Health público produção e staging OK; nenhum deploy de produção, alteração
  de KV ou app separado de baseline. Produção Sheets continua preparada, não
  ativada; exige conferir compatibilidade da API/banco implantados antes de ligar.

Próxima ordem: editor de cursos/publicação, presença assistida e vínculo baseline
manual; depois adapter Chatwoot com transferência humana e painel analítico.
Somente ao concluir os critérios de cada fluxo reabrir o gate da Play Console.

## Continuidade — editor e versões (implementação local)

Fatia A integrada em código e descrita em
[COURSE_VERSIONING_SLICE_2026-09-21.md](COURSE_VERSIONING_SLICE_2026-09-21.md).
Inclui lifecycle editorial, snapshots imutáveis, turma fixada em edição,
progresso isolado, eventos versionados e seed sem sobrescrita. A migração 0015
existe localmente, mas o VPS continua na 0014 até deploy verificado.
Não confundir isso com conclusão das ondas. Há gates explícitos para PostgreSQL,
Xiaomi, promoção de conteúdo, cache privado e certificados de cursos dinâmicos.
