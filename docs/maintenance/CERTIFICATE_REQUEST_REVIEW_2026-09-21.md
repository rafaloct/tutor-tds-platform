# Certificados — pedido e revisão humana

Estado atualizado: API implantada e validada em **staging**, sem ativação em produção.
Evidência: `../infrastructure/CERTIFICATE_REQUESTS_STAGING_2026-09-21.md`.
As seções de verificação local abaixo registram a etapa anterior ao deploy.
Esta fatia implementa a decisão do usuário de analisar certificados por matrícula
e edição. Não implementa ainda assinatura, emissão ou migração da carteira.

## Contrato e proteção dos dados

- `GET /certificate-requests/contexts`: matrículas próprias ativas, edição
  publicada/arquivada e vínculos de turma válidos. Não aceita nome/CPF ou horas
  declaradas pelo cliente para criar o pedido.
- `POST /certificate-requests`: snapshot de nome, curso, programa, instituição e
  carga horária. Um pedido por matrícula/edição; repetição retorna o mesmo pedido.
  Contexto de turma diferente retorna 409, sem sobrescrever o pedido anterior.
- `GET /certificate-requests` e `GET /certificate-requests/{id}`: consulta privada
  pelo titular ou equipe com escopo autorizado.
- `GET /certificate-requests/review-queue`: somente pendentes de outras pessoas,
  filtrados no SQL pelo escopo. Administrador global, coordenação/administração
  ativa do programa ou professor ativo proprietário da turma podem revisar.
  Monitor não recebe autoridade de aprovação. Ninguém aprova o próprio pedido.
- `POST /certificate-requests/{id}/review`: decisão humana e justificativa de
  3–500 caracteres; revisão esperada evita decisões concorrentes sobrescritas.
  Aprovar revalida vínculos, instituição, conclusão e tempo validado no servidor.
- `POST /certificate-requests/{id}/resubmit`: somente o titular reabre um pedido
  rejeitado, explicitamente, com controle de revisão. O histórico é preservado.

Evidência de turma exige matrícula, edição e turma exatas. Pedido individual
agrega evidência da mesma matrícula/edição, inclusive de turmas dessa edição.
Eventos antigos sem versão só contam para a edição original determinística e
pedido individual, nunca para outra edição ou pedido de turma.

A migração `20260921_0016` cria duas tabelas, sem reescrever certificados ou
conteúdos antigos. Constraints e triggers protegem snapshots, transições e
histórico; a exclusão da conta elimina os pedidos privados do titular. Ao excluir
um antigo revisor, seu identificador é anonimizado no histórico de terceiros,
preservando decisão, papel, justificativa e data.

## Flutter e experiência

O leitor agora abre “Solicitar certificado”, sem chamar a emissão legada direta.
A navegação também funciona em cursos expositivos sem perguntas. Contadores
locais não concedem aprovação. A carteira abre pedidos próprios; a área de equipe
abre a fila de revisão, sujeita à autorização real da API.

A tela distingue “Aguardando análise”, “Precisa de ajustes” e **“Aprovado — emissão
pendente”**. Não oferece PDF de um pedido apenas aprovado. Mostra turma e permite
consultar matrícula/edição/pedido; um pedido já aberto em outro contexto é
identificado, evitando uma duplicação impossível. O nome de turma é o nome atual,
não parte do snapshot acadêmico imutável.

Operações exigem rede e sessão. O repositório é vinculado à primeira conta usada
e valida a conta antes/depois das requisições. Não usa a fila de revisão como
probe de permissão; erro 401 limpa os dados da tela.
Não há fila offline de aprovação. Analytics registra identificadores de
página/recurso/ação sem nome, justificativa ou evidências acadêmicas.

## Verificação local

- Suíte Flutter completa: **270 testes passaram**.
- Repositório/tela de pedidos: **28 testes passaram**, novamente após o último
  reforço de sessão. Inclui fonte 200%, concorrência/409, conta trocada, contexto
  de outra turma, pedido pendente, reapresentação e aprovação sem emissão.
