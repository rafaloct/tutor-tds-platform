# Fatia A — editor e versões de cursos

Estado: editor/versionamento implantado e exercitado no PostgreSQL staging;
promoção explícita implementada localmente; **não liberada para produção**.
Esta fatia não encerra as Ondas 1–4 nem o Freeze/QA da Onda 5.

Validação local atualizada: **143 testes API** e **214 testes Flutter** passaram;
análise Dart dos arquivos alterados sem problemas. A suíte API também revelou
que o carregamento de configuração Alembic desabilitava o logger de rastreio
quando executado no mesmo processo; corrigido com `disable_existing_loggers=False`.
Os testes de preservação de rastreio e retry voltaram a passar na suíte completa.

## Regras implementadas

- Professor/creator edita seus rascunhos dentro de programa autorizado. Coordenação
  e administrador revisam/publicam no escopo permitido. O papel global `student`
  não impede uma capacidade de professor decorrente de vínculo institucional.
- Publicar cria projeção pública, arquiva a edição anterior e conserva seu snapshot.
  A edição publicada não pode ser sobrescrita pelo editor. Alterações passam por
  novo rascunho, revisão e publicação, com revisão CAS/HTTP 409 e trilha de atores.
- Cursos ofertados por vários programas exigem autoridade de publicação em todos
  os programas vinculados, pois compartilham o catálogo público.
- Migração `20260921_0015` preserva os IDs dos cursos, cria versões UUID5 para
  conteúdo legado e fixa a versão das turmas existentes. Conteúdos e módulos
  recebem identidades/versionamento sem modificar os JSONs originais dos cursos.
- Reimportação de seed idêntico é idempotente. Conteúdo diferente cancela a
  transação e orienta criar nova versão; não sobrescreve curso já cadastrado.
- Perguntas/quiz precisam de alternativas e quiz precisa de gabarito antes de
  revisão/publicação. Rascunhos incompletos continuam editáveis.
- Exclusão autorizada de antiga conta creator anonimiza autoria/auditoria,
  preservando snapshots e transições institucionais. Contas ainda vinculadas à
  equipe continuam no fluxo assistido já existente.

## Rotas e telas

| Fluxo | Contrato |
| --- | --- |
| Capacidades e programas | `GET /editor/context` |
| Meus conteúdos por programa | `GET /editor/courses?program_id=...` |
| Edição/histórico | `GET /editor/courses/{id}?version_id=...` |
| Criar rascunho | `POST /courses` |
| Salvar módulos e conteúdos estruturados | `PATCH /courses/{id}` com `version_id` e `expected_revision` |
| Revisar/publicar/arquivar | `POST /courses/{id}/submit`, `/publish`, `/archive` |
| Nova edição | `POST /courses/{id}/versions` com `source_version_id` |
| Catálogo público | `GET /courses` e `GET /courses/{id}` — continua sem login |
| Turmas do aluno | `GET /classes?enrolled_only=true` — matrícula ativa |
| Conteúdo fixado na turma | `GET /classes/{id}/course` — edição publicada/arquivada autorizada, sem fallback para catálogo |

Flutter: entradas “Meus conteúdos” e “Minhas turmas”, editor estruturado,
pré-visualização sem eventos/progresso/certificados, proteção contra perda de
edição ao sair, confirmação de recarga após conflito e histórico de versões.
As rotas novas têm identificadores de telemetria estáveis.

## Aprendizagem e preservação

`lesson_started`, `lesson_completed` e `study_activity` recebem opcionalmente
`payload.course_version_id` e `payload.class_id`. O backend valida a associação
exata aluno–matrícula–turma–edição. Isso também evita escolher uma matrícula
arbitrária quando o aluno participa de dois programas para o mesmo curso.
Os campos chegam ao `payload_json` do Sheets; identidade do aluno/sessão continua
pseudonimizada. Payloads legados continuam aceitos.

Replay offline público de versão arquivada só é aceito dentro da janela auditada
de publicação (inclusiva) a arquivamento (exclusiva); com turma informada a
matrícula exata é obrigatória. Versões nunca publicadas não são aceitas.

Progresso novo é separado por curso/versão e, na turma, por conta. Histórico
legado permanece no aparelho; somente a edição original pública pode retomá-lo
por compatibilidade. A Home não usa avanço de edição antiga para abrir nova.
O leitor conta question/quiz, não falas `user`, como questões respondidas.
Nenhum certificado existente, namespace KV ou chave de assinatura foi alterado.

## Portões ainda abertos — não omitir na continuidade

1. Migração staging concluída com backup, imagem rastreável e preservação dos
   hashes das 17 tabelas auditadas. Editor, permissões, duas publicações,
   matrícula e replay exercitados pela API real; evidências em
   `../qa/course-versioning-2026-09-21/README.md`.
2. APK DEV instalado: turma manteve edição anterior, conclusão offline chegou
   ao PostgreSQL e Sheets após reconexão. Ainda validar UI de professores/
   coordenadores, fonte ampliada, conflitos e regressão visual no aparelho.
   Correções de progresso e Tutor sobreposto passaram nos testes e foram
   instaladas; isso não aprova o gate físico completo em `release_status.json`.
3. Promoção explícita implementada em `api/app/course_promotion.py`, com
   manifesto SHA256, identidade preservada e dry-run padrão. Oito testes locais
   passaram; ainda não aplicada entre ambientes reais. Não clona bancos.
4. Fechar disponibilidade offline de **reabertura** da área de turmas. Esta
   versão consulta associação/edição online e mostra falha explícita, sem abrir
   silenciosamente outra versão; o cache público não é cache privado de turma.
5. Integrar certificados de cursos novos/versionados ao gateway. O Worker atual
   mantém `CERTIFICATE_COURSES` estático em `src/index.js`; isso é uma lacuna
   concreta para cursos dinâmicos. Preservar resgate/verificação dos antigos.
6. Rever fluxo de devolver revisão para correção (hoje lifecycle linear),
   atribuição de eventos públicos offline estudados após arquivamento e
   interpretação longitudinal de progresso entre edições. Não inventar presença
   formal ou validade de certificado a partir desses eventos.
7. Continuar B presença assistida → C baseline/mentoria → D analytics →
   E suporte Chatwoot → F IA/notificações. O objetivo completo permanece aberto.

## Separação dos dados reafirmada pelo usuário

Tutor usa planilhas distintas para produção e testes. Baseline permanece intacto.
Staging Sheets está ativo e recebeu eventos do teste físico; produção Sheets
permanece preparada, não ativada. A escolha de planilhas separadas foi confirmada
expressamente pelo usuário. Baseline, produção, KV, Chatwoot e credenciais não
foram modificados nesta rodada. Mudanças remotas foram limitadas a staging:
migração, imagem API/worker, importação idempotente dos nove cursos e registros QA.
