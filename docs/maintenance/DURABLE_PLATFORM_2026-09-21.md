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
Existem caixas WebWidget `Tutor TDS — Site` (7, sem agentes) e `Ipex - TDS` (13,
contém ambos). É necessário identificar qual token o app usa antes de alterar
atribuições. Nenhuma conta criada, nenhum bot ativado nesta inspeção.

Adiados do segundo app: migração de identidade, deduplicação entre tablets/Forms,
sincronização bidirecional, previsão automática de mentoria, integração analítica
com dados sensíveis. Manter decisão humana e não confundir falta de conexão com
baixo desempenho.

## Validação incremental

- API local: 14 testes direcionados passaram antes do ajuste A1; depois, todos
  os 9 testes de sync passaram incluindo o novo caso A1.
- Flutter: 20 testes de turma/equipe e 5 de catálogo passaram.
- Análise Dart de turma/equipe limpa. SDK correto:
  `C:\Users\Usuario\flutter-3.44.9\bin`; SDK do PATH era incompatível.
- Não foi gerado/instalado novo APK nesta rodada. Validação física pendente.
- Não promover produção nem gerar AAB até atualizar e cumprir o preflight.

## Resultado operacional final

Pendente de completar nesta execução: reconciliação, replay sem duplicação,
readback do evento sentinela e saúde de produção após correção A1.