- Análise Dart dos arquivos alterados: sem problemas.
- Suíte backend completa: **162 testes passaram**. Testes incluem
  idempotência e revisão concorrentes, autorizações, evidência por edição,
  snapshot, triggers, exclusão de conta e preservação de certificado legado.
- Testes locais de banco usam SQLite. Migração/triggers PostgreSQL e o fluxo no
  Xiaomi com estas telas novas ainda **não foram validados**.

## Próximas condições de liberação — obrigatórias

1. Implantar a migração/API em staging com backup, proveniência da imagem e
   verificação de preservação dos registros; validar triggers em PostgreSQL.
2. Concluir reserva/idempotência da emissão e canal autenticado API → Worker,
   com schema versionado que preserve assinaturas e verificação dos antigos.
3. Fechar o bypass da emissão legada com plano de compatibilidade para o app
   publicado; não desligar produção antecipadamente.
4. Isolar a carteira por conta/matrícula/edição sem eliminar documentos antigos;
   alinhar hash e endpoints de verificação API/Worker.
5. Validar ponta a ponta aluno → equipe → emissão → KV → carteira, retries,
   dados/eventos, acessibilidade e dispositivo físico antes de qualquer release.

Paginação das filas/listas e aferição de consultas por pedido permanecem pendentes
para validação de escala. O filtro SQL de autorização não substitui esse teste.
Produção, Worker, KV, Sheets e certificados existentes não foram alterados nesta
fatia. As demais ondas continuam abertas; não há autorização técnica de release.

## Fechamento delimitado da integração de turma

Decisão do usuário: revisão aberta pelo dashboard fica restrita à turma
selecionada e à edição correspondente. O dashboard passa `classId`, `courseId`
e `courseVersionId` (quando disponível); o botão fica indisponível enquanto
carrega ou se o dashboard não corresponde à seleção. O filtro da tela de revisão
combina os três campos; a API continua impondo o escopo autorizado completo.
Esse filtro de apresentação não concede nem substitui autorização.

`TeamCapabilityResolver` existente foi preservado. Não foi encontrado endpoint
de capability específico para revisão de certificados: `/auth/me` fornece papel
global e `/editor/context` trata de publicação de cursos, regras não equivalentes.
O atalho baseado em `reviewQueue()` foi removido dos pedidos próprios, mantendo
a entrada pela equipe. Não foi criado novo endpoint ou sistema de capabilities.

Cobertura acrescentada: professor com duas turmas, professor em A/monitor em B,
mudança da capacidade ao selecionar B, parâmetros reais da navegação e exclusão
de pedidos de outra turma/edição na revisão. Um teste integrado da API percorre
contexts → criação → releitura → fila autorizada → decisão → SQL/auditoria →
releitura pelo aluno. Usa identidade substituída na fixture e SQLite; não é teste
de login real, Flutter conectado à API, PostgreSQL ou dispositivo físico.

Critério de parada desta integração: testes locais e análise passando. Emissão,
deploy, validação real de staging e aperfeiçoamentos visuais permanecem fora
deste recorte; não confundir este fechamento com conclusão das ondas.

Resultado Flutter deste fechamento: **274 testes passaram**, análise dos quatro
arquivos Dart alterados sem problemas. Suíte API completa: **163 testes passaram**
(dois avisos de depreciação de dependências, sem falhas). Nenhuma mudança em implementação backend,
migração, Worker, produção ou mecanismo de capabilities nesta integração.

## Gate de compatibilidade para emissão

O bypass entre a rota legada de referências e a aprovação humana foi isolado
por configuração no commit `032c769`. `CERTIFICATE_APPROVAL_REQUIRED=false`
mantém o contrato do aplicativo publicado durante a migração. Quando ativado
no staging, `POST /certificates/references` exige um pedido aprovado para a
mesma matrícula/edição e, quando informada, turma correspondente; pedido
ausente ou turma divergente retorna `422`. A aprovação não emite o documento
por si só: Worker autenticado, reserva/idempotência, assinatura, KV e carteira
ainda precisam de validação ponta a ponta. Não ativar em produção antes de
testar o aplicativo publicado e preservar referências antigas.

Regressão após o gate: **207 testes API passaram**, com dois avisos de
depreciação conhecidos. A flag permanece desligada em todos os ambientes.
