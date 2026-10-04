# Contrato reference-first para ingestão de mídia

Status: contrato de implementação futura para a Issue #31.  
Base de auditoria: `codex/onda-0-consolidacao` em `d06b1c95ec09035c7ebd8855af34704a85566b0b`.

Este documento descreve o próximo recorte de ingestão administrativa de mídia sem implementar upload, storage ou integração com provider. Ele complementa `docs/architecture/MEDIA_PLATFORM.md`.

## 1. Escopo e não escopo

O objetivo é permitir que creator e coordinator registrem, revisem e publiquem uma **referência de mídia já entregue a um provider**, com trilha explícita de origem e handoff. O FastAPI continua responsável por metadata, RBAC, status e autorização. O Google Drive pode ser o master institucional, mas não é CDN. A VPS não deve servir arquivos de mídia.

Este recorte **não** inclui:

- upload binário pela API;
- Drive API;
- R2 ou object storage real;
- criação de asset em provider pago;
- geração de URL assinada de provider;
- download offline;
- mudança do contrato público de CourseVersion;
- mudança de Flutter;
- migrations.

A implementação futura deste contrato poderá exigir migration; isso fica fora deste documento.

## 2. Estado atual confirmado

No canônico atual:

- `POST /admin/media` cria um `MediaAsset` em `draft` a partir de metadata fornecida pelo cliente;
- `PATCH /admin/media/{id}` edita somente rascunho autorizado;
- `POST /admin/media/{id}/publish` publica diretamente `draft|processing -> published` quando `rights_confirmed=true`;
- `block`, `archive` e `history` já existem;
- creator precisa de vínculo creator ativo e normalmente só pode criar para si;
- coordinator/admin controlam publicação;
- `master_drive_file_id` existe no modelo e não é exposto em `MediaResponse`;
- `provider` e `provider_asset_id` são referências fornecidas externamente;
- não existe upload, validação de MIME/tamanho real, checksum, confirmação de handoff, download grant ou integração Drive/provider;
- `processing` existe como status aceito, mas não há fluxo administrativo canônico que o produza;
- playback grants já são separados de metadata e não devem ser reutilizados como grants de download.

O contrato abaixo define **comportamento-alvo**, não implementação já existente.

## 3. Princípios

1. **Reference-first**: a API registra referências e evidências do handoff; o binário não trafega pela API.
2. **Provider-neutral**: nenhuma regra editorial depende de Cloudflare, YouTube, HLS ou outro provider específico.
3. **Fail-closed**: ausência, inconsistência ou expiração de evidência de handoff impede publicação.
4. **Drive é master, não delivery**: referência ao master nunca vira `playback_url`.
5. **VPS não é CDN**: o host público da API não pode ser destino de mídia.
6. **CourseVersion não guarda grant**: cursos armazenam `media_id`, nunca URL assinada, token ou credencial.
7. **Metadata declarada não é inspeção**: MIME, tamanho e checksum são declarações até existir integração que os confirme.
8. **Idempotência operacional**: retries não podem criar duas mídias ou dois acknowledgments para o mesmo handoff lógico.

## 4. Registro de rascunho

### 4.1 Atores

**Creator**

- pode registrar mídia apenas para si;
- precisa de vínculo `creator` ativo no programa;
- pode editar seu rascunho enquanto ele não estiver publicado/bloqueado/arquivado.

**Coordinator**

- pode registrar ou editar referência no programa sob sua coordenação;
- pode confirmar handoff e publicar após todos os gates;
- não deve transformar ausência de evidência em aprovação implícita.

**Admin**

- mantém autoridade global existente, com as mesmas validações de integridade.

### 4.2 Identidade e escopo

Todo rascunho deve permanecer vinculado a:

- `institution_id`;
- `program_id`;
- `course_id`;
- `module_id`;
- `creator_user_id`;
- `title`;
- `competency_id`;
- `followup_activity_id`;
- `visibility`;
- `offline_policy`.

O programa precisa pertencer à instituição e o curso precisa estar ofertado pelo programa, preservando as validações atuais.

## 5. Metadata de master/referência

O próximo slice deve aceitar metadata declarada separada em dois blocos conceituais.

### 5.1 Master institucional

Campos-alvo mínimos:

- `master_reference_type`: inicialmente `drive_file_id` ou `external_reference`;
- `master_reference`: identificador opaco, nunca URL pública para o aluno;
- `declared_mime_type`;
- `declared_size_bytes`;
- `declared_sha256`.

Regras:

