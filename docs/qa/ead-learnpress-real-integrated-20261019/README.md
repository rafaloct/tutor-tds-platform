# LearnPress real sintético — candidato integrado IPEX

Data: 19/10/2026. Executor: LARGeo. Fonte funcional sob teste:
`c853db021368f4b536521800ed9dc33ef68e3aac`.

## Estado

- **OBSERVED:** o teste do PR #292 registrava manualmente os post types e uma
  rota `/learnpress/v1/courses/{id}` simulada. Ele continua válido como prova de
  WordPress core, mas não como prova LearnPress real.
- **TESTED-LOCAL:** WordPress 7.1.2, LearnPress 4.3.6 e SQLite Database
  Integration 3.0.2 reais foram instalados do zero em diretório descartável. O
  adaptador integrado foi conferido por hashes e passou **76 verificações** com
  a rota LearnPress nativa, modelos/CURD e hooks reais.
- **DECISION:** a fixture contém um único administrador
  `@qa-synthetic.test`; capacidades LearnPress equivalentes ao administrador
  institucional já auditado na Issue #276 foram concedidas somente no banco
  descartável. Nenhuma permissão externa foi alterada.
- **UNKNOWN/HUMAN_GATE:** instalação institucional, plugins/tema/proxy do EAD,
  contas reais, SSO, matrícula, quizzes, notas, direitos das 48 aulas e save do
  formulário no WordPress público não foram exercitados.

## Ambiente isolado

- raiz final:
  `D:\AI-Shared\tmp\tutor-tds\learnpress-real-c853db0-final-20261019`
- banco SQLite sintético: 663.552 bytes, SHA-256
  `9AB8FE3064F899602B31129CEC3C40A5AE061A84D40D6C7929D818C3392869B5`;
- origem configurada: `http://127.0.0.1:18731`;
- `WP_HTTP_BLOCK_EXTERNAL=true`; nenhum servidor HTTP foi iniciado e não ficou
  listener na porta 18731;
- um usuário sintético, um curso final, uma seção, uma aula publicada e uma aula
  draft; zero linha em `learnpress_user_items`.

Pacotes oficiais usados:

| Pacote | SHA-256 |
| --- | --- |
| `wordpress-7.1.2.zip` | `8FC96C59A78B7219E4A130222B7FADB51B03E503E8B0123BEAA7E28961C21CE2` |
| `learnpress.4.3.6.zip` | `1230172064C3065E131F95F25D5A8772255E85B725842EADE28BF24B0FF61A20` |
| `sqlite-database-integration.3.0.2.zip` | `1602E75577AD9B3A7E3E4A6A44A81B9541CDEE2124D48928FAF61C6FD3CD4F74` |
| `wp-cli.phar` 2.12.0 | `CE34DDD838F7351D6759068D09793F26755463B4A4610A5A5C0A97B68220D85C` |

## Aceite final

`test-learnpress-runtime.php` não registra rota LearnPress sintética. Ele
comprovou:

1. WordPress, LearnPress, post types, classes e hashes exatos do adaptador;
2. curso, seção e aulas criados por post types/CURD do LearnPress real;
3. `/learnpress/v1/courses/{id}` HTTP 200 com seção real;
4. currículo TDS consumindo essa rota e ETag 304;
5. aula fechada antes do opt-in e draft omitido;
6. primeira submissão MP4/VTT fechada e segunda aprovada;
7. troca de MP4 ou VTT revogando o fingerprint até nova confirmação;
8. MP4 sem VTT válido e alternativa YouTube preservada;
9. zero matrícula, progresso ou outro `learnpress_user_items` criado.

Resultado final: `LEARNPRESS_REAL_INTEGRATED_QA_PASS`, **76/76**, exit 0.

- log:
  `D:\AI-Shared\test-results\tutor-tds\learnpress-real-c853db0-20261019\learnpress-real-runtime-final.log`
- SHA-256 do log:
  `40E949E804342D284047A5A2F7AB7DCCB47388F7F3BBB78FB563464C51CF1D5B`
- SHA-256 do teste:
  `E1E619D2D460CA8C598016E22B36F155BF035A3D2DB61E6AC636BA835A6A20B7`

O PHP local emitiu os warnings preexistentes de `mysqli` duplicado e
`pdo_firebird` ausente. Eles não afetaram o exit 0 nem SQLite/LearnPress.

## Tentativas anteriores

- tentativa 1: incompatibilidade do `declare(strict_types=1)` com `wp eval-file`;
- tentativa 2: fixture sem capacidades LearnPress, reproduzindo a fronteira RBAC
  já documentada na Issue #276;
- tentativa 3: o CURD retornou todos os itens da seção e o harness selecionou o
  item publicado em vez do draft;
- tentativa 4: execução funcional PASS, mas contador final estava no escopo
  errado do `eval-file`;
- tentativa 5: 76/76 na fixture de desenvolvimento;
- execução final acima: 76/76 numa segunda instalação criada do zero.

Essas correções alteraram somente o harness. Nenhuma falha funcional do
adaptador integrado permaneceu aberta.
