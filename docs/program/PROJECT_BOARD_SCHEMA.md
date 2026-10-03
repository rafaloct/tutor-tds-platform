# GitHub Project — estrutura recomendada

Nome: **Tutor TDS — Plataforma Permanente**

## 1. Campos

### Status
- Intake
- Triagem
- Ready
- Em desenvolvimento
- Aguardando humano
- Blocked
- Review
- Staging
- Accepted
- Done

### Prioridade
- P0 bloqueante/segurança/continuidade
- P1 núcleo operacional
- P2 melhoria/escala
- P3 oportunidade

### Área
- App Flutter
- API/Domínio
- Dados/BI
- Portal/WordPress
- Conteúdo
- Chatwoot/Suporte
- Mídia
- IA/Gateway
- Certificados
- Infra/Dokploy
- Backup/DR
- Segurança/Privacidade
- CI/Release
- Governança/Docs

### Tipo
- Epic
- Feature
- Bug
- Infra
- Security
- Data
- Documentation
- Research/Decision

### Ambiente
- N/A
- Local
- Staging
- Production

### Risco
- Low
- Medium
- High
- Critical

### Human Gate
- None
- Decision
- Access
- Data
- Cost
- Release
- Production

### Executor
- Human
- ChatGPT/Codex
- Devin
- Windsurf
- Other agent

Campos adicionais:
- Depends on
- Target wave
- Evidence URL
- Owner functional
- Owner technical

## 2. Views

### Execução
Board por Status, filtro not Done.

### P0/P1
Tabela prioridade + dependências + owner.

### Por área
Board por Área.

### Agentes
Filtro executor agente; mostrar Status, Human Gate, Risk, Depends on.

### Bloqueios humanos
Filtro Human Gate != None ou Status = Aguardando humano.

### Release
Área CI/Release, Infra, Security, Backup; mostrar Environment e Evidence.

### Portal e conteúdo
Área Portal/WordPress + Conteúdo + Mídia.

### Jornada do aluno
API/Domínio + App + Dados/BI, filtrado para identity/enrollment/presence/certificate/mentorship/follow-up.

## 3. Regra de entrada

Issue só vai a Ready se tiver:
- objetivo único;
- contexto;
- arquivos prováveis;
- autoridade do dado;
- dependências;
- critérios de aceite;
- testes;
- fora de escopo;
- human gate;
- risco;
- rollback quando aplicável.

## 4. Regra de Done

Done significa critérios aceitos para o escopo da issue. Não significa deploy de produção, salvo quando a issue disser explicitamente.

## 5. Auto-add sugerido

Associar issues do repositório `rafaloct/tutor-tds-platform`. Se usar workflow do GitHub Projects, evitar auto-marcar Ready sem os campos mínimos.

## 6. Convenção de título

```text
[P0][AREA][STATUS] verbo + resultado
[P1][PORTAL][READY] Implantar arquitetura pública do portal TDS
[EPIC][P1][MEDIA] Plataforma de mídia desacoplada
```

## 7. Dependências

Não confiar somente em texto. Usar campo Depends on e repetir no corpo quando bloqueante.
