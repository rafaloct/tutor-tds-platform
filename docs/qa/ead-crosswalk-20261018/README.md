# F1 | Crosswalk público LearnPress × Tutor TDS, 18/10/2026

**Issue:** #253. **Dependências:** ADR #249 / PR draft #250, Epic #224, inventário pedagógico #230 / PR draft #232.
**Status:** `TESTED-LOCAL` e leitura pública `TESTED-LIVE-READONLY` apenas para nomes e IDs. **Não é mapeamento institucional aprovado**, SSO funcional, matrícula integrada ou liberação de AAB.

## Objetivo e definição operacional

Dar a humanos e agentes uma maneira inequívoca de identificar quais cursos públicos do LearnPress **parecem corresponder**, pelos dados observados, aos cursos publicados na API TDS. O mapa é intencionalmente **candidato**. Não atribui `CourseVersion`, acesso, matrícula em turma, frequência, RAG ou certificado por inferência.

| Termo | Autoridade | Uso nesta fatia |
|---|---|---|
| `wp_course_id` | LearnPress | ID público estável da oferta no EAD; não é `course_id` TDS |
| `tds_candidate_slug` | FastAPI, catálogo público | Sugestão editorial a revisar, nunca chave de direito |
| `published_version_label` | FastAPI, catálogo público | Rótulo observado (p.ex. `v1`), **não** `course_version_id` |
| `mapping_status=candidate_review` | Snapshot de QA, não transacional | Relação preliminar, sem aprovação humana |
| `mapping_status=unmapped` | Snapshot de QA | Oferta LearnPress adicional sem vínculo TDS confirmado |
| `institutional_access=false` | Política de segurança do snapshot | O **crosswalk não concede** qualquer direito; não afirma que o usuário jamais terá acesso por outro processo |
| `editorial_approval=null` | Fluxo humano futuro | Ausência deliberada de revisão, não sinônimo de rejeição |

## Catálogos e mapeamento observado

| Curso LearnPress | WP ID | Slug candidato FastAPI | Estado |
|---|---:|---|---|
| Inteligência Artificial e Inclusão Digital | 614 | `ia-cartilha` | candidato |
| Agricultura Sustentável | 1298 | `agricultura-sustentavel` | candidato |
| Atendimento ao Cliente | 1307 | `atendimento-cliente` | candidato |
| Audiovisual para o Dia a Dia | 1314 | `audiovisual` | candidato |
| Cooperativismo e Crédito | 1321 | `cooperativismo` | candidato |
| Economia do Lar | 1328 | `economia-lar` | candidato |
| Educação Financeira | 1335 | `educacao-financeira` | candidato |
| Inspeção e Certificação (SIM/SIMA) | 1343 | `sim-sima` | candidato |
| Sistemas Agroflorestais (SAF) | 1356 | `saf` | candidato |
| Automações com o Celular para o Pequeno Negócio | 1474 | **não mapeado** | `unmapped` |
| IA aplicada a Processos Internos | 1709 | **não mapeado** | `unmapped` |

A tabela foi composta com **IDs e títulos públicos** coletados em 18/10/2026. As nove associações de slug foram enumeradas explicitamente, sem algoritmo que transforme títulos em direitos. Cada linha ainda exige curadoria editorial, versão de curso, reconhecimento institucional e, quando aplicável, critérios de certificação. As duas ofertas adicionais permanecem EAD-only até revisão do público-alvo, vinculação ou decisão de mantê-las separadas.

### Fontes e proveniência

- LearnPress: `GET https://ead.ipexdesenvolvimento.cloud/wp-json/learnpress/v1/courses?per_page=100` — **11 cursos** na resposta pública.
- Tutor TDS: `GET https://ead.ipexdesenvolvimento.cloud/tutor-api/public/courses` — **9 cursos** publicados, com slugs e rótulos de versão.
- Arquivo `public-source-snapshot.json`: SOMENTE `{id,name}` do LearnPress e `{slug,title,status,published_version_label}` da FastAPI. Nenhum campo de usuário, conta, telefone, CPF, tokens, gabarito ou acesso.
- Arquivo `course-crosswalk-candidates.json`: onze linhas com `editorial_approval:null`, `tds_course_version_id:null`, `institutional_access:false`, `rag_authorized:false`, `certificate_authorized:false`.
- Auditoria curricular **separada**: PR #232 / Issue #230 já contém as seções, 48 candidatos de vídeo e quizzes ainda sem vinculação. Não duplicar ou assumir aprovação de suas aulas nesta F1.

