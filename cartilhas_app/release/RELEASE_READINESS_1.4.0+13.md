# Release readiness Android — Tutor TDS 1.4.0+13

Auditoria executada em 20/09/2026. **O bundle registrado abaixo está superseded
e não deve ser enviado à Play Console.** Ele antecede a implementação da
retomada offline segura do Evidence/check-in. O código atual passou 177/177
testes, mas requer reteste físico no Xiaomi reconectado e novo rebuild antes de
voltar a ser candidato a teste interno. Este documento não registra upload ou
publicação. O bundle histórico foi
reconstruído uma única vez depois das correções finais de acessibilidade/layout
e da correção P1 de resolução dos endpoints de mídia com base em subpath. O
APK DEV correspondente passou o reteste físico de grant/HLS, velocidades 0,75x
e 2x e retomada.

## Artefato histórico superseded — não enviar

- Caminho: `release/Tutor-TDS-1.4.0+13-signed.aab`
- Tamanho histórico: `64.716.303` bytes
- SHA-256 superseded: `B93FAD21CE8AE92AB464FCAFE8FB69E66C07C6E712DB0DBFCA0AE580B2844B66`
- Package/applicationId: `com.tutortds_cartilhas` (inalterado)
- Version name/code: `1.4.0` / `13`
- SDK: mínimo 24, target 36, compile 36
- ABI no bundle: `armeabi-v7a`, `arm64-v8a` e `x86_64`

## Gates históricos do artefato e gates atuais do código

- `dart analyze lib test`: zero issues.
- `flutter test --no-pub`: **177/177** no código atual, depois da mudança de
  Evidence offline. Esse resultado não transforma o AAB superseded em candidato.
- `flutter test --coverage test`: baseline anterior de 163 testes aprovada;
  relatório bruto em `coverage/lcov.info`.
- Cobertura de linhas: total `5.378/7.881` (68,24%); certificados
  `499/567` (88,01%); Study AI `1.828/2.191` (83,43%); sync/outbox
  `732/826` (88,62%). O recorte sync/outbox inclui os modelos, fila e serviço
  `assessment_sync_*` e os modelos, fila e serviço em `learning_events`.
- Gate responsivo automatizado aprovado com `textScale 2.0`, telefone estreito
  e landscape para Home, quiz/simulado, mídia, Classroom/Monitor, Evidence e
  certificados, incluindo semântica essencial e ausência de overflow.
- O gate encontrou e corrigiu quatro falhas reais: rolagem integral da Home,
  rolagem da configuração do simulado, expansão do seletor de turma e quebra
  segura da linha de integridade do certificado. A Home também passou a
  reutilizar o `Future` do catálogo em rebuilds.
- A regressão do prefixo da API de mídia foi coberta para autorização de
  playback e rating GET/PUT. No Xiaomi, grant/HLS, velocidades 0,75x/2x e
  retomada foram aprovados; legenda não era testável porque o item retornou
  `captions=[]`.
- Configuração produtiva validada sem chaves de IA ou de provedor.
- Matriz Gradle: debug aceita apenas staging aprovado; release aceita apenas
  produção; staging, configuração vazia e gateway divergente são bloqueados.
- Build limpo com Flutter 3.44.9 / Dart 3.12.2 e arquivo de lock existente.
- Bundletool 1.18.3 `validate`: aprovado.
- Assinatura JAR: válida; certificado do AAB corresponde a
  `android/upload_certificate.pem`.
- SHA-256 do certificado de upload: `16:44:39:F5:EF:57:F6:E9:C7:B8:58:A3:4F:59:2C:26:1D:CC:EC:AD:B3:B3:59:98:F0:7C:40:1F:6C:34:3F:50`.
- BundleConfig: bibliotecas nativas não comprimidas e alinhamento
  `PAGE_ALIGNMENT_16K`.
- Os 12 objetos ELF das três ABIs foram inspecionados com `llvm-readelf`; todos
  os segmentos `LOAD` têm alinhamento mínimo de 16 KB.
- Shrink Java/Kotlin: R8 ativo, com `proguard.map`, `r8.json` e `usage.txt`.
- Símbolos nativos para as três ABIs incluídos em `BUNDLE-METADATA`.
- Dart não usa `--obfuscate` neste artefato histórico. Obfuscação não é controle de
  segredo e só deve ser ativada junto de um processo testado de guarda e uso
  dos símbolos de desofuscação.

## Manifesto e privacidade

- Permissões efetivas: `INTERNET`, `RECORD_AUDIO` e a permissão interna de
  receptor não exportado gerada pelo AndroidX.
- Microfone é opcional no dispositivo e solicitado apenas pela ação de voz.
- Não há localização, contatos, câmera, armazenamento amplo ou notificações.
- `allowBackup=false`, `fullBackupContent=false` e
  `usesCleartextTraffic=false`.
- Consultas Android 11+ declaradas para reconhecimento de fala e TTS, além dos
  destinos externos realmente usados.
- Varredura do conteúdo descompactado do AAB não encontrou nomes conhecidos de
  chaves de IA nem prefixo de token OpenAI; API, gateway e exclusão compilados
  correspondem aos destinos produtivos esperados.
- O bundle superseded não contém a URL de staging nem o domínio inválido usado no
  teste negativo do gate de release.

## Requisitos Play verificados

- Desde 31/08/2026, atualizações de apps móveis precisam mirar API 36; o
  artefato superseded usa target 36. Fonte: https://support.google.com/googleplay/android-developer/answer/11926878
- Apps target 35+ devem suportar páginas de memória de 16 KB para atualizações
  a partir de 01/02/2027; o bundle já declara alinhamento de 16 KB. Fonte:
  https://developer.android.com/guide/practices/page-sizes
- O AAB está assinado com a chave de upload; a Play App Signing gera os APKs de
  distribuição. Fonte: https://developer.android.com/studio/publish/app-signing

## Bloqueios antes de qualquer novo upload

1. **Não enviar o hash superseded acima.** Reconectar o Xiaomi, retestar a
   perda de rede, retry idempotente e reabertura com novo código no Evidence;
   depois reconstruir e repetir os gates do AAB.
2. Confirmar na Play Console que `versionCode 13` nunca foi usado e que o SHA-256
   público acima corresponde à chave de upload cadastrada.
3. Revisar e confirmar Segurança dos dados, política de privacidade, exclusão
   de conta, classificação indicativa, público-alvo e declarações de conteúdo.
4. Enviar o **novo** AAB primeiro para teste interno, executar o relatório de pré-lançamento e
   instalar pela Play em Android 7/8 e Android atual, inclusive atualização
   sobre a versão publicada.
5. Testar no aparelho: modo offline, voz/TTS, login/logout/reentrada, troca de
   aluno/equipe, vídeos restritos, simulado entre aparelhos, evidências, PDF e
   exclusão.
6. Validar legenda quando o catálogo publicar uma faixa real; `captions=[]` não
   permitiu comprovar esse subcaso no reteste físico.
7. Não promover se houver divergência de assinatura, versionCode já usado,
   crash/ANR, alerta de SDK/página de memória ou declaração de dados incoerente.

## Observação de manutenção

O build histórico emite aviso não bloqueante de que alguns plugins ainda aplicam o Kotlin
Gradle Plugin diretamente. O artefato superseded compilou com AGP 9.0.1/Kotlin 2.3.20,
mas as dependências devem ser atualizadas e retestadas antes de uma futura
versão do Flutter que torne Built-in Kotlin obrigatório.
