# Revisão independente da implementação — 2026-09-20

## Decisão do snapshot

**NO-GO para AAB/Play neste snapshot.** Não restou P0/P1 de código confirmado
ao encerrar a revisão, mas os gates operacionais e E2E abaixo ainda não foram
demonstrados. A revisão foi feita sobre o `HEAD 3fe73c8` com alterações paralelas ainda
não commitadas; por isso os comandos devem ser repetidos no commit candidato.

Escopo: segurança, privacidade, RBAC, migrations, idempotência, mídia,
isolamento staging/produção e compatibilidade com usuários já publicados.
Nenhum deploy, acesso à VPS/produção, uso do Play Console, build AAB ou teste ADB
foi realizado.

## Gates funcionais/auditáveis

| ID | Gate não demonstrado | Evidência objetiva |
|---|---|---|
| G-01 | Histórico editorial auditável | `media_assets` mantém estado atual, `published_by` e timestamps, mas não há log imutável de transições/alterações; também não há fluxo para `blocked` e `archived`. |
| G-02 | Creator Score completo | A regra v1 usa conclusão, follow-up, salvamento e qualidade operacional; a própria snapshot marca `explicit_rating.available=false`. A avaliação exigida no critério da Onda 4 ainda não participa. |
| G-03 | Playback protegido | A arquitetura prevê `/admin/media/{id}/playback-token`; o endpoint não existe. URL Cloudflare configurada é estática, portanto mídia restrita ainda não demonstrou URL curta/assinada por matrícula. |
| G-04 | Rate limit de produção | API e compose não demonstram limitação para login, registro, refresh, eventos ou verificação externa de certificado. Aceitar somente com rate limit comprovado no proxy/WAF ou implementado e testado. |
| G-05 | PostgreSQL real | Alembic passou em SQLite temporário, mas a cadeia `0001` → `0009` ainda precisa de upgrade, smoke e restore ensaiados em PostgreSQL de staging isolado. |
| G-06 | E2E e escala | Ainda faltam app → API → PostgreSQL → Sheets, offline/reconexão, certificado público, desempenho 3G, acessibilidade e teste físico do APK `.dev` em staging. |

## Correções confirmadas durante a revisão

Os seguintes defeitos foram encontrados, comunicados aos agentes responsáveis e
corrigidos no workspace durante a revisão:

- exclusão de conta após evento de vídeo agora apaga `media_events` antes do
  evento principal;
- mídia `unlisted` deixou de aparecer em `GET /media` e permanece acessível só
  pelo detalhe;
- retry de ledger com a mesma chave e payload divergente passou a responder
  conflito;
- RBAC do painel/analytics passou a usar o vínculo real de turma, sem depender
  apenas do papel global do JWT;
- mídia Flutter passou a aceitar o contrato canônico sem `provider_asset_id`,
  normalizar caption canônica/legada e tornar rejeições observáveis;
- YouTube passou a criar o iframe final em `youtube-nocookie.com`;
- certificado agora exige elegibilidade, consulta a fonte pública configurada,
  rejeita data futura e preserva referências legadas com snapshot parcial;
- o worker passou a pseudonimizar evento/usuário/sessão no Sheets e a exclusão
  cria tombstone auditável que limpa linhas já sincronizadas; o teste local com
  sink em memória confirmou purge idempotente;
- checkpoints passaram a validar posição mínima, sequência monotônica e horário
  futuro, reduzindo fabricação de conclusão/Creator Score;
- a API passou a rejeitar HLS sem `.m3u8` e hosts Drive, Docs e
  `googleusercontent` também em playback, thumbnail e legenda;
- ledger passou a exigir `source_event_id`, persistir FK para score/evento e
  rejeitar retry divergente. Uma divergência temporária ORM/migration foi
  detectada e corrigida; o teste agora inspeciona coluna, FKs e unique. A unique
  também foi corrigida para deduplicar a origem/regra/tipo entre scores, e score
  e evento de origem passaram a `NOT NULL` no banco;
- `preReleaseBuild` agora exige `TUTOR_ENVIRONMENT=production` e API, gateway,
  privacidade e exclusão nos endpoints HTTPS produtivos exatos; debug continua
  aceitando somente staging. A matriz Gradle confirmou release produtivo e
  bloqueou release em staging, sem configuração ou com gateway incorreto.

Essas correções continuam sujeitas à repetição da suíte no commit candidato.

## Evidências locais

Executado em 2026-09-20, sem rede de produção:

