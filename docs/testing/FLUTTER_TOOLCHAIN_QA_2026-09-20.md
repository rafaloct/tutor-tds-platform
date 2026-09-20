# QA do toolchain Flutter - 2026-09-20

## Resultado

**APROVADO para análise estática e testes locais no estado auditado.**

- SDK fixado: Flutter 3.44.9 / Dart 3.12.2.
- Dependências resolvidas com sucesso.
- `.dart_tool/package_config.json` coerente com o SDK fixado.
- Análise direta com infos fatais: zero achados.
- Suíte Flutter completa inicial: **120/120 testes aprovados**.
- Revalidação pós-P1 (Monitor, Evidence e perfil): **127/127 testes aprovados**.
- Revalidação independente final após correção do 403: **137/137 testes aprovados**.
- Dispositivo Xiaomi inventariado via ADB, sem instalar, iniciar, remover ou limpar aplicativo.

Esta evidência substitui a limitação de toolchain registrada durante a auditoria visual anterior. Ela não substitui build release, assinatura, testes físicos em staging, smoke de backend nem validação na Play Console.

## Ambiente verificado

Workspace:

```text
C:\Users\Usuario\Downloads\Cartilhas (Versão Chatbot)\Cartilhas (Versão Chatbot)\cartilhas_app
```

Binários usados explicitamente, sem depender do `PATH`:

```text
C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat
C:\Users\Usuario\flutter-3.44.9\bin\dart.bat
```

Versões:

```text
Flutter 3.44.9
Framework revision 6b182d2c75
Engine b9499e4c25212536ba3a4eec4f5c1905fb3214fe
Dart 3.12.2
DevTools 2.57.0
```

O `pubspec.yaml` exige Dart `^3.12.0`, portanto Dart 3.12.2 atende ao contrato.

## Coerência de dependências

Comando:

```powershell
& 'C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat' pub get
```

Resultado: exit code 0, `Got dependencies!`. A mensagem de 63 versões mais novas incompatíveis com as constraints é informativa; nenhuma dependência foi atualizada fora das constraints.

Entradas relevantes de `.dart_tool/package_config.json` após a resolução:

| Pacote | `rootUri` | Language version |
|---|---|---:|
| `flutter` | `file:///C:/Users/Usuario/flutter-3.44.9/packages/flutter` | 3.10 |
| `flutter_test` | `file:///C:/Users/Usuario/flutter-3.44.9/packages/flutter_test` | 3.10 |
| `cartilhas_app` | `../` | 3.12 |

Não restou referência do package config ao SDK antigo `C:\Users\Usuario\flutter`.

## Análise estática

Comando final:

```powershell
& 'C:\Users\Usuario\flutter-3.44.9\bin\dart.bat' analyze --fatal-infos lib test
```

Resultado:

```text
Analyzing lib, test...
No issues found!
```

Exit code: 0.

### Observação sobre `flutter analyze`

`flutter analyze` com o mesmo SDK chegou a iniciar, mas o analysis server encerrou com `FormatException: Unexpected end of input` ao ler uma mensagem LSP cujo workspace contém parênteses e espaços. O código não foi a origem dessa exceção. O gate foi executado diretamente pelo analisador Dart do mesmo SDK, com `--fatal-infos`, e terminou sem achados.

Para CI, preferir o comando direto acima até que o wrapper `flutter analyze` seja confirmado em um caminho simples ou corrigido pelo SDK.

## Suíte Flutter completa

Comando final:

```powershell
& 'C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat' test --no-pub
```

Resultado da primeira estabilização:

```text
00:32 +120: All tests passed!
```

Exit code: 0. Nenhum teste foi omitido por filtro.

Cobertura comportamental observada na suíte inclui autenticação e onboarding, proteção/migração de CPF, exclusão de dados locais, telemetria, eventos e sync, quiz/simulado, flashcards, resumos, Tutor, Classroom, Evidence Engine, mídia e certificados.

## Revalidação pós-P1

Depois da implementação da superfície Monitor por exceção e dos últimos ajustes
de Evidence/perfil, os gates foram repetidos no mesmo SDK fixado:

