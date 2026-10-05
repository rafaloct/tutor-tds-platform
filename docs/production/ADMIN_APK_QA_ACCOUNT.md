# Preparação de conta QA para homologação física do APK

**Status:** IMPLEMENTED no candidato local; execução em staging requer operador
já autorizado e aprovação humana para habilitar as flags de staging. Não usar em
produção.

## Finalidade e limites

Este roteiro prepara uma conta **sintética** para testar o APK no Xiaomi, sem
SQL, Sheets ou um cadastro paralelo. Ele reutiliza `User`,
`ProgramMembership`, `Enrollment`, `ClassEnrollment` e `CohortMembership`.
Não autoriza importar pessoas, administrar equipe, alterar frequência, emitir
certificado ou usar dados pessoais reais.

O operador deve estar autenticado e ter um `ProgramMembership` **ativo** no
programa da turma, com o papel já existente `program_operator`, `coordinator`
ou `admin`. Ser administrador global, sem esse vínculo de programa, não basta.

## Pré-condições de staging

1. Confirmar uma turma sintética existente, ativa e com edição fixada.
2. Confirmar que o curso dessa turma é ofertado pelo programa.
3. Usar somente uma conta de operador já autorizada e uma identidade de aluno
   inteiramente sintética. Não registrar CPF, telefone, senha ou outro dado real
   em issue, chat, commit ou motivo operacional.
4. Após aprovação humana para o ensaio de staging, habilitar as duas flags
   somente naquele ambiente: `OPERATOR_OPERATIONS_ENABLED=true` na API e
   `--dart-define=OPERATOR_OPERATIONS_ENABLED=true` no APK de QA. Ambas ficam
   desabilitadas por padrão; não há fallback para produção.

## Fluxo no APK

1. Entre com a conta do operador e abra **Operação de participantes**.
2. Escolha explicitamente o programa / curso / turma retornado em *Selecionar
   programa / curso / turma*. Não use um contexto sugerido por outra pessoa.
3. Para pessoa já existente, use **Localizar**. Busca por nome só mostra
   pessoas já vinculadas ao programa; uma pessoa externa só pode ser vinculada
   após busca por CPF exato, que devolve uma prova temporária de identidade.
   Nome não é usado para casar identidades.
4. Se a pessoa sintética não existir, use **Cadastrar nova pessoa**, informe
   apenas dados sintéticos e um motivo sem dados sensíveis, e selecione
   **Solicitar cadastro**. O resultado deve mostrar a pessoa, matrícula ausente
   e vínculo com a turma ausente.
5. Selecione **Solicitar matrícula**. A confirmação deve passar a mostrar
   *Matrícula no curso: ativa*.
6. Selecione **Vincular à turma**. A confirmação final deve mostrar *Vínculo
   com a turma: ativo*, o contexto selecionado e o histórico das operações.
7. Entre no APK com a conta sintética e retome a homologação física do Xiaomi.

## Segurança operacional e recuperação

- A tela não cria uma segunda identidade: o servidor detecta duplicidade no
  cadastro e reutiliza o usuário localizado para vínculo e matrícula.
- Se a resposta de uma operação se perder, use **Retomar a mesma operação**.
  Não reenvie cadastro com uma nova tentativa manual: a chave idempotente
  retorna o mesmo recibo sem duplicar usuário, matrícula ou vínculo.
- Se a autorização, o contexto ou a revisão mudar, a tela limpa os dados e pede
  nova consulta. Não tente contornar a negação com outro programa/turma.
- Para corrigir turma, revogue o vínculo com motivo e selecione o novo contexto;
  a matrícula e o histórico são preservados.
- Ao fim do ensaio, desligue as flags de staging conforme o gate humano. O
  rollback é desabilitar as flags; recibos já confirmados são preservados para
  auditoria e não devem ser apagados para simular reversão.

## Evidência mínima a registrar no draft PR

Registrar somente identificadores sintéticos e resultados sanitizados:

- contexto selecionado e estado final de matrícula/turma;
- replay da mesma chave sem duplicação;
- tentativa de acesso a outra instituição ou turma negada;
- versão do APK de QA, ambiente staging e resultado da homologação física;
- o responsável humano que autorizou habilitar/desabilitar as flags.

Não declarar `TESTED-STAGING` ou `ACCEPTED` antes do ensaio físico. Produção,
keystore, certificados e dados reais permanecem fora deste procedimento.
