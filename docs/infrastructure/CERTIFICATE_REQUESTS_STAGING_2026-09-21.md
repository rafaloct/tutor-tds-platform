# Pedidos de certificado — validação real em staging

## Resultado

API e sincronizador de staging atualizados para o código `04204c1cde6141eed1bd2c5a81a0cb039ed621c6`.
Migração PostgreSQL `20260921_0015 → 20260921_0016` aplicada. Teste público de
health/cursos passou; API e worker estão em execução com a mesma imagem.
Produção, Worker Cloudflare e KV não foram alterados. Nenhum certificado emitido.

## Proveniência e backup

- Fonte: `git archive HEAD api`, SHA256
  `7241632a6fdf7171528abcf7bd3d1a24eaf4bac90905f20948ba03739ec9a104`.
- Imagem: `tutor-tds-api:staging-04204c1cde6141eed1bd2c5a81a0cb039ed621c6`.
- Referência de imagem observada em API e worker:
  `sha256:1f31398fee8560b98488a99eb00d80d3cb683113d0e87a71050db9bffba91a4e`.
- Fonte extraída no VPS: `/opt/tutor-tds-04204c1/api`.
- Backup pré-migração: `/root/tutor-tds-backups/certificate-04204c1/before-0016.dump`,
  SHA256 `87e73cf0b23b03e9b55691a9f156a2aed857c47eb35f6032d7ea417c39c03641`.
  Diretório com modo 0700; `pg_restore --list` aceitou o arquivo. Isso **não**
  equivale a um teste de restauração integral.
- Script existente de deploy verificou labels OCI, migração, health e igualdade
  de imagem API/worker. Imagem anterior `staging-ac03fbcf4767d967f72a6d449435918383352188`
  preservada. Não houve limpeza de backups/imagens.

## Preservação e histórico

Os arquivos `before.json` e `after.json` no diretório do backup registram contagens
e hashes iguais nas 17 tabelas cobertas por `audit_course_version_migration.py`,
incluindo cursos, usuários, matrículas, certificados, eventos e evidências.
Limite do auditor reaproveitado: não cobre todas as tabelas e omite o campo
`classes.course_version_id`; não interpretar como prova de igualdade de todo banco.

Em PostgreSQL, `audit_certificate_requests_staging.py` conferiu a persistência das
transições pending → rejected e a autoria do professor sintético. Tentativas de
alterar snapshot, reescrever justificativa histórica e excluir transição foram
barradas pelos triggers. Cada tentativa foi revertida em transação.

## Fluxo autenticado verificado

`smoke_certificate_requests_staging.py` executado duas vezes no VPS, usando
credenciais sintéticas protegidas, sem imprimir CPF, senha ou tokens:

1. Login real de aluno/professor e conferência das identidades por `/auth/me`.
2. Contexto da matrícula/turma/edição existente; criação do pedido e releitura.
3. POST repetido retorna o mesmo identificador; aluno não acessa fila da equipe.
4. Professor recebe o pedido autorizado; aluno não pode decidir o próprio pedido.
5. Aprovação sem critérios suficientes retorna 422; não se fabricou carga horária.
6. Professor registra “pedir ajustes”; decisão repetida com revisão antiga dá 409.
7. Aluno relê a decisão; pedido sai da fila de pendentes. Segunda execução mantém
   o mesmo pedido e revisão, sem produzir outra decisão.

Identificadores sintéticos para rastreabilidade:

- Pedido: `1df9d709-29f4-4163-8a7f-42223ea78b76`, revisão 2, `rejected`.
- Turma: `8d7e5869-cdd6-4ebe-a94e-2de91c0e7399`.
- Edição: `c276ae19-3f49-4271-99ae-2a367e04d517`.
- Curso: `staging-editor-course-qa-20260921-a`.

Os scripts novos foram copiados à parte e não compõem a imagem do commit acima;
são evidências operacionais executadas contra essa imagem. Pedido/histórico foram
preservados no staging para consulta, não apagados depois do teste.

## O que não está provado

Não foi feito nesta etapa teste Flutter conectado às novas rotas no Xiaomi,
aprovação positiva com horas reais suficientes, emissão assinada, carteira nova,
notificação ou projeção dos pedidos no Sheets. O sincronizador estar rodando não
prova que pedidos/decisões foram exportados: sua persistência foi verificada em
PostgreSQL. A publicação continua bloqueada; as demais ondas não estão concluídas.
