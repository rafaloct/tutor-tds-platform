# Turmas offline e decisão de certificados — 2026-09-21

Estado: cache privado implementado e reabertura fria validada no Xiaomi.
Negativas de acesso/troca de conta foram testadas localmente; ainda falta sua
validação física. Não houve deploy de backend/Worker nem alteração de produção;
o teste DEV enviou eventos sintéticos ao staging existente.

## Reabertura offline

`LearnerOfflineRepository` envolve o gateway existente somente na tela
“Minhas turmas”. O catálogo público e os painéis de equipe não usam esse cache.

- Lista validada pela API `/classes?enrolled_only=true` e conteúdo obtido por
  `/classes/{id}/course`; somente a edição fixada na turma é salva.
- Chave por ambiente (hash da URL da API) e sujeito da sessão no armazenamento
  seguro. `localUserId()` apenas seleciona dados já confirmados pela API: não
  valida assinatura JWT nem concede autenticação/papel/permissão de servidor.
- Sem token local, após troca de conta ou em outro ambiente: cópia inacessível.
  Nomes de pessoas, CPF, colegas, professores e monitores não são armazenados.
  Metadados mínimos da turma e conteúdo ficam nas preferências privadas do app.
- Validade inicial conservadora de sete dias, tanto da lista quanto da última
  abertura autorizada do conteúdo. Atualizar a lista não renova a autorização
  do conteúdo. Relógio anterior ao salvamento não concede acesso.
- Fallback somente em timeout/erro de transporte. HTTP e JSON inválido não são
  interpretados como ausência de rede. 401/403/404 invalidam a autorização local,
  inclusive quando a autenticação já limpou os tokens.
- A revogação remota não é detectável sem conexão: uma cópia previamente obtida
  pode ser lida até vencer a janela offline. O servidor continua validando
  matrícula/versão ao receber eventos; não há concessão de certificado offline.
- Lista online vazia remove cópias antigas; mudança de pin descarta edição velha.
  Dados locais corrompidos não impedem uma resposta online válida de reparar o
  cache. Turmas planejadas/encerradas continuam legíveis quando a API autoriza.
- Ao abrir offline, a tela informa que o conteúdo está salvo e o progresso será
  enviado posteriormente. Eventos continuam carregando versão/turma. Nenhuma
  substituição silenciosa pelo catálogo público é feita.
- Exclusão local de dados limpa também o cache. Logout impede acesso, mas não
  apaga o conteúdo: a mesma conta poderá reutilizá-lo dentro da validade.

Cobertura específica: reabertura fria, conta/ambiente, prazo/relógio, respostas
401/403/404/500, revogação, lista vazia, pin diferente, troca de conta durante
requisição, conteúdo vencido, corrupção, planned/closed e UI com fonte 200%.
Não extrapolar os testes locais para validação física ou prontidão de produção.

### Evidência física desta etapa

- Suíte Flutter completa: **242 testes passaram**. Análise dos arquivos alterados
  sem problemas. Build debug arm64 em `config/staging.qa.json` instalado com `-r`
  apenas em `com.tutortds_cartilhas.dev`; dados preservados.
- APK SHA256: `c35f36f905df4f8c8ce0f89abed5cd8de9e50eedd2bb992da8eaf632a4adf0f2`.
- Conta sintética `staging-qa-student`; cache online verificado em
  `2026-09-21T15:46:11.397321Z`, duas turmas e uma edição baixada:
  `c276ae19-3f49-4271-99ae-2a367e04d517`.
- Desligados Wi-Fi/dados, force-stop e reabertura do DEV. “Minhas turmas”
  reapareceu com aviso offline e a turma QA abriu a cópia local, preservando o
  estado de conclusão salvo. Não houve emissão de certificado.
- Capturas inspecionadas: `../qa/course-versioning-2026-09-21/cold-offline-class-list.png`
  e `cold-offline-class-reader.png` na mesma pasta.
- A fila tinha sete eventos após a reabertura offline; ficou vazia após retomar
  o app conectado. PostgreSQL confirmou
  `1790005648575243-oPiSgQlL6vuGnApF:lesson_started`, `sync_status=synced`, vínculo
  de matrícula e payload com versão acima e turma
  `8d7e5869-cdd6-4ebe-a94e-2de91c0e7399`. Esse status é evidência do worker;
  não foi feita nova leitura nativa da linha Sheets nesta etapa.
- Para eliminar divergência de coordenadas do ADB, testado temporariamente em
  resolução nativa 1220×2712. Override anterior 1080×1920 restaurado; Wi-Fi e
  dados móveis conferidos novamente em estado 1. Densidade não alterada.
- O gate físico completo segue pendente: revogação e troca de conta no aparelho,
  papéis editoriais, leitura parcialmente concluída e avaliação visual integral.
  A captura também mantém o texto/botão legado de emissão de certificado; a
  nova política abaixo ainda precisa substituir esse fluxo antes da liberação.

## Certificados: decisão explícita do usuário

Em resposta à pergunta desta tarefa, foi escolhida emissão **por edição e
matrícula, com aprovação humana após conclusão e carga horária validadas**.
Preservar todos os certificados antigos e suas formas de verificação.

Auditoria somente leitura do código encontrou:

1. Worker `src/index.js` emite em `POST /v1/certificates` usando contadores do
   cliente e mapa fixo dos nove cursos. Não consulta a elegibilidade da API.
2. API `app/certificates.py` registra referências depois da emissão; essa etapa
   não impede a emissão anterior. A verificação deve alinhar `hash` do Worker
   com o contrato da API e distinguir endpoint JSON de URL pública HTML.
3. Flutter emite diretamente no Worker e a carteira busca apenas por curso.
   Não há isolamento completo por conta/matrícula/edição nesse fluxo legado.

Próxima implementação exigida, ainda não entregue:

- Pedido autenticado e autorização humana auditada no escopo correto, com
  evidências validadas por matrícula/edição; o solicitante não aprova a si mesmo.
- Snapshot acadêmico imutável, identidade estável, idempotência e estado de
  emissão em PostgreSQL; assinatura solicitada ao Worker por canal autenticado.
- Novo schema versionado sem alterar canonicalização/assinatura dos antigos;
  preservar chaves KV, resgate e rotas públicas de verificação existentes.
- Impedir que emissão irrestrita legada contorne a nova aprovação, com plano de
  compatibilidade e ativação controlada para o app já publicado. Não desligar
  produção nesta etapa nem fingir que manter o endpoint aberto resolve o gate.
- Carteira Flutter por conta/matrícula/edição, mantendo os arquivos antigos;
  UI de solicitar, aguardando revisão, aprovado/emitido e motivo de negativa.
- Testar API ↔ Worker ↔ KV ↔ Flutter, concorrência/retries e legados antes de
  ativar produção. Conclusão local de cartilha não prova aprovação acadêmica.

O gate de release continua fechado. As fatias B–F e a validação integral das
Ondas 1–4/Freeze permanecem no objetivo; esta etapa não reduz seu escopo.
