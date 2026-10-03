# Fluxos e hierarquias ponta a ponta

## 1. Hierarquia organizacional e pedagógica

A nomenclatura exata deve seguir as entidades reais do domínio. O desenho lógico é:

```mermaid
flowchart TD
  I[Institution] --> P[Program]
  P --> O[Offer / oferta]
  P --> C[Course]
  C --> CV[CourseVersion]
  O --> CL[Class / Cohort]
  CL --> EN[Enrollment]
  U[User] --> M[Membership]
  M --> EN
  EN --> LC[LearningContext]
  CV --> LC
  CL --> LC
  LC --> A[Activity/Attempt]
  LC --> PR[Progress]
  LC --> CE[Certificate Request/Reference]
  LC --> EV[Evidence/Mentorship quando aplicável]
```

Regra: a UI pode simplificar nomes, mas autorização usa IDs/contexto completo.

## 2. Hierarquia de autoridade

```text
decisão institucional
    ↓
contrato de domínio
    ↓
API autorizada
    ↓
persistência PostgreSQL
    ↓
eventos/projeções
    ↓
Sheets/BI/portal/support context
```

Nunca inverter a seta para conceder direito com base em projeção.

## 3. Jornada do participante

```mermaid
flowchart LR
  B[Baseline/origem quando houver] -->|vínculo revisado| U[Pessoa]
  U --> M[Matrícula]
  M --> T[Turma/edição]
  T --> S[Estudo]
  S --> AT[Atividades]
  T --> F[Presença oficial]
  AT --> P[Progresso]
  F --> EL[Elegibilidade de conclusão]
  P --> EL
  EL --> CR[Solicitação/validação certificado]
  T --> ME[Mentoria opcional]
  ME --> E[Evidência revisada]
  T --> FU[Follow-up 30/60/90]
  CR --> BI[Projeção BI]
  E --> BI
  FU --> BI
```

Baseline não cria matrícula automaticamente.

## 4. Novo curso

```mermaid
sequenceDiagram
  participant C as Creator/Editor
  participant API as FastAPI
  participant DB as PostgreSQL
  participant M as Media/Storage
  participant R as Revisor
  participant A as App
  C->>API: criar curso/version draft
  API->>DB: persistir draft
  C->>API: registrar materiais
  API->>M: upload/ingestão autorizada
  C->>API: submeter revisão
  R->>API: aprovar/publicar
  API->>DB: snapshot published
  A->>API: atualizar catálogo
  API-->>A: nova versão/metadados
```

Nenhum rebuild do app deve ser necessário para conteúdo editorial normal.

## 5. Nova notícia

```mermaid
sequenceDiagram
  participant E as Editorial
  participant W as WordPress
  participant P as Público
  participant A as App
  E->>W: draft
  E->>W: revisão/publicação
  W-->>P: página pública
  A->>W: feed público
  W-->>A: resumo + URL
```

Notícia não passa pelo PostgreSQL acadêmico.

## 6. Atendimento

```mermaid
flowchart LR
  U[Usuário] --> APP[Flutter]
  APP --> API[Contexto mínimo]
  API --> APP
  APP --> CW[Chatwoot]
  CW --> AG[Agente humano]
  AG -->|se ação acadêmica necessária| CMD[Comando API autorizado]
  CMD --> DB[(PostgreSQL)]
```

Etiqueta/macro Chatwoot não substitui CMD autorizado.

## 7. Mídia

```mermaid
flowchart LR
  D[Drive master] --> I[Ingestão]
  I --> P[Provider/R2]
  I --> API[Metadata]
  API --> DB[(PostgreSQL)]
  APP[Flutter] --> API
  API --> G[Playback grant]
  G --> APP
  APP --> P
```

## 8. Dados/BI

```mermaid
flowchart TD
  APP[Flutter] --> API[FastAPI]
  API --> DB[(PostgreSQL)]
  DB --> EX[Export/Sync]
  EX --> SH[Sheets]
  SH --> BI[Power BI]
  DB --> JE[Journey Export]
  JE --> BI
  BASE[Baseline] -. vínculo revisado .-> DB
```

Linha pontilhada = vínculo controlado, não ingestão irrestrita.

## 9. Release

```mermaid
flowchart LR
  I[Issue] --> B[Branch]
  B --> PR[Draft PR]
  PR --> CI[CI/checks]
  CI --> RV[Review]
  RV --> ST[Staging]
  ST --> AC[Acceptance]
  AC --> PF[Preflight]
  PF --> HG[Human release gate]
  HG --> PD[Production]
  PD --> SM[Smoke/monitor]
  SM --> CS[CURRENT_STATE/evidence]
```

## 10. Incidente

```mermaid
flowchart TD
  A[Alert/relato] --> T[Triage]
  T --> S{Severidade}
  S -->|SEV1/2| C[Conter]
  S -->|SEV3/4| F[Corrigir programado]
  C --> R[Recuperar]
  R --> V[Validar]
  V --> P[Postmortem]
  P --> I[Issue preventiva]
```

## 11. Backup/restore

```mermaid
sequenceDiagram
  participant S as Serviço stateful
  participant B as Job backup
  participant O as Offsite storage
  participant K as Custódia de chave
  participant R as Restore isolado
  S->>B: snapshot/dump
  B->>B: criptografar/checksum
  B->>O: upload
  O-->>B: readback
  K-->>R: chave autorizada
  O-->>R: backup
  R->>R: decrypt + restore + smoke
```

Objeto e chave não devem depender da mesma credencial única.

## 12. Hierarquia operacional de responsabilidade

```text
Coordenação / Product Owner
├── Pedagógico
├── Dados/LGPD
├── Comunicação/Editorial
├── Suporte/Monitoria
└── Tecnologia
    ├── Desenvolvimento
    ├── Infra/Operação
    └── Release/Segurança
```

Isso é separação de responsabilidade, não organograma institucional obrigatório.

## 13. Pontos de decisão humana

- regra de frequência;
- elegibilidade/mentoria;
- publicação institucional;
- liberação produção;
- retenção/privacidade;
- acesso administrativo;
- compra de provider;
- exclusão irreversível.

Agentes podem preparar implementação e testes, mas não fabricar essas decisões.