- `declared_mime_type` deve usar MIME permitido por uma allowlist explícita;
- `declared_size_bytes` deve ser inteiro positivo e possuir limite máximo configurado no domínio;
- `declared_sha256` deve conter exatamente 64 caracteres hexadecimais minúsculos;
- a API deve deixar claro que estes valores são **declarados**, não verificados contra o arquivo no recorte reference-first;
- `master_reference` nunca pode aparecer em resposta pública de aluno;
- se o tipo for Drive, somente o identificador do arquivo deve ser armazenado, nunca link de compartilhamento como delivery.

### 5.2 Referência de delivery

Campos-alvo:

- `provider`;
- `provider_asset_id`;
- `handoff_status`;
- `handoff_acknowledged_at`;
- `handoff_acknowledged_by`;
- `handoff_external_reference` opcional, sem credencial.

A semântica deve permanecer compatível com a extração provider-neutral proposta no PR #89, mas o contrato não depende de esse PR estar integrado.

## 6. Handoff para provider

O handoff representa uma confirmação administrativa de que o asset já foi criado/entregue fora da API.

Estados conceituais:

- `not_started`: provider ou asset ainda não informado;
- `pending`: referência foi informada, mas ainda não confirmada;
- `acknowledged`: coordinator/admin confirmou que a referência corresponde ao master declarado e está pronta para validação/publicação;
- `failed`: a tentativa externa falhou ou a referência foi rejeitada.

O acknowledgment deve registrar:

- ator;
- timestamp;
- provider;
- asset id;
- referência do master considerada;
- checksum declarado considerado;
- motivo/nota curta opcional, sem secrets.

O acknowledgment **não prova** upload, integridade criptográfica ou disponibilidade do provider. Ele é evidência operacional administrativa.

## 7. Semântica de `processing`

`processing` deve representar somente:

> referência de delivery registrada, ainda não liberada para publicação enquanto os gates administrativos e técnicos do handoff não estiverem concluídos.

Transições alvo do próximo slice:

```text
draft -> processing
processing -> draft       # correção/retry
processing -> published   # somente após gates
draft -> published        # deve deixar de ser permitido no novo fluxo
published -> blocked
published|blocked -> archived
```

Regras:

- entrar em `processing` exige master/reference metadata mínima e provider reference informada;
- falha de handoff mantém ou devolve a mídia para um estado editável, sem apagar histórico;
- retry deve atualizar a tentativa lógica sem perder evidência anterior;
- `processing` não torna mídia visível no catálogo;
- `processing` não pode criar playback grant;
- nenhuma transição deve depender de polling do provider neste slice.

## 8. Pré-condições de publicação

No comportamento-alvo, `publish` deve falhar quando qualquer condição abaixo não for satisfeita:

1. ator é coordinator autorizado ou admin;
2. status atual é `processing`;
3. `rights_confirmed=true`;
4. lineage instituição/programa/curso/módulo continua válida;
5. master/reference metadata mínima está completa;
6. MIME declarado pertence à allowlist;
7. tamanho declarado está dentro dos limites;
8. SHA-256 declarado é estruturalmente válido;
9. provider é suportado pelo contrato vigente;
10. `provider_asset_id` é estruturalmente válido;
11. handoff está `acknowledged`;
12. acknowledgment pertence à versão corrente da referência, não a uma referência antiga;
13. destino de delivery não é Drive;
14. destino de delivery não é o host da API/VPS;
15. não existe credencial, token administrativo ou signed URL persistida como metadata pública.

No recorte reference-first, não se deve alegar que MIME, tamanho ou checksum foram conferidos contra o arquivo real.

## 9. Falha e retry

Falhas possíveis devem ser representáveis sem apagar o rascunho:

- referência de master ausente/inválida;
- metadata declarada inválida;
- provider não suportado;
- asset id inválido;
- handoff externo não concluído;
- referência alterada depois do acknowledgment;
- direitos não confirmados;
- conflito de edição;
- falha editorial/revisão.

Regras de retry:

- alterar master, checksum, provider ou asset invalida acknowledgment anterior;
- retry não pode promover automaticamente para `published`;
- toda nova confirmação deve registrar ator e timestamp;
- histórico deve preservar transições relevantes;
- respostas 409 devem ser usadas para conflito de estado/revisão, mantendo o padrão atual de CAS quando aplicável;
- validação de payload deve falhar com 422, sem side effect parcial.

## 10. Direitos e responsabilidade editorial

`rights_confirmed` continua obrigatório, mas não pode ser o único gate.

No próximo slice:

