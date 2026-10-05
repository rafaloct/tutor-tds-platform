# Preparação QA APK — operação sintética de participantes

Issue #109 / parent #95; PR #96. Esta preparação cobre somente a apresentação
Flutter do fluxo administrativo existente. Não é aceite de staging ou produção.

## Estado e limites

- **OBSERVED:** a operação existente expõe locate/register/enroll/assign por
  gateway autorizado e projeta matrícula e vínculo à turma no mesmo contexto.
  O fluxo Flutter não introduz endpoints, persistência local ou autorização.
- **TARGET:** acompanhar localizar ou cadastrar → confirmar matrícula → vincular
  à turma; mostrar a confirmação final somente quando o serviço retorna ambos
  ativos no contexto escolhido. Iniciar cadastro limpa a confirmação anterior.
- **DECISION:** usar somente dados sintéticos e os repositories/controllers
  existentes. Replay retoma a mesma operação. Sem mudanças em `api/**`,
  `auth_repository.dart`, RBAC, migrations, Sheets ou SQL manual.
- **UNKNOWN/BLOCKED:** trial em staging depende da conclusão de #81 e não foi
  executado nesta issue. APK físico, Xiaomi, TalkBack e paridade visual não foram
  validados. O índice Stitch inspecionado não contém uma tela administrativa
  equivalente.

`MERGE_ALLOWED=NO` · `PRODUCTION_ALLOWED=NO` · sem staging real/Xiaomi nesta task.
Manter o PR em draft.

## Verificação local focal

Na pasta `cartilhas_app/`, executar com Flutter 3.44.9:

```sh
flutter analyze lib/features/operations
flutter test test/features/operations
```

Os testes focais devem cobrir a sequência de cadastro, matrícula e vínculo,
ausência de confirmação antiga durante um novo cadastro e confirmação final
somente após as duas relações serem retornadas ativas. A execução desta issue
não encontrou Flutter ou Dart instalados no ambiente; os comandos ficaram
pendentes e nenhum resultado de teste é declarado.

## Trial posterior a #81

Após #81 e autorização explícita de staging, preparar operador e contextos
sintéticos já autorizados. Pela UI, conferir: pessoa existente e nova; retorno
de cadastro sem confirmação final; matrícula confirmada sem conclusão prematura;
vínculo à turma no contexto/edição esperados; e confirmação final somente depois
das duas confirmações do serviço. Interromper uma resposta e retomar a mesma
operação, verificando ausência de duplicata. Registrar screenshots sanitizadas,
build/commit e resultado, sem conta ou dado pessoal real.

Não executar ou inferir este trial nesta issue. Se houver divergência de vínculo,
autorização ou edição, parar e encaminhar para o responsável do serviço; a UI não
deve corrigir estado acadêmico nem contornar autorização.