## Como executar, sem credenciais

Da raiz do repositório, usando Python 3.11+:

```bash
python -m unittest discover -s tooling/qa/ead_crosswalk -p 'test_*.py' -v
python tooling/qa/ead_crosswalk/audit.py
python tooling/qa/ead_crosswalk/audit.py --live
```

O primeiro comando testa regras com fixtures congeladas **sem acesso à rede**. O segundo valida schema e consistência offline. O terceiro lê **somente os dois endpoints HTTPS públicos da allowlist**, sem cookies/token, sem redirecionar, com timeout e limite de tamanho, e compara IDs, títulos, slugs, estado e label ao snapshot. Nenhum comando grava dados ou altera os arquivos do snapshot.

Resposta observada na primeira execução em 18/10: `candidate_matches=9`, `unmapped_wp_ids=[1474,1709]`, `authoritative_links=0`, `institutional_permissions_granted=0`, `live=PASS`.

**Falha significa parada:** mudança de título, ID, versão publicada ou número de cursos retorna `AUDIT_BLOCKED` e exit code **2**. Não atualizar automaticamente snapshot ou correspondência. Conferir na origem, comparar o diff, solicitar curadoria e produzir novo PR deliberado.

## Limites, dependências e critérios de entrega

**OBSERVED:** 11 ofertas públicas EAD, nove cursos públicos TDS, nove pares candidatos por nome/slug, dois sem correspondência, ausência de um verdadeiro identificador `CourseVersion` na resposta pública.
**DECIDED:** LearnPress é autoridade da inscrição/progresso na oferta EAD; FastAPI é autoridade de identidade/turma/frequência/certificado institucional; app projeta sem recriar LMS.
**TARGET:** mapeamento assinado curso/versão por equipe pedagógica, `wp_lesson_id`/`quiz_id` com edição de cartilha aprovada, vinculação opaca `tds_user_id↔wp_user_id`, estado de Minha área e feedback ao aluno.
**UNKNOWN/BLOCKED:** CourseVersion institucional real de cada oferta, estado da conta aluno, esquema de progresso autenticado, disponibilidade de quizzes por matrícula, direitos editoriais da mídia e público das ofertas #1474/#1709. Esperar F0 de Devin (#252) e revisão humana.

**Próxima ação do executor humano/editorial:** revisar cada uma das nove sugestões com os IDs de curso e edição autorizados, decidir se as duas ofertas extras terão integração institucional e registrar a aprovação em canal com autoria/revisão. Não alterar `mapping_status` nesta fatia: uma alteração de status requer contrato de autorização diferente e PR específico.

**Gates:** nenhum merge antes da revisão; nenhum deploy, migração, provisionamento, troca de matrícula, emissão de certificado, build oficial ou Play. `MERGE_ALLOWED=NO`, `PRODUCTION_ALLOWED=NO`, `FORCE_PUSH_ALLOWED=NO`.

## Handoff para F2/F3

Para a futura "Minha área", a interface deve consultar o progresso **real da conta LearnPress** por sessão autorizada (F0/F2), sem derivá-lo do crosswalk. Um aluno pode estar matriculado em uma das onze ofertas LP sem ter turma institucional TDS; não preencher cartão "matrícula institucional" com esse dado. O crosswalk serve somente para apresentar a relação editorial quando revisada, nunca para consultar uma conta pelo nome ou CPF.

Arquivos deste recorte: `docs/qa/ead-crosswalk-20261018/*.json`, este README e `tooling/qa/ead_crosswalk/audit.py` + `test_audit.py`. Branch e PR próprios, sem editar a branch do Devin.
