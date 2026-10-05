# WP-3 — mapa narrativo e de fontes da experiência pública

Data: 2026-10-04
Escopo: Home pública do Programa TDS.
Status: **IMPLEMENTED no tema / fontes editoriais parcialmente prontas / sem staging ou produção**.

Este documento complementa `WP3_HOME_CONTRACT.md`. Ele não substitui a fonte de
verdade de nenhum domínio e não autoriza publicar automaticamente fotos,
depoimentos, parceiros, números ou conteúdo legado.

## 1. Decisão narrativa

A Home deve evoluir de uma explicação técnico-plataforma para uma narrativa
institucional progressiva:

```text
território → desafio → escuta/articulação → formação → prática →
evidência pública → continuidade
```

O WordPress continua sendo apenas a superfície pública/editorial. Matrícula,
frequência, progresso, certificado, dados pessoais e decisões acadêmicas
permanecem fora do portal.

A alteração desta fatia preserva os 14 slots funcionais e todos os estados
fail-closed de WP-3. O que muda é a linguagem: o visitante deve primeiro
entender por que o TDS existe e como atua; a arquitetura interna não deve ser a
protagonista da Home.

## 2. Inventário de fontes públicas verificadas

### Fonte A — apresentação do TDS a lideranças comunitárias de Palmas

- Publicação: Prefeitura de Palmas, 27/05/2026.
- URL:
  https://palmas.to.gov.br/core/noticias/projeto-territorios-de-desenvolvimento-social-e-inclusao-produtiva-e-apresentado-a-lideres-comunitarios/
- Sustenta publicamente:
  - nome do Programa TDS;
  - vínculo ao MDS e ao Acredita no Primeiro Passo;
  - execução pela UFT;
  - foco em desenvolvimento territorial e inclusão produtiva;
  - escuta das demandas da comunidade como orientação das ações;
  - registro do encontro com 62 lideranças comunitárias.
- Uso autorizado nesta fatia: **fonte editorial**, sem hardcode do número no tema.
- Imagens: a página possui fotografias creditadas, mas a existência pública da
  foto não comprova autorização de reutilização no portal TDS. Tratar como
  `PRECISA_APROVAÇÃO` antes de copiar/importar o arquivo.

### Fonte B — formação de Associativismo e Cooperativismo

- Publicação: UFT, 25/06/2026.
- URL:
  https://www.uft.edu.br/noticias/tds-realiza-curso-sobre-associativismo-e-cooperativismo-para-liderancas-comunitarias-em-palmas
- Sustenta publicamente:
  - realização do primeiro dia da formação em Palmas;
  - público composto por representantes de associações comunitárias;
  - temas de organização coletiva, participação social e desenvolvimento
    territorial.
- Uso: `PRONTO_COM_FONTE` para notícia/história editorial após curadoria.

### Fonte C — curso solicitado a partir da escuta anterior

- Publicação: Prefeitura de Palmas, 23/06/2026.
- URL:
  https://palmas.to.gov.br/core/noticias/lideres-comunitarios-participam-de-curso-de-associativismo-promovido-pela-uft/
- Sustenta publicamente:
  - 61 inscritos no curso;
  - continuidade em três datas;
  - relação explícita entre a demanda apresentada pelas lideranças em maio e a
    formação realizada em junho.
- Uso: evidência concreta da narrativa `escuta → formação`.
- Número: não entra automaticamente em `PortalStatsProvider`; precisa de
  decisão editorial sobre período, denominação e fonte exibida.

### Fonte D — articulação posterior com associações comunitárias

- Publicação: Prefeitura de Palmas, 26/08/2026.
- URL:
  https://palmas.to.gov.br/core/noticias/prefeitura-de-palmas-e-uft-avancam-em-parceria-para-levar-cursos-do-programa-tds-as-associacoes-comunitarias-da-capital/
- Sustenta publicamente:
  - articulação institucional em andamento;
  - previsão de novos encontros para definir locais e datas;
  - cursos, oficinas e orientação como parte da proposta.
- Classificação: **EM ANDAMENTO/PLANEJADO**, não resultado realizado.

### Fonte E — proposta com Casa da Mulher Brasileira

- Publicação: UFT, 23/06/2026.
- URL:
  https://www.uft.edu.br/noticias/tds-apresenta-proposta-de-inclusao-produtiva-a-participantes-da-oficina-de-costura-e-customizacao-da-casa-da-mulher-brasileira
- Sustenta publicamente:
  - apresentação de proposta de inclusão produtiva;
  - iniciativa em fase de elaboração;
  - articulação interinstitucional.
- Classificação: **PLANEJADO/EM ELABORAÇÃO**. Não apresentar como ação concluída.

## 3. Matriz Home → fonte → estado editorial

