# Tutor TDS — prontidão produtiva e recuperação (02/10/2026)

**PRODUCTION_RELEASE_READY=false. Nenhum AAB deve ser gerado nesta rodada.**
Pergunta operacional: "Se o notebook desaparecer hoje, o Tutor TDS continua
funcionando?" A API histórica na VPS respondeu `/health` 200 e o app Play
histórico não depende do notebook para iniciar; porém fonte canônica GitHub,
recuperação completa e compatibilidade do *próximo* release não estão provadas.
Portanto a resposta para continuidade/recuperação verificável é **NÃO
COMPROVADO**, nunca SIM por inferência de healthcheck.

## Fonte Git e dois computadores

Inventário inicial: branch `codex/onda-0-consolidacao`, HEAD
`f3ee6f49ad35103ae2a89038d1f9887269568bd3`; 48 arquivos tracked
modificados e 3.669 caminhos untracked antes do novo recorte (3.576 em
`outputs/`). Sem remote e sem tags; `gh` indisponível no PATH. Nada foi
comitado, descartado ou enviado. `.gitignore` agora separa `/outputs/` sem
apagar seu conteúdo. Código/testes, migrations, contratos e evidências QA
curadas devem ser revisados para commits; APKs, cópias de PBIP, exports
massivos e dumps não devem entrar inadvertidamente no Git. Um clone **ainda
não** reconstitui a cópia BI/artefatos em `outputs/`; antes de afirmar paridade
dos desktops, criar destino privado de artefatos com hash/retention/controle
de acesso e manifesto das dependências externas, sem publicar dados QA reais.

Plano proposto, **exige aprovação antes de commits** porque código,
migration 0020, gates físicos e evidências estão interdependentes:
1. commits revisados de API + migration + testes, com contrato compatível;
2. Flutter/journey/catálogo/editor + testes focados, sem configs secretas;
3. contratos e evidências pequenas sanitizadas com hash e referência externa
   dos outputs preservados; manter freeze de `release_status.json`;
4. gates de ambiente/release e seus testes; revisar diff/segredos antes de
   cada stage. Nunca usar `git add .` sobre a árvore não auditada.

Reason (intervenção externa): não há autenticação/remote GitHub e é preciso
escolher o destino privado e a custódia de artefatos grandes. Exact human
action: instalar/disponibilizar GitHub CLI, executar `gh auth login` pelo
próprio titular sem compartilhar token, confirmar repositório privado
`tutor-tds-platform` e aprovar o plano de commits/artefatos. What remains
unblocked: auditoria, documentação e testes locais; criação de origin/push
aguardam acesso e revisão sem tocar `master` destrutivamente.

## Triagem de secrets antes de GitHub

Relatar somente tipo/caminho/estado, nunca valor. `api/.env.example`,
`api/staging.env.example`, `api/staging-seed.env.example` e
`cartilhas_app/android/key.properties.example` são modelos tracked e exigem
revisão de placeholders. `.env.deploy`, `android/key.properties`,
`android/upload-keystore.jks`, definições QA em `tmp/` e
`cartilhas_app/config/production.json` são locais/ignorados, nunca stage.
`cartilhas_app/android/upload_certificate.pem` está tracked e foi identificado
como certificado X.509 **público**, não como chave privada. Há um website
widget token Chatwoot visível no código cliente; não é credencial de servidor,
mas permissões e abuso precisam de revisão. A busca histórica por nomes
sensíveis só achou examples e certificado; busca de padrões de alta confiança
indicou fixtures em testes, não prova varredura exaustiva de todos os blobs.
Auditar também untracked JSON/evidências e binários antes de qualquer push;
rotacionar credencial real eventualmente identificada antes da promoção.

## Dados e arquivos

| Local atual | Proteção confirmada | Lacuna/riscos |
| --- | --- | --- |
| PostgreSQL Tutor API | compose versionado define PostgreSQL 16 com volume nomeado interno; `/health` consultou DB | volume real, revision e réplica/restauração produtiva não verificados nesta rodada; perda da VPS sem offsite pode perder matrículas/eventos |
| Outbox/cache/secure storage Flutter | sandbox do aparelho, cache por URL, SQLite de fila com dono/API | desinstalação/perda do aparelho perde dados ainda não sincronizados; não é backup do backend |
| Certificados KV Worker | legado permanece em Cloudflare, PDFs derivados salvos no aparelho | export/restore KV e reconciliação API→Worker não comprovados; não confundir referência com emissão |
| Nove PDFs de curso | links Drive dos assets, não dados transacionais da API | permissão/disponibilidade e bytes da edição no Drive podem mudar, arquivos não estão congelados pelo Git |
| PWA/privacidade, seed | `api/public` e `api/seed` montados read-only no compose; código no workspace | presença no host/deploy reproduzível depende de proveniência Git e configuração Dokploy |
| Media/attachments/evidence | metadados na API; upload binário/object storage é alvo arquitetural, Drive institucional armazena masters propostos | uploads/fotos/arquivos da VPS e volumes AnythingLLM/Weaviate sem inventário+offsite+restore completo; não inventar bucket atual |
| BI e export QA | fonte Sheets original preservada; overlay/cópia PBIP em `outputs/` no computador | clone não inclui outputs ignorados; Fabric e cópia privada não provam backup do acervo analítico |
| Dokploy/Traefik/TLS | compose com labels Traefik TLS; HTTPS público validado | configuração/secrets/certificados runtime e restauração completa ainda não auditados |

