# Tutor TDS: Android QA ligado ao WordPress privado sintético (Issue #241)

Este código é **QA estritamente isolado**, não uma feature pública, nem configuração de release. A implementação WordPress editorial real está em PR #238; o app cliente em PR #240. A fonte sintética é WordPress 6.7.2 + LearnPress 4.3.6 + MySQL 8.0.45 em uma rede Docker **internal=true**, sem portas publicadas, na VPS.

## Topologia de execução

`WordPress sintético VPS container:80` → `VPS Docker IP privado 192.168.16.3:80` → túnel SSH `127.0.0.1:18731` no DESKTOP-8T5DRBS → `adb reverse tcp:18731 tcp:18731` → emulador Android 35 QA, app x86_64.

O domínio ead.ipexdesenvolvimento.cloud e a API de produção **não são alterados**. `TDS_EDITORIAL_QA_HTTP_BASE=http://127.0.0.1:18731` é habilitado apenas com modo debug, `DYNAMIC_QA_ISOLATED_PACKAGE=true` e run ID de 32 caracteres hexadecimais. O Gradle exige o endereço exato de loopback e recusa parâmetros extras em release. Política Android permite HTTP **apenas para loopback no manifesto debug**. O restante das chamadas continua HTTPS, inclusive o catálogo público de 11 cursos.

## Navegação no app QA

Entrada anônima → `Cursos do EAD` → cartão `LABORATÓRIO INTERNO · DADOS FICTÍCIOS` → `Percurso de aprendizagem`, curso id=12 → lição id=13 (quando WordPress sintético liberar `mobile_content`) → texto de QA seguro e vídeo YouTube previamente aprovado → `Atualizar` para ver nova revisão/ETag sem build. Outros cursos usam o domínio EAD oficial, com IDs de produção, sem ponte HTTP.

**Não há dados pessoais, gabaritos, certificados ou matrículas em QA.** A marca de laboratório nunca deve aparecer no aplicativo distribuído. Não gravar notificações, contatos, contas reais, senhas ou telas administrativas.

## Passos reproduzíveis, somente QA

1. Verifique os dois containers `tds-learning-qa-*`, rede interna e ausência de PortBindings. Não mexa no WordPress de produção.
2. SSH no desktop: `ssh -N -T -o ExitOnForwardFailure=yes -L 127.0.0.1:18731:192.168.16.3:80 tutor-tds-vps` em processo dedicado.
3. `adb -s emulator-5554 reverse tcp:18731 tcp:18731` (não usar dispositivo físico).
4. Testar GET do host desktop com cabeçalho `Host: tds-learning-qa-wp-20261017`, currículo `/??rest_route` construído como `/?rest_route=/tds-learning/v1/courses/12/curriculum`; deve retornar 200 sem cookie/autenticação.
5. Build `flutter build apk --debug --target-platform android-x64 --dart-define-from-file <arquivo privado do QA>` e validar com `aapt dump badging` que `com.tutortds_cartilhas.dev.dynamicqa.r{32hex}` é o pacote, não `com.tutortds_cartilhas`.
6. Capturar screenrecord MP4 original, screenshot PNG e SHA256 do APK/evidências. Gravar no próprio desktop, sem sair do ambiente QA; não exigir GPU L4 para emulador (sem /dev/kvm).
7. Em pós-teste, matar somente emulador iniciado por este runner, fechar túnel de sua sessão e restaurar o WordPress sintético à política opt-in inicial. Não apagar banco nem pastas sem verificar outras sessões.

## Gates de release

- Debug-only private editorial transport; release Gradle bloqueia `DYNAMIC_QA_*` e define HTTP experimental, e manifesto principal exige HTTPS.
- O app público **ainda não tem** endpoint de adaptação WordPress instalado: esta captura não prova publicação de conteúdo real.
- Homologar SSL/Cloudflare, perfis aluno/instrutor, Android 35/36, YouTube/legendas, Tutor/RAG e performance antes do AAB/Play. Não declarar produção pronta.
- Merges e deploy requerem aprovação separada, sem force-push e sem alteração de conteúdo real.

## Resultados

O recibo final de TESTED-EMULATOR, vídeo e prints deve ser acrescentado depois dos testes executados. **A existência deste documento não prova que a sessão Android já ocorreu.**