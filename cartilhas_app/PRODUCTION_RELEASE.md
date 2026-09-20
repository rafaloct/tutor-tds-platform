# Tutor TDS — release Android 1.4.0+13

## Estado validado em 20/09/2026

- Pacote: `com.tutortds_cartilhas`.
- Android: `minSdk 24`, `targetSdk 36`, `compileSdk 36`.
- AAB candidato: `release/Tutor-TDS-1.4.0+13-signed.aab`.
- Tamanho final: `64.711.735` bytes.
- SHA-256 final: `706E007DE279010752EBE9D45BDFF44F307EEDC43F46D0E09A946CD6EF502946`.
- API: `https://ead.ipexdesenvolvimento.cloud/tutor-api`.
- Política: `https://cartilhas.ipexdesenvolvimento.cloud/privacy.html`.
- Exclusão externa: `https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html`.
- Gateway IA: `https://tutor-tds-gateway.tdsipex.workers.dev`.
- Modelo do Tutor: sem DeepSeek; credenciais e modelo permanecem no servidor.

O ciclo externo de cadastro, telemetria, analytics, exclusão e revogação do
token foi testado em produção. A API contém as nove cartilhas e mantém fallback
local no aplicativo.

## Reproduzir o bundle

O arquivo real `config/production.json` é ignorado pelo Git. Ele deve definir
somente as quatro URLs públicas presentes em `config/production.example.json`.
O validador bloqueia API ausente, HTTP e chaves conhecidas de provedores.

Como o caminho original contém acentos, use um drive virtual curto:

```powershell
subst T: "C:\Users\Usuario\Downloads\Cartilhas (Versão Chatbot)\Cartilhas (Versão Chatbot)"
Set-Location T:\cartilhas_app
dart run tool/validate_production_config.dart config/production.json
dart analyze lib test
flutter test --no-pub
flutter build appbundle --release --dart-define-from-file=config/production.json
```

Validação executada no artefato:

- Bundletool 1.18.3: bundle válido;
- `versionName 1.4.0` e `versionCode 13`;
- bibliotecas nativas não comprimidas com `PAGE_ALIGNMENT_16K`;
- símbolos nativos separados em `BUNDLE-METADATA`;
- permissões somente `INTERNET` e `RECORD_AUDIO` (além da permissão interna do Android);
- `allowBackup=false` e `usesCleartextTraffic=false`;
- assinatura JAR válida e chave correspondente a `android/upload_certificate.pem`.
- URLs produtivas de API, gateway e exclusão presentes no binário, sem URL de
  staging ou marcadores conhecidos de credenciais de IA.

O relatório detalhado deste candidato, incluindo hash, permissões, shrink e
pendências humanas, está em `release/RELEASE_READINESS_1.4.0+13.md`.

## Operação da API

A pilha produtiva está em `/opt/tutor-tds-api` na VPS. PostgreSQL usa rede
interna e volume dedicado; somente a API passa pelo Traefik. Os três containers
têm logs limitados a 5 arquivos de 20 MB.

```bash
cd /opt/tutor-tds-api
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml logs --tail=100 api
curl -fsS https://ead.ipexdesenvolvimento.cloud/tutor-api/health
```

O backup lógico roda diariamente às 03:20 UTC, retém 14 dias localmente e pode
ser disparado por `/opt/tutor-tds-api/ops/backup.sh`. Cópia externa e teste de
restauração ainda são controles operacionais obrigatórios pós-release.

## Antes do rollout

Use `release/PLAY_CONSOLE_CHECKLIST.md`. O upload e a promoção para produção
dependem de login humano na Play Console, confirmação da chave de upload,
revisão das declarações e resultado do teste interno. Não publique diretamente
em 100% dos usuários sem passar por teste interno e rollout gradual.
