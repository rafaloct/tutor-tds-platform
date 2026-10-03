# API pública v1 do Portal TDS

Refs #28 e #45.

## Recorte implementado

A API já possuía `GET /courses`, usado pelo Flutter para entregar o conteúdo completo das cartilhas. Alterar esse contrato para uma allowlist pública quebraria o consumidor do app e misturaria dois objetivos diferentes.

Por isso, o portal recebe uma projeção pública separada:

- `GET /public/courses`
- `GET /public/courses/{slug}`

Somente cursos `active=true` com uma `CourseVersion` em estado `published` aparecem.

## Campos

Sempre:
- `slug`
- `title`
- `status=published`
- `published_version_label`
- `updated_at`

Somente quando já existem como metadata pública explícita:
- `summary`
- `cover_public_url`
- `public_workload_text`
- `public_audience_text`

A API não infere carga, público, modalidade, área, FAQ, destino de participação ou materiais a partir de campos internos.

## Não exposto

A projeção não devolve:
- sections/messages/conteúdo pedagógico integral;
- downloadUrl legado;
- course_version_id interno;
- IDs de usuário, matrícula ou membership;
- CPF/NIS/telefone;
- progresso, presença, baseline ou evidências;
- storage IDs/tokens/credenciais.

## Paginação e cache

`GET /public/courses?offset=0&limit=50`, com limite máximo 100.

Respostas públicas válidas recebem:
`Cache-Control: public, max-age=60, stale-while-revalidate=300`.

## Gaps deliberados

`GET /public/program` não foi criado porque o modelo atual de Program possui apenas nome e instituição, sem narrativa/metadata pública aprovada.

`GET /public/materials` não foi criado porque não existe entidade/campo canônico que distinga material público de arquivo pedagógico/privado.

Os campos pedidos pelo WP-5 (#45) — modalidade, área, conteúdo detalhado, materiais públicos, FAQ, CTA/destino e disponibilidade pública — permanecem gaps até ganharem representação canônica. O WordPress deve ocultar esses componentes em vez de inventar dados.

## Compatibilidade

`GET /courses` permanece intacto para o Flutter. A projeção do portal é independente e read-only.
