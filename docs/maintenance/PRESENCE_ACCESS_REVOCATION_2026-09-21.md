# Fatia B — revogação de acesso às evidências

Estado: correção local, não implantada. Staging continua na imagem `04204c1`.

## Lacuna comprovada

Em `api/app/evidence.py`, a atribuição antiga de professor/monitor era suficiente
para acesso mesmo após desativar o vínculo no programa. O aluno era conferido
somente em `class_enrollments`, sem verificar a matrícula acadêmica ou vínculo
ativo com o programa. No check-in, `user_id` de terceiro enviado por um aluno
era silenciosamente ignorado, em vez de rejeitar a operação divergente.

## Alteração mínima

- Reutilizadas as funções locais de autorização e tabelas existentes.
- Administrador global mantém o escopo administrativo existente.
- Professor da turma exige vínculo ativo de professor/coordenador/admin no
  programa; monitor atribuído exige vínculo ativo com papel de equipe.
- Leitura de sessões e exceções pelo aluno, check-in próprio/manual e importação
  vinculada a aluno verificam turma ativa, matrícula ativa e programa ativo,
  incluindo consistência de pessoa/programa/curso na associação.
- A verificação ocorre antes do retorno idempotente: chave antiga não restaura
  permissão revogada. Aluno não pode enviar presença em nome de outra pessoa.
- Sem schema novo, sem novo serviço de capabilities e sem mudança Flutter.

## Evidência

Comando: `.venv/Scripts/python.exe -m pytest tests/test_evidence.py tests/test_classrooms.py tests/test_auth.py -q -o addopts='' --disable-warnings`

**13 testes passaram**, com dois avisos de depreciação já existentes. Os cenários
adicionados cobrem revogação e rebaixamento de professor/monitor; desativação do
programa, matrícula ou turma do aluno; bloqueio de registro manual para matrícula
revogada; replay de chave antes bem-sucedida; alvo divergente e acesso restaurado.

## Limites e próxima implementação funcional

Isto corrige a autorização da API de evidências, não toda a política transversal
de acesso do aplicativo. Outros módulos têm verificações próprias e não foram
reescritos nesta etapa. Não foi executada novamente a suíte completa, nem testes
de PostgreSQL/dispositivo para esta mudança.

A fatia B permanece aberta: o modelo atual tem check-in/check-out, evidência
pending/accepted/rejected e relatório de sessão, mas ainda não oferece todo o
estado formal solicitado (`pending`, `suggested_present`, `confirmed_present`,
`justified_absence`, `absent`) por pessoa/sessão. Não interpretar QR ou contagem
de check-ins como presença formal confirmada. Falta fechar essa decisão humana
e a apresentação correspondente, além do gate físico de offline/sincronização.

Produção, certificados e dados do VPS não foram modificados nesta etapa.