```powershell
& 'C:\Users\Usuario\flutter-3.44.9\bin\dart.bat' analyze --fatal-infos lib test
& 'C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat' test --no-pub
```

Resultado:

```text
Analyzing lib, test...
No issues found!

00:52 +127: All tests passed!
```

Ambos os comandos terminaram com exit code 0.

Este resultado corresponde ao snapshot pós-Monitor/P1 imediatamente anterior
à integração de Assessment Sync. A seção específica abaixo registra a repetição
dos mesmos gates no snapshot posterior estabilizado.

### CPF e suporte Chatwoot

- `SecureProfileDataStore` grava CPF somente no armazenamento protegido da
  plataforma (`FlutterSecureStorage`).
- `user_cpf` permanece no código apenas como chave legada: a leitura migra o
  valor para o armazenamento seguro e remove a preferência; escrita e limpeza
  também removem a chave legada.
- Os testes de perfil cobrem armazenamento seguro e migração/remoção do CPF em
  texto simples.
- `ChatwootScreen` não lê, recebe ou envia CPF. Nome e telefone só são enviados
  quando há consentimento; sem consentimento, o contato usa identidade genérica
  e um identificador aleatório próprio do suporte.
- Nome e telefone continuam em `SharedPreferences`; essa decisão está fora do
  gate específico de CPF e deve permanecer descrita na política de privacidade.

Resultado do gate: **aprovado para CPF**. Não foi feita inspeção de dados reais
no dispositivo.

### Telemetria de Monitor e Evidence

As novas entradas usam `trackedRoute` com identificadores fechados:

| Fluxo | Page ID | Resource ID | Feature ID |
|---|---|---|---|
| Monitor por exceção | `monitor_exceptions` | - | `monitor_exceptions` |
| Check-in do aluno | `evidence_checkin` | - | `evidence_checkin` |
| Cockpit do professor | `evidence_cockpit` | `class_session` | `evidence_engine` |

O detalhe de estudante no Monitor também registra a feature
`monitor_student_details`. Os IDs contêm somente enumerações de produto, sem
nome, CPF, telefone ou texto livre.

Resultado do gate de rotas: **aprovado**. Ações internas do cockpit (abrir
sessão, rotacionar QR, importar, revisar e fechar) ainda podem receber eventos
de produto próprios em uma evolução P2; a auditoria formal dessas operações
permanece no backend.

### Varredura de segredos

A varredura foi executada por nomes de arquivo e padrões, sem imprimir valores.
Foram excluídos documentação, testes/fixtures, exemplos, lockfiles, builds e
caches. Também foi verificado o inventário de arquivos `.env*` e as regras de
ignore.

| Padrão | Resultado |
|---|---|
| Chaves privadas PEM/OpenSSH | nenhum arquivo de código/configuração encontrado |
| Tokens conhecidos de AWS, GitHub, OpenAI e Google | nenhum arquivo encontrado |
| JWT literal | nenhum arquivo encontrado |
| Credencial embutida em URL | nenhum arquivo encontrado |
| Atribuição genérica de credencial | `cartilhas_app/lib/screens/chatwoot_screen.dart` |

O achado no Chatwoot é o identificador de website exigido pelo widget público
do cliente, não uma credencial administrativa. Recomenda-se ainda movê-lo para
configuração de build e manter rotação/documentação separadas, classificado
como P2.

O arquivo local `.env.deploy` contém nomes de variáveis operacionais sensíveis,
está coberto por `.gitignore` e não é rastreado pelo Git. Seus valores não foram
exibidos. `key.properties`, `local.properties` e o keystore Android encontrados
localmente também estão ignorados pelas regras do projeto.

Resultado do gate de repositório: **nenhum segredo privilegiado confirmado em
código rastreável pelos padrões de alta confiança usados**. Isso não substitui
um scanner de entropia/secret manager no CI.

## Rastreabilidade das regressões durante a rodada

Foram vistos dois conjuntos de falhas enquanto outras frentes ainda escreviam no workspace compartilhado. Eles não foram classificados como resultado final até a estabilização:

1. três falhas após a migração de CPF para `FlutterSecureStorage`, causadas por ausência de mock/injeção nos testes;
2. uma falha em fixture de recuperação de sessão do Evidence Engine e um lint `use_null_aware_elements`.

