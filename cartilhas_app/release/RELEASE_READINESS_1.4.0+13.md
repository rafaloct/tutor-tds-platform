# Release readiness Android — Tutor TDS 1.4.0+13

Auditoria executada em 20/09/2026. Este documento prepara um candidato para
**teste interno**; não registra upload ou publicação.

## Artefato validado

- Caminho: `release/Tutor-TDS-1.4.0+13-signed.aab`
- Tamanho final: `64.711.735` bytes
- SHA-256 final: `706E007DE279010752EBE9D45BDFF44F307EEDC43F46D0E09A946CD6EF502946`
- Package/applicationId: `com.tutortds_cartilhas` (inalterado)
- Version name/code: `1.4.0` / `13`
- SDK: mínimo 24, target 36, compile 36
- ABI no bundle: `armeabi-v7a`, `arm64-v8a` e `x86_64`

## Gates aprovados

- `dart analyze lib test`: zero issues.
- `flutter test --coverage test`: 163 testes aprovados; relatório bruto em
  `coverage/lcov.info`.
- Cobertura de linhas: total `5.378/7.881` (68,24%); certificados
  `499/567` (88,01%); Study AI `1.828/2.191` (83,43%); sync/outbox
  `732/826` (88,62%). O recorte sync/outbox inclui os modelos, fila e serviço
  `assessment_sync_*` e os modelos, fila e serviço em `learning_events`.
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
- Shrink Java/Kotlin: R8 ativo, com `proguard.map`, `r8.json` e `usage.txt`.
- Símbolos nativos para as três ABIs incluídos em `BUNDLE-METADATA`.
- Dart não usa `--obfuscate` neste candidato. Obfuscação não é controle de
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
- O bundle final não contém a URL de staging nem o domínio inválido usado no
  teste negativo do gate de release.

## Requisitos Play verificados

- Desde 31/08/2026, atualizações de apps móveis precisam mirar API 36; este
  candidato usa target 36. Fonte: https://support.google.com/googleplay/android-developer/answer/11926878
- Apps target 35+ devem suportar páginas de memória de 16 KB para atualizações
  a partir de 01/02/2027; o bundle já declara alinhamento de 16 KB. Fonte:
  https://developer.android.com/guide/practices/page-sizes
- O AAB está assinado com a chave de upload; a Play App Signing gera os APKs de
  distribuição. Fonte: https://developer.android.com/studio/publish/app-signing

## Pendências humanas antes do upload

1. Confirmar na Play Console que `versionCode 13` nunca foi usado e que o SHA-256
   público acima corresponde à chave de upload cadastrada.
2. Revisar e confirmar Segurança dos dados, política de privacidade, exclusão
   de conta, classificação indicativa, público-alvo e declarações de conteúdo.
3. Enviar primeiro para teste interno, executar o relatório de pré-lançamento e
   instalar pela Play em Android 7/8 e Android atual, inclusive atualização
   sobre a versão publicada.
4. Testar no aparelho: modo offline, voz/TTS, login/logout/reentrada, troca de
   aluno/equipe, vídeos restritos, simulado entre aparelhos, evidências, PDF e
   exclusão.
5. Não promover se houver divergência de assinatura, versionCode já usado,
   crash/ANR, alerta de SDK/página de memória ou declaração de dados incoerente.

## Observação de manutenção

O build emite aviso não bloqueante de que alguns plugins ainda aplicam o Kotlin
Gradle Plugin diretamente. O candidato compila com AGP 9.0.1/Kotlin 2.3.20,
mas as dependências devem ser atualizadas e retestadas antes de uma futura
versão do Flutter que torne Built-in Kotlin obrigatório.
