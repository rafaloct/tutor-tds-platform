# Contas gerenciadas e perfis — 2026-09-21

O cadastro público (`POST /auth/register`) continua criando somente alunos.
Perfis operacionais não devem ser escolhidos livremente pelo cliente.

## Fluxo consolidado

Um administrador autenticado usa `POST /admin/accounts` com nome, CPF,
telefone, senha, `role` e `program_id`. A API cria `users.role` e o
`program_memberships` ativo na mesma transação. Em caso de falha, nenhum dos
dois registros é confirmado.

Papéis aceitos: `student`, `teacher`, `monitor`, `creator`, `coordinator`,
`finance` e `admin`. A resposta não devolve CPF nem senha.

## Regras

- apenas token com papel global `admin` pode criar contas gerenciadas;
- o programa precisa existir;
- CPF duplicado continua retornando conflito;
- o vínculo de programa é explícito e auditável;
- produção não deve receber novos perfis até a imagem candidata ser validada;
- staging deve usar uma conta administrativa de homologação provisionada pelo
  procedimento de bootstrap, nunca credenciais inventadas no cliente.

## Evidência de homologação

Em 21/09/2026, a conta administrativa sintética foi criada no staging pela
rota consolidada e validada com login (`200`) e leitura da hierarquia
administrativa (`200`). O APK DEV no Xiaomi `ZT6HPRHQHATSEQPR` permaneceu em
primeiro plano sem `FATAL EXCEPTION` no logcat. As credenciais não são
registradas neste documento.
