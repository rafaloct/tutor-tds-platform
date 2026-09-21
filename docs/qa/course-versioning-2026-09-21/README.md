# QA real — versões, turmas e fila offline — 2026-09-21

Resultado: progresso verificável em staging; **NO-GO para publicação**.
Não encerra Ondas 1–4 nem Freeze/QA. Produção e baseline não alterados.

## Proveniência e preservação

- Backend implantado: `ac03fbcf4767d967f72a6d449435918383352188`.
- Imagem: `tutor-tds-api:staging-ac03fbcf4767d967f72a6d449435918383352188`.
- Image ID: `sha256:8f80949e4a6c6e0ede3e89aae9c5246f7f02119105da8707ad65eab52dea4d0d`.
- Arquivo-fonte SHA256: `e77d0e1852f0817db009c11fffbc412cc872917820e69ab1346f2e13f9b8ed16`.
- Diretório VPS: `/opt/tutor-tds-course-ac03fbcf4767d967f72a6d449435918383352188`.
- Backup anterior à migração: `before-0015.dump`, SHA256
  `7e7015719922d5d75848e9530684d9f761d59e7b6dc7b3f69adf945c7e2ea6c0`.
  `pg_restore --list` aceitou o arquivo; não equivale a ensaio de restauração.
- Migração `0014 → 0015`: hashes e contagens das 17 tabelas iguais antes/depois,
  excluindo apenas a nova coluna `classes.course_version_id` da comparação.
  Backfill, FK composta e trigger de imutabilidade verificados no PostgreSQL.
  Ver `migration-audit.json`; usar o modo verify somente no primeiro backfill.
- Staging inicialmente tinha apenas um curso sintético. Nove cursos reais foram
  importados dos assets existentes duas vezes, sem duplicação/sobrescrita.

## API real e aparelho

`api/ops/smoke_course_editor_staging.py --run-id course-qa-20260921-a` exerceu
login/refresh, permissões, edição/CAS409, revisão/publicação, versão 2,
matrícula idempotente e replay de eventos. Registros sintéticos foram mantidos.
Não repetir o mesmo run-id; o script não é limpeza nem migração de produção.

Identificadores sintéticos rastreáveis:

- Curso: `staging-editor-course-qa-20260921-a`.
- Versão 1: `c276ae19-3f49-4271-99ae-2a367e04d517`.
- Versão 2: `9ffa7d51-e32f-41ea-b90d-026b8fc417b8`.
- Turma v1: `8d7e5869-cdd6-4ebe-a94e-2de91c0e7399`.
- Turma v2: `3bd8415e-dbe3-4c2c-b0a8-730d1c42f627`.

Xiaomi `ZT6HPRHQHATSEQPR`, pacote DEV separado. A turma abriu “Primeira edição
preservada” com a segunda já pública. Conteúdo foi concluído sem rede; dois
eventos permaneceram na fila e foram enviados ao retomar o app conectado.
Wi-Fi e dados móveis restaurados e conferidos em estado 1.

Sessão física: `1790003586520603-dCSgCw4khgE4JEjJ`.
Eventos `lesson_started`, `study_activity:1` (33 segundos validados) e
`lesson_completed` chegaram com versão e turma corretas ao PostgreSQL.
Leitura nativa limitada do Google Sheets confirmou linhas 432–434, incluindo
atividade e conclusão sincronizadas às `2026-09-21T15:15:16.607893Z`.
Isso não comprova presença formal nem elegibilidade automática a certificado.

## Sheets: decisão confirmada

Planilhas separadas para produção e testes; não adicionar abas/eventos Tutor no
baseline. PostgreSQL permanece registro transacional; a planilha é projeção
pseudonimizada, não um segundo cadastro concorrente de alunos.

- Staging ativo: `1YpEF-1zdbLwjbkff5fyqYo9FhdPDwFQBA2Uwl0Gsy14`, aba
  `EventosAPI-Staging`. Conferência read-only via Google Drive/Sheets.
- Produção preparada, sincronizador ainda não ativado:
  `1AshF-drgHCb4NEsI2f_DCLDXk75Olp1pdfUG1p7cj6k`.
- Baseline intacto: `1MNM2QgA8xbneQoBFmlsbP7kgOIdGoh5wD_w8tIRP5TE`.

## Correções e limites da evidência visual

As imagens `student-pinned-v1.png` e `student-completed-offline.png` são anteriores
à correção visual. Revelaram progresso prematuro em 100% e Tutor sobrepondo ações.
Corrigido: progresso por mensagens avançadas; Tutor na AppBar; certificado mantido
após conclusão. Dois widget tests verificam alternativas/Continuar acessíveis,
progressão 0 → 1/3 → 2/3 → 1 e retomada no último módulo sem falsa conclusão.

APK inicial SHA256: `9cd61e9ccad97866870bec37a08ca136d7a48cd0184eb3248b0bad673e2dde4d`.
APK corrigido, instalado com `-r`, SHA256:
`09e04fc9278e8ced51f3a2314a4269694a7631a00e032bd810977d013c1e3f50`.
Build debug arm64, `config/staging.qa.json`, gateway IA vazio intencionalmente.
App publicado `com.tutortds_cartilhas` permaneceu 1.2.0+11; não foi substituído.

A hierarquia UI posterior mostrou Tutor na AppBar e progresso parcial de 6%.
Entretanto, a captura `tutor-context-after-install.png` mostrou outra tela, a
abertura contextual do Tutor. Não é evidência visual suficiente da regressão do
leitor; repetir com sessão de aparelho estável antes de aprovar o gate.

Validação local final: 143 testes API e 214 Flutter passaram. A primeira execução
da API na raiz falhou por não localizar `alembic.ini`; repetição em `api/` passou.
Warnings de depreciação httpx/anyio e futura migração Kotlin permanecem, sem
atualização de dependências nesta rodada.

Promoção de conteúdo tem oito testes locais e dry-run padrão; esse utilitário
não está na imagem ac03 implantada. Não houve promoção de conteúdo para produção.
Pendências: UI editorial física, acessibilidade ampliada, reabertura privada
offline, certificados dinâmicos, promoção real ensaiada e fatias B–F. Gate de
release continua fechado; AAB antigo não deve ser enviado.