- creator pode declarar os dados necessários;
- coordinator/admin confirma o handoff e decide publicar;
- confirmação de direitos deve ser persistida de forma atribuível ao fluxo atual;
- mudar referência de master ou delivery depois da confirmação exige revalidação dos gates antes de publicar.

Este contrato não cria workflow jurídico nem substitui termo de cessão/autorização.

## 11. Fronteira de delivery

O backend é responsável por:

- metadata;
- status;
- RBAC;
- auditabilidade;
- grants de playback;
- resolução provider-neutral.

O backend **não** deve:

- servir vídeo master;
- usar a VPS como CDN;
- devolver `master_drive_file_id` ao aluno;
- persistir grant de playback em CourseVersion;
- tratar link do Drive como URL de playback;
- armazenar credencial de provider em payload público.

O provider é responsável pela entrega efetiva. O master institucional permanece desacoplado.

## 12. Fronteira de download/offline

`offline_policy=allowed` continua sendo apenas permissão declarativa enquanto não existir infraestrutura de download.

Não implementar download no próximo slice.

Contrato futuro esperado:

- grant de download separado de `MediaPlaybackGrant`;
- URL curta/assinada e com expiração;
- vínculo com usuário, matrícula, media_id e asset autorizado;
- storage privado no cliente;
- expiração/revogação;
- nenhum master Drive exposto;
- nenhum grant persistido no CourseVersion ou cache de catálogo.

Até esse contrato existir:

- `allowed` não significa que existe download funcional;
- UI não deve prometer disponibilidade offline de arquivo;
- playback online continua independente.

## 13. Critérios de aceitação executáveis para o próximo slice

A próxima implementação só está concluída quando testes automatizados provarem todos os itens abaixo.

### 13.1 Registro e RBAC

1. creator ativo cria draft próprio com metadata reference-first válida;
2. creator não consegue criar mídia em nome de outro usuário;
3. creator sem membership ativo recebe 403/422 conforme o contrato existente;
4. coordinator/admin conseguem operar dentro de suas permissões;
5. aluno/outsider não conseguem acessar operações administrativas.

### 13.2 Metadata declarada

6. MIME fora da allowlist retorna 422;
7. tamanho zero, negativo ou acima do limite retorna 422;
8. checksum que não seja SHA-256 hex de 64 chars retorna 422;
9. master Drive/reference não aparece em `MediaResponse` pública;
10. nenhuma signed URL ou credencial é persistida em CourseVersion.

### 13.3 Processing e handoff

11. draft sem metadata mínima não entra em `processing`;
12. draft com metadata válida e provider reference válida entra em `processing`;
13. `processing` não aparece no catálogo publicado;
14. `processing` não recebe playback authorization;
15. coordinator/admin pode registrar acknowledgment;
16. creator sozinho não pode autoaprovar handoff se não possuir papel de publicação;
17. alterar master/checksum/provider/asset invalida acknowledgment anterior;
18. retry preserva histórico e não duplica o MediaAsset.

### 13.4 Publicação

19. `draft -> published` direto é recusado;
20. publish sem `rights_confirmed` é recusado;
21. publish sem acknowledgment corrente é recusado;
22. publish com lineage inválida é recusado;
23. publish com provider/asset inválido é recusado;
24. publish usando Drive como delivery é recusado;
25. publish usando host da API/VPS como delivery é recusado;
26. `processing -> published` válido mantém o comportamento público atual de catálogo/playback.

### 13.5 Regressão

27. playback grant atual continua opaco, temporário e revogável pelo status/vínculo;
28. block/archive continuam invalidando acesso conforme comportamento existente;
29. `master_drive_file_id` continua backend-only;
30. testes atuais de mídia permanecem verdes;
31. nenhuma chamada real a Drive, R2, provider pago ou staging é necessária para validar o slice.

## 14. Forma mínima da próxima implementação

O próximo slice deve ser limitado a:

- modelos de request/response e persistência necessários ao contrato reference-first;
- endpoints administrativos para mover draft para processing e registrar acknowledgment;
- gates de publicação;
- audit trail;
- testes unitários/API;
- documentação de operação.

Deve permanecer fora:

- upload binário;
- worker de transferência;
- Drive API;
- R2 real;
- provider pago;
- Flutter;
- download offline;
- staging/produção.

A implementação deve nascer do canônico vigente no momento da execução e, se o adapter provider-neutral já estiver integrado, reutilizá-lo. Se não estiver, os gates devem ser escritos de modo desacoplado para que a integração posterior não altere o contrato editorial.