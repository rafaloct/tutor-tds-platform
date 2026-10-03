# RC-D — materiais remotos por edição e módulo (#31)

Base: `873962afb613f183a7f1d81e97d5d77979278fd6`. Reservas: #37 comentários
5970153310, 5970180402 e 5970187437. Candidato local; não constitui aceite de
staging, dispositivo, provider ou produção. #52 permanece sem retorno comprovado.

## Contrato implementado

`CourseVersion.content.sections[].materials` é lista opcional (default vazia),
limitada a 50 itens por módulo. Cada item possui `id` estável único no módulo,
`kind` (`pdf`, `video`, `link`), `title` e exatamente um destino:

- PDF/link: `url` pública HTTPS, até 2000 caracteres, sem credenciais, query,
  fragmento, espaços ou barras invertidas. Não usar URLs assinadas, PII ou secrets.
- Vídeo: `media_id` de MediaAsset existente. O manifesto não copia playback URL,
  master Drive, grants nem credenciais do provider.

Campos adicionais são recusados. Título tem até 240 caracteres. IDs aceitam
letras ASCII, números, hífen e underscore (material até 120, mídia até 36).
Os URLs são referências públicas externas; não há upload, inspeção de MIME ou
garantia de disponibilidade do conteúdo remoto neste recorte.
Destinos exigem hostname DNS (IPs literais e nomes/sufixos locais recusados),
porta HTTPS padrão 443. Isso valida a referência escrita, não resolve DNS nem
controla redirecionamentos posteriores do host; revisar o destino público continua
parte da publicação editorial. Não representa proteção contra DNS rebinding.

O editor existente adiciona/edita/remove materiais por módulo, salva o rascunho,
mostra conferência e usa submit/publish com RBAC/revision CAS existentes. Vídeos
devem estar publicados na mesma instituição/programa/curso/módulo; a verificação
ocorre tanto no envio para revisão quanto na publicação. Alteração posterior
exige nova edição. Turmas fixadas na anterior preservam seu manifesto. Nenhuma
migration, entidade paralela, mudança de autorização acadêmica ou provider novo.

## Consumo e falhas

O leitor oferece “Materiais do módulo” no módulo atual. A lista mostra os três
formatos e abre PDF/link externamente por controller seguro, sem crédito por
clique. Vídeo reconsulta `GET /media/{id}` online sem fallback/cache de autorização,
confere ID/publicação/curso/módulo e reutiliza player e grants existentes. Resposta
tardia após troca de sessão não abre o player. Indisponibilidade/negação/rede
falha mantêm mensagem genérica e permitem tentar novamente. Estados vazio e
carregando explícitos; metadados da edição podem estar em cache, arquivos não.
Reprodução já aberta tem os limites do player/provider existente; este recorte
não introduz DRM, revogação instantânea de segmentos ou disponibilidade real.

## Gate RC e operação

`REMOTE_CATALOG_ENABLED` continua **false por padrão**. O candidato de teste deve
ser configurado explicitamente com true e a API isolada autorizada. Essa primeira
configuração/build é necessária; depois o operador publica novas edições e a
recarga do catálogo no mesmo binário recebe os materiais, sem recompilação a cada
edição. Não habilitar produção nem confundir essa opção com aprovação de release.

PDF/link só recebem endereços públicos estáveis. Para vídeo, operador usa o ID
da mídia previamente publicada pelo fluxo administrativo existente. Criação/
upload de mídia, provider fake #52, storage e UI de ingestão permanecem recortes
próprios. Nenhuma suposição de execução/entrega de #52.

Rollback: reverter o candidato antes da promoção. Após publicação, retirar uma
edição pelo lifecycle existente ou publicar nova edição corrigida; nunca mutar
snapshot antigo. Bloqueio de vídeo continua pelo fluxo MediaAsset existente.

## Matriz focal e limites

| Fronteira | Evidência local | Gate restante |
|---|---|---|
| Editor → API | validação, RBAC, draft oculto, linhagem, publicação | operação em staging |
| Edição → turma | snapshot anterior preservado no fork/publish | conferência física |
| API → catálogo/cache Flutter | refresh três formatos na mesma instância | mesmo APK/dispositivo |
| Vídeo → player/grant | detalhe online e rejeição sem fallback | provider sintético/real conforme autorização |
| PDF/link externos | controller com sucesso/falha simulado | abrir arquivo/site em dispositivo |

Comandos focais (SDK histórico 3.44.9, junction exclusivo
`C:/Users/Usuario/.codex/tmp/tutor-tds-materials-qa`; Python ambiente criado por
`uv sync --locked --extra test` neste checkout):

```text
api/.venv/Scripts/python -m pytest tests/test_course_editor.py -q
dart run build_runner build --build-filter=lib/models/cartilha.g.dart
flutter test test/remote_materials_test.dart test/course_editor_screen_test.dart test/course_editor_repository_test.dart test/course_repository_test.dart test/media_repository_test.dart
flutter analyze lib/features/remote_materials lib/features/course_editor lib/features/media/data/media_repository.dart lib/models/cartilha.dart lib/screens/chat_experience_screen.dart test/remote_materials_test.dart
git diff --check
```

TESTED-LOCAL em 03/10/2026: API 49/49; Flutter 45 casos únicos concluídos
(lote 44 PASS + um finder falho, seguido do arquivo focal 7/7 PASS após correção);
analyze focal sem issues; codegen e diff-check PASS. Os dois testes antigos do
editor precisaram rolar ListView até construir a ação fora do viewport; assertions
de conflito/revisão foram preservadas. Finder de vídeo foi corrigido para o título
do tile, pois título e subtítulo iguais duplicavam o ancestral. Sem afrouxar runtime.

Inspeção heurística redigida de 13 arquivos alterados/novos encontrou zero padrões
de alta confiança de chaves/tokens. Não equivale a scanner completo; scan
autoritativo permanece gate CI. Revisão estática independente sem bloqueador após
correção de destinos locais. SHA final consta no checkpoint/revisão do PR.
Nenhum deploy, AAB,
dados reais, secrets ou chamadas a provider real foram usados nesta validação.
