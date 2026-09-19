# Armazenamento de desenvolvimento no disco D

> **Nota de auditoria (2026-09-19):** o disco `D:` não está disponível no ambiente atual. Para preservar a versão exigida sem substituir o Flutter global, o Flutter 3.44.9 foi instalado em `C:\Users\Usuario\flutter-3.44.9` e o projeto foi exposto pelo junction curto `C:\Dev\tutor-tds`. As instruções abaixo descrevem uma configuração histórica e não devem ser reaplicadas automaticamente.

O projeto, o Flutter e o Android SDK permanecem no disco `D:`. Os caches que
normalmente crescem no perfil do Windows também foram direcionados para o `D:`
para evitar que builds Flutter/Android esgotem o SSD do sistema.

## Destinos ativos

| Componente | Destino |
| --- | --- |
| Flutter | `D:\flutter-3.44.9` |
| Repositório Git compartilhado do Flutter | `D:\DevTools\flutter-main` |
| Android SDK | `D:\DevTools\AndroidSDK` |
| Gradle | `D:\DevTools\gradle` |
| Pub/Dart | `D:\DevTools\pub-cache` |
| Perfil Android/ADB | `D:\DevTools\android-user` |
| Temporários do usuário | `D:\DevTools\temp` |
| Cache do Android Studio | `D:\DevTools\android-studio-cache` |

As variáveis `GRADLE_USER_HOME`, `PUB_CACHE`, `ANDROID_USER_HOME`,
`ANDROID_HOME`, `ANDROID_SDK_ROOT`, `FLUTTER_ROOT`, `TEMP` e `TMP` são
persistidas no escopo do usuário. O primeiro item do `Path` do usuário é
`D:\flutter-3.44.9\bin`.

Junções NTFS foram mantidas nos caminhos antigos do `C:`. Elas ocupam apenas
alguns bytes e protegem ferramentas antigas que ainda tentem acessar
`C:\flutter`, `%USERPROFILE%\.gradle`, `%LOCALAPPDATA%\Pub\Cache` ou o caminho
padrão do Android SDK.

## Verificar ou reaplicar

O script é idempotente. Sem parâmetros ele apenas simula e exibe o plano:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\migrate_dev_storage_to_d.ps1
```

Para aplicar os destinos novamente:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\migrate_dev_storage_to_d.ps1 -Execute
```

Feche Android Studio, Flutter e processos Dart antes de usar `-Execute`. Abra
um terminal novo depois da aplicação para herdar as variáveis atualizadas.

## Recuperação e manutenção

As cópias antigas do Gradle e do Android SDK foram preservadas em
`D:\DevTools\migration-backup\2026-08-11-caches`. Não é necessário mantê-las
para compilar; elas existem apenas para recuperação. Exclua esse backup somente
depois de alguns dias de builds bem-sucedidos e de confirmar que não há arquivo
necessário nele. Não exclua `D:\DevTools\flutter-main`: o Flutter 3.44.9 usa o
repositório Git compartilhado dessa pasta.

Os artefatos `build` e `.dart_tool` ficam dentro deste projeto no `D:`. Se
crescerem demais, `flutter clean` libera espaço no `D:` sem afetar o SSD. Não é
necessário mover novamente o Flutter nem o projeto.

Se um build ainda mencionar uma letra antiga de unidade (por exemplo, `T:`),
o arquivo incremental foi criado antes da migração. Regenere-o no `D:` com:

```powershell
flutter clean
flutter pub get
```