As correções preservaram o armazenamento seguro, adicionaram mocks/testes de migração e estabilizaram o contrato Evidence. A repetição independente final desse snapshot produziu zero achados e 127/127 testes aprovados.

## Revalidação após Assessment Sync

No snapshot declarado estável após a integração de Assessment Sync, os gates
foram repetidos independentemente com o SDK fixado:

```powershell
& 'C:\Users\Usuario\flutter-3.44.9\bin\dart.bat' analyze --fatal-infos lib test
& 'C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat' test --no-pub
```

Resultado:

```text
Analyzing lib, test...
No issues found!

01:28 +137: All tests passed!
```

Ambos terminaram com exit code 0. A execução completa não usou filtros.

### Contrato e resolução de sincronização

O corpo enviado ao endpoint contém somente `course_id`, `topic`, `mode`,
`revision`, índices de `answers` e `marked`, `current_index`,
`remaining_seconds`, `completed`, `score` e `updated_at`. Não contém deck,
enunciados, alternativas, índice de gabarito, explicação, dificuldade ou tópicos
fracos. O teste de serviço confirma a ausência de `deck`, `weakTopics` e
`difficulty`; a revisão do serializador confirma também a ausência das demais
estruturas pedagógicas.

- sucesso só produz `Sincronizado` depois de resposta canônica exata;
- falha de rede/API/sessão mantém a revisão pendente para retry;
- 409 consulta a versão remota, preserva a fila e exige escolha explícita;
- tentativa remota concluída não pode ser sobrescrita pela versão local;
- 403 preserva a revisão como pendente com
  `active_enrollment_required`.

**P1 do 403 encerrado em 2026-09-20:** a tela agora informa `Tentativa segura
neste aparelho • matrícula ativa necessária para sincronizar` e oferece a ação
explícita `Tentar novamente`. Depois do 403, novos autosaves continuam
enfileirados localmente sem repetir PUT; a rede é consultada novamente somente
quando o aluno aciona esse botão. O teste de serviço confirma ausência de loop,
preservação da revisão e segundo PUT apenas no retry manual; o teste de widget
confirma mensagem e ação. A repetição independente posterior terminou com
análise limpa e 137/137 testes aprovados.

Nenhum APK foi gerado ou instalado e staging/produção não foram acessados nesta
revalidação.

## Inventário ADB somente leitura

ADB:

```text
C:\Users\Usuario\AppData\Local\Android\Sdk\platform-tools\adb.exe
Android Debug Bridge 1.0.41, versão 36.0.0-13206524
```

Dispositivo conectado:

| Campo | Valor |
|---|---|
| Serial ADB | `ZT6HPRHQHATSEQPR` |
| Fabricante | Xiaomi |
| Modelo | `2311DRK48G` |
| Device | `duchamp` |
| Android | 15 |
| API | 35 |
| ABI | `arm64-v8a` |
| Build | `AP3A.240905.015.A2` |

Pacotes já presentes antes desta validação:

| Pacote | Version code | Version name | Observação |
|---|---:|---|---|
| `com.tutortds_cartilhas` | 11 | 1.2.0 | pacote publicado; não foi tocado |
| `com.tutortds_cartilhas.dev` | 11 | 1.2.0-dev | pacote de desenvolvimento já instalado; não foi aberto |
| `br.org.ipex.cartilhas_app` | 2 | 1.1.0 | pacote legado já instalado; não foi tocado |

Comandos ADB executados foram limitados a `version`, `devices -l`, `getprop`, `pm list packages` e `dumpsys package`. Não houve `install`, `uninstall`, `pm clear`, `am start`, escrita de arquivo ou chamada de rede pelo dispositivo.

## Gates ainda externos

O resultado deste documento permite avançar para QA físico, mas não autoriza release. Permanecem:

1. publicar e validar o health HTTPS do staging separado;
2. gerar APK `.dev` somente com o gate de ambiente staging aprovado;
3. testar no Xiaomi os fluxos críticos com dados sintéticos, inclusive offline/retomada e fonte ampliada;
4. validar o backend/migrations em staging e smoke integrado;
5. somente depois executar o gate release/AAB com configuração de produção e assinatura autorizadas.