| Bloco narrativo | Slot WP-3 | Status | Fonte/autoridade | Observação |
|---|---|---|---|---|
| Identidade e propósito | hero | PRONTO_COM_FONTE | docs/program + fontes A/B | Copy pode permanecer institucional e sem números |
| Por que o TDS existe | hero/journey | PRONTO_COM_FONTE | fonte A + PORTAL_AND_CONTENT | Falar em inclusão produtiva e demandas territoriais; não prometer renda/emprego |
| Onde atua | future territorial view | PRECISA_DADO | notícias oficiais por local | Não inferir cobertura completa a partir de notícias pontuais |
| Pessoas e território | stories | PRECISA_ASSET | notícias UFT/Prefeitura + acervo TDS | Fotografias/depoimentos exigem autorização/proveniência antes de importar |
| Como a jornada funciona | journey | PRONTO_COM_FONTE | fontes A/C + docs/program | Linguagem pública: escuta, formação, prática, continuidade |
| Áreas de formação | areas | PRECISA_DADO | conteúdo editorial aprovado | Não inventar taxonomia enquanto provider não publicar termos |
| Cursos | courses | FUTURO | #45 / PR #63 / FastAPI público | Manter fail-closed até adapter autoritativo estar integrado |
| Tecnologia como apoio | tools | PRONTO_COM_FONTE | TARGET_ARCHITECTURE | App/portal/materiais como meios, não como promessa de resultado |
| TDS em números | stats | PRECISA_DADO | PortalStatsProvider + fonte pública | Nada hardcoded; cada item exige source_label/proveniência |
| Histórias de ações | stories | PRONTO_COM_FONTE | fontes B/C e futuros posts revisados | Não migrar automaticamente os 283 posts legados |
| Últimas ações | news | PRONTO_COM_FONTE | WordPress editorial | Somente posts TDS triados/publicados |
| Agenda | agenda | PRONTO_COM_FONTE | tds_event / WP-4 | Evento não equivale a presença |
| Materiais | library | PRONTO_COM_FONTE | tds_material / WP-4 | Somente material público aprovado |
| Parceiros | partners | PRECISA_APROVAÇÃO | publicação institucional | Relação pública não autoriza automaticamente logo/claim de parceria |
| Acesso ao app | app-access | PRECISA_DADO | TDS_Public_Config | CTA aparece apenas quando URL oficial for configurada |
| Certificado | certificate | FUTURO | WP-6 / verificador oficial | Portal não emite/aprova |
| Suporte | support | FUTURO | WP-6 / adapter Chatwoot | Portal não armazena prontuário acadêmico |

## 4. Assets

A pasta oficial indicada em #42,
`1cagbyKQHMALaa9_tiZu3H3T_VBQNNMDU`, contém identidade visual do TDS
(logotipos, marca isolada, ícones e assets de aplicativo).

Na leitura de 04/10/2026, essa pasta **não forneceu um acervo de fotografias de
turmas/territórios suficiente para a Home narrativa**.

Consequência:

- logo/marca: `PRONTO_COM_FONTE`;
- hero com fotografia real: `PRECISA_ASSET`;
- galeria de turma/atividade: `PRECISA_ASSET`;
- rosto/depoimento de participante: `PRECISA_APROVAÇÃO`;
- fotografia encontrada em notícia institucional: continua
  `PRECISA_APROVAÇÃO` para reutilização do arquivo fora da publicação original.

Enquanto isso, o tema deve funcionar sem fotografia genérica. Não usar banco de
imagens para preencher artificialmente essa lacuna.

## 5. Conteúdo que NÃO deve ser transformado em claim

Não converter automaticamente em resultado:

- meta ou objetivo de política/programa;
- número sem período/denominador/fonte;
- atividade planejada;
- parceria em negociação;
- intenção de mentoria;
- promessa de renda, emprego, crédito ou certificado;
- clique, page view ou uso do app;
- conteúdo dos 283 posts legados sem triagem.

A Home deve distinguir explicitamente:

- **realizado**;
- **em andamento**;
- **planejado/em elaboração**;
- **objetivo do programa**.

## 6. Mudança aplicada nesta fatia

Arquivos de tema:

- `wordpress/tds-child-theme/front-page.php`
- `wordpress/tds-child-theme/inc/home-components.php`

Alterações:

1. identidade extensa do TDS no hero;
2. jornada reescrita para `escuta → formação → prática → continuidade`;
3. cursos apresentados como formações do programa, sem linguagem de LMS;
4. tecnologia reposicionada como meio;
5. estatísticas reposicionadas como evidências verificáveis;
6. histórias/notícias apresentadas como ações territoriais;
7. parceiros continuam condicionados a publicação aprovada;
8. app, certificado e suporte mantêm os fallbacks já existentes.

Nenhum:

- endpoint;
- adapter;
- CPT;
- opção WordPress;
- evento analítico;
- schema;
- dado acadêmico;
- backend;
- staging;
- produção

foi alterado.

## 7. Absorção pelas issues atuais

| Mudança | Issue |
|---|---|
| Copy e narrativa da Home | #43 / #27 |
| Fontes para histórias/notícias | #44 |
| Catálogo público | #45 / PR #63, não tocar nesta frente |
| Acesso, suporte e certificado | #46 |
| Fotografias, direitos e conteúdo aprovado | #44 + gate editorial |
| Dados/números com proveniência | #43 + provider aprovado |
| Staging, visual QA e regressão | #47 |
| Staging/rollback operacional | PR #76, não tocar nesta frente |

## 8. Próximos passos públicos, sem dependência do RC

1. Curar 2–4 histórias públicas a partir de fontes institucionais já publicadas,
   preservando link original e classificação de estado.
2. Identificar no acervo oficial quais fotografias têm autorização/proveniência
   adequada para republicação.
3. Só depois criar composição visual com fotografias reais no slot de histórias.
4. Alimentar números via provider com source_label/source_url, nunca em template.
5. Validar a nova narrativa em 360/390/768/1024/1440 dentro do WP-7.