Backups conhecidos: script da API em `/opt/tutor-tds-api/ops/backup.sh`, cron
histórico diário 03:20 UTC, retenção local 14 dias, gzip/hash; offsite
(`BACKUP_OFFSITE_DIR`) e criptografia (`BACKUP_AGE_RECIPIENT`) são opcionais.
O endurecimento versionado pode não estar implantado. Um ensaio isolado
0005→0020 e cópia DPAPI fora da VPS em 01/10 foram verificados, mas dependem
do perfil Windows e **não** constituem restore drill independente e contínuo
de produção. Hostinger snapshots, volumes compartilhados, KV, masters Drive
e configuração Dokploy continuam sem prova conjunta de recuperação.
Requisito mínimo bloqueante: RPO/RTO definidos; backup automático diário
validado e alertado; retenção explícita; cópia criptografada fora da VPS com
chave independente; restore em ambiente isolado de PostgreSQL, volumes,
configuração e certificados; checksums e evidência com horário/versão/ator.
Um dump que nunca passou restore não conta como backup comprovado.

## Gates obrigatórios do próximo AAB

| # | Gate | Estado nesta auditoria |
| --- | --- | --- |
| 1 | commit e tag identificáveis | FAIL: sem tag/working tree suja |
| 2 | GitHub privado atualizado | FAIL: sem remote/autenticação CLI |
| 3 | working tree de release limpa | FAIL: mudanças e QA por revisar |
| 4 | API de produção canônica resolvida | PASS parcial: `/tutor-api` confirmado; provenance ainda não |
| 5 | API produtiva saudável/HTTPS | PASS pontual: GET `/health` 200 e TLS válido; `/live` 404 |
| 6 | PostgreSQL produção persistente | PENDING: compose define volume; host runtime não comprovado |
| 7 | DATABASE_URL remota/interna do compose comprovada | PENDING: config candidate endurecida, deploy/running env não auditados |
| 8 | sem endpoints/flags local ou staging no build | FAIL: config ignorada atual reprovou preflight; nenhuma promoção |
| 9 | schema/backend ↔ app compatível | FAIL: GET `/version` produção 404 |
| 10 | migrations aplicadas no destino correto | PENDING: revision produtiva não inspecionada nesta rodada |
| 11 | backup configurado/monitorado | PENDING: offsite opcional |
| 12 | restauração independente comprovada | FAIL: falta aceite do restore produtivo completo |
| 13 | secrets fora do Git e histórico revisado | PENDING: triagem por path; auditoria final antes do push |
| 14 | HTTPS/domínio/SSL válidos | PASS pontual para endpoint API existente |
| 15 | testes de release | PENDING: recortes locais apenas, suíte completa na janela de release |
| 16 | upgrade do app publicado 1.2.0+11 | FAIL: não validado para código 1.4.0+13 candidato |
| 17 | build manifest sem secrets | PENDING: script futuro o gera após gates |
| 18 | AAB SHA-256 | PENDING: nenhum AAB autorizado nesta rodada |

A API atual não expõe revision Alembic nem versão mínima suportada; contrato
proposto em `ENVIRONMENT_CONTRACT.md`. `tooling/build_production.ps1` requer
configuração produtiva exata, signing/freeze físico, tag+origin sincronizado,
`PublishedVersionCode` real informado pelo titular, health+`/version`,
`docs/production/evidence/production-restore-acceptance.json` com campos
`status=passed`, `offsite_backup`, `postgres_restore`,
`critical_volumes_restore`, `upgrade_compatibility`,
`backend_schema_compatibility` verdadeiros, Flutter 3.44.9, testes/analyze.
Esse arquivo de aceite **não existe** e não deve ser fabricado. Só após tudo
isso o script construiria AAB e `release/build-manifest.json` com
`versionName`, `versionCode`, `git_commit`, `git_tag`, timestamp UTC,
environment, api_base_url, flags, api/schema version e SHA-256 do AAB. Nunca
escrever URL de banco ou secrets no manifesto. Gate Android Gradle é defesa
adicional, não substitui backup, restore, proveniência ou decisão humana.

Comando futuro (NÃO executar agora):
`powershell -File tooling/build_production.ps1 -Flutter <SDK_3.44.9>/bin/flutter.bat -PublishedVersionCode <CODIGO_PLAY_CONFERIDO>`.
`-PreflightOnly` executa só gates e não cria AAB; preflight local desta rodada
foi bloqueado por configuração produtiva ignorada divergente, sem revelar seu
conteúdo. Produção, Play, assinatura e `release_status.json` permaneceram
intocados. Aprovação futura exige revisar este documento contra evidência real,
nunca alterar security/freeze para fazer o build passar.