```text
api/.venv/Scripts/python.exe -m pytest -q
40 passed

flutter test (mídia + turmas, 8 arquivos, --no-pub)
22 passed

tooling/validate_android_environment_gates.ps1
6 cenários aprovados; nenhum APK/AAB gerado

flutter analyze --no-pub
inconclusivo: analysis server encerrou 2x antes da análise por JSON LSP truncado

scan local por chaves privadas/API keys conhecidas
nenhum segredo correspondente encontrado

scan por DeepSeek em código/config executável
nenhum uso encontrado; ocorrências estão apenas em documentação de proibição/inventário
```

### Atualização pós-P1 - Flutter, CPF, telemetria e segredos

Uma revalidação independente posterior, usando exclusivamente Flutter 3.44.9 /
Dart 3.12.2, substitui o resultado Flutter parcial acima:

```text
dart analyze --fatal-infos lib test
zero achados

flutter test --no-pub
127/127 aprovados
```

Esse resultado é do snapshot pós-Monitor/P1 anterior à integração de Assessment
Sync. A repetição do snapshot posterior está registrada abaixo.

Também foi confirmado que:

- CPF é gravado no `FlutterSecureStorage`; a ocorrência `user_cpf` em
  `SharedPreferences` existe somente para migração e remoção da chave legada;
- Chatwoot não recebe CPF e só recebe nome/telefone mediante consentimento;
- Monitor usa `pageId/featureId = monitor_exceptions`;
- check-in usa `pageId/featureId = evidence_checkin`;
- cockpit Evidence usa `pageId = evidence_cockpit`,
  `resourceId = class_session` e `featureId = evidence_engine`;
- a varredura de alta confiança não confirmou segredo privilegiado em código;
  sinalizou somente o identificador público de website do Chatwoot, que deve
  migrar para configuração de build como melhoria P2;
- `.env.deploy` e materiais de assinatura locais estão ignorados e não foram
  lidos ou exibidos nesta revisão.

Evidência detalhada em `docs/testing/FLUTTER_TOOLCHAIN_QA_2026-09-20.md`.

### Atualização após Assessment Sync

O snapshot estabilizado posterior foi repetido de forma independente:

```text
dart analyze --fatal-infos lib test
zero achados

flutter test --no-pub
137/137 aprovados
```

O payload móvel não envia deck, enunciados, alternativas, gabarito,
explicações, dificuldade ou tópicos fracos. 409 mantém a revisão local, consulta
a versão remota e exige escolha explícita; uma tentativa remota concluída não
pode ser sobrescrita.

**P1 do 403 encerrado em 2026-09-20:** a UI informa que a tentativa está segura
no aparelho e que matrícula ativa é necessária, com `Tentar novamente` como
ação explícita. Autosaves posteriores ao 403 apenas preservam/atualizam a fila
local e não repetem PUT; o retry manual revalida o vínculo. Testes de serviço e
widget cobrem ausência de loop, preservação local, mensagem e ação. A
revalidação independente final produziu análise limpa e 137/137 testes.

O teste de migrations cobriu upgrade/downgrade e paridade ORM em SQLite. O teste
legado existente cobre backfill de matrícula, mas não substitui ensaio PostgreSQL
com cópia sanitizada de staging.

## Intervenções externas obrigatórias

1. Publicar e validar o health HTTPS isolado de
   `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`.
2. Fornecer banco, JWT, pepper, planilha, service account e
   `SHEETS_PSEUDONYM_SECRET` estável/exclusivo de staging. Exercitar sync, purge
   pós-exclusão e reconciliação na API Google real; rotação do segredo exige
   procedimento próprio para não perder a capacidade de localizar linhas.
3. Confirmar prefixo público de certificado e executar emissão/verificação com
   dados sintéticos.
4. Definir canal/conta institucional, Shared Drive, responsáveis, direitos,
   retenção e provedor de entrega; Drive não pode ser playback.
5. Aprovar juridicamente Creator Score/ledger. Pagamentos permanecem desligados.
6. Somente depois dos gates técnicos: validar assinatura de upload, Data Safety,
   política/exclusão, release notes e rollout na Play Console.
7. Acrescentar `"TUTOR_ENVIRONMENT": "production"` ao
   `cartilhas_app/config/production.json` local ignorado antes do futuro build;
   o gate bloqueia corretamente o arquivo atual até essa atualização explícita.

## Comandos de repetição no candidato

```powershell
Set-Location api
& ./.venv/Scripts/python.exe -m pytest -q

Set-Location ../cartilhas_app
& 'C:\Users\Usuario\flutter-3.44.9\bin\dart.bat' analyze --fatal-infos lib test
& 'C:\Users\Usuario\flutter-3.44.9\bin\flutter.bat' test --no-pub
```

Não gerar AAB nem instalar APK até staging HTTPS, dados sintéticos e a matriz de
ambiente estarem aprovados.
