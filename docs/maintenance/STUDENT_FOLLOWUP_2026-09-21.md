# Acompanhamento: baseline e mentoria

Estado: implementação local em andamento; não implantada. Não há ainda tela
integrada nem evidência ponta a ponta desta fatia.

## Reaproveitamento confirmado

O app de formulários permanece independente e somente foi lido seu código.
Em `flutter_app/lib/main.dart:1047`, o ID combina identificação do tablet e
milissegundos. O valor é gravado como `local_record_id` junto ao `timestamp`.
Portanto ele identifica uma coleta, não a identidade durável de uma pessoa.
Não associar por nome/CPF, nem exigir que esse identificador seja UUID.

A primeira entrega liga explicitamente o aluno autenticado do Tutor ao registro
externo, com origem, data, território opcional e revisão humana justificada.
Não importa respostas, senhas, dados socioeconômicos ou interesses. A planilha
baseline e o banco do outro app não são alterados. Campos de capacitação em
texto não são convertidos automaticamente para IDs de cursos do Tutor.

## Cliente

`ClassroomRepository` existente ganhou operações online para vínculo e casos de
mentoria. Rotas preservam turma, aluno e prefixo da API. O acompanhamento fica
vinculado à conta que o abriu: troca de conta descarta a resposta e bloqueia
novas operações naquele repositório. Não há cache ou fila offline desses dados.

Testes direcionados: 7 passaram (3 novos de acompanhamento e 4 existentes de
turmas). Verificam métodos/corpos/caminhos HTTP, paginação, autenticação e troca
de conta. Não substituem testes de autorização/persistência no servidor.

## Próxima integração

API aditiva com histórico e autorização por turma; depois tela simples de
acompanhamento no contexto do estudante, com objetivo, responsável, próxima
ação e estado do caso. Reusar navegação/telemetria existentes, sem criar um
painel analítico novo. Testar vínculo, abertura, atualização e releitura antes
de promover. Nenhuma recomendação automática concede mentoria nesta entrega.
