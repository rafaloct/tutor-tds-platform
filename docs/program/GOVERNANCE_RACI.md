# Governança e responsabilidades

## 1. Papéis funcionais

Nomes de pessoas mudam. O sistema deve registrar **papéis**, substitutos e owner institucional.

- Product Owner / Coordenação do Programa
- Responsável pedagógico
- Responsável por dados/LGPD
- Responsável técnico
- Operação/Infraestrutura
- Editorial/Comunicação
- Suporte/Monitoria
- Docente
- Mentor
- Desenvolvedor/Agente
- Release manager
- Auditor/revisor

Uma pessoa pode acumular papéis, mas a documentação deve manter as responsabilidades distintas.

## 2. RACI macro

Legenda: R executa, A aprova, C consultado, I informado.

| Processo | Coordenação | Pedagógico | Dados | Técnico | Infra | Editorial | Suporte | Release |
|---|---|---|---|---|---|---|---|---|
| roadmap/prioridade | A/R | C | C | C | I | I | C | I |
| regra de frequência | A | R | C | C | I | C | C | I |
| conteúdo de curso | A | R | I | C | I | C | C | I |
| notícia pública | A/C | C | C | I | I | R | I | I |
| schema/API | C | C | C | A/R | C | I | I | I |
| dados pessoais/retenção | C | C | A/R | C | C | I | C | I |
| infraestrutura/secrets | I | I | C | C | A/R | I | I | C |
| atendimento | A | C | C | C | I | I | R | I |
| deploy produção | I | I | C | C | R | I | I | A |
| release Play | I | C | C | C | I | I | I | A/R |
| backup/restore | I | I | C | C | A/R | I | I | C |
| incidente de segurança | I | I | A/C | R | R | I | I | C |

## 3. Decisões que agente NÃO toma

- quem é elegível;
- regra institucional de frequência/capacitação;
- concessão de certificado fora do contrato aprovado;
- base legal/retention final;
- identidade visual institucional final;
- compra/licença;
- domínio oficial;
- acesso de pessoas a produção;
- publicação de release;
- rotação/destruição de segredo;
- exclusão irreversível de dado real.

O agente prepara opções, evidências e impacto.

## 4. Hierarquia de decisão técnica

1. segurança/privacidade e contrato institucional;
2. `docs/DECISIONS.md`;
3. contrato de domínio;
4. arquitetura canônica;
5. issue aceita;
6. código existente;
7. implementação nova.

Conflito deve ser interrompido e relatado.

## 5. Segregação de funções

Idealmente:
- autor não é único aprovador do próprio conteúdo;
- agente que implementa não promove produção sozinho;
- restauração é validada por pessoa diferente de quem mantém o único backup;
- conta administrativa não é compartilhada;
- logs/auditoria não podem ser alterados pelo mesmo fluxo que auditam.

## 6. Acessos

Todo serviço deve possuir:
- owner institucional;
- segundo administrador;
- e-mail de recuperação institucional;
- MFA quando suportado;
- inventário de permissões;
- data de revisão;
- procedimento de desligamento/substituição;
- conta de automação separada de conta humana.

## 7. Gate humano

Uma issue marca `HUMAN-GATE` quando depende de:
- decisão normativa;
- credencial/acesso;
- publicação;
- custo;
- dado real;
- mudança irreversível.

O agente deve informar:
- Reason;
- Exact human action;
- What remains unblocked;
- Evidence needed to resume.

## 8. Mudança em produção

Exige:
- issue;
- PR revisado;
- CI verde;
- migração testada quando houver;
- backup recente/restauração conhecida;
- config/preflight;
- plano de rollback/forward recovery;
- responsável pela janela;
- evidência pós-deploy;
- atualização de CURRENT_STATE.

## 9. Auditoria

Registrar ator, timestamp, objeto, ação e motivo para:
- publicação/retirada de curso;
- alteração de turma;
- matrícula/revogação;
- aprovação de certificado;
- evidência/mentoria;
- papel/permissão;
- publicação de mídia;
- mudança de config relevante;
- deploy/migration.

## 10. Continuidade de equipe

A saída de uma pessoa não pode bloquear:
- domínio;
- GitHub;
- Play;
- VPS/Dokploy;
- Cloudflare;
- R2;
- Google Workspace;
- WordPress;
- Chatwoot;
- provedor de mídia;
- recuperação de backup.

Revisar inventário trimestralmente ou a cada troca de equipe.
