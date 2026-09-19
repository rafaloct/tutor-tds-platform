# Tutor TDS - Inventário da VPS

> Auditoria somente leitura realizada em 2026-09-19. Nenhum serviço, firewall, volume ou dado foi alterado.

## Resumo

| Item | Estado confirmado |
|---|---|
| Host | `srv1533541` |
| Sistema | Ubuntu 24.04.4 LTS, kernel 6.8.0-90 |
| CPU | 8 vCPU AMD EPYC 9354P |
| Memória | 31 GiB; aproximadamente 23 GiB disponíveis |
| Swap | 4 GiB; 3,4 GiB em uso no momento da auditoria |
| Disco raiz | 387 GiB; 319 GiB usados (83%); 68 GiB livres |
| Timezone | UTC, NTP sincronizado |
| Docker | 29.3.1 |
| Docker Compose | 5.1.1 |
| Dokploy | 0.29.1, saudável |
| Proxy principal | Traefik 3.6.7 |
| Acesso | chave ED25519 dedicada, root em `BatchMode` |

## Serviços relevantes confirmados

- `anythingllm`: RAG usado pelo app, saudável, porta 3001 publicada.
- `cartilhastds-anythingllmwithweaviate-...-weaviate-1`: banco vetorial Weaviate.
- `compose-copy-redundant-alarm-18gsr7-cartilhas-web-1`: web/PWA em Nginx.
- `kreativ-tds-sync`: sincronização TDS, saudável.
- `kreativ-lms-lite-api` e `projeto-tds-lms-lite-dashboard-1`: API e painel LMS existentes.
- `kreativ-postgres`: PostgreSQL/pgvector 16, saudável.
- `kreativ-rag` e `kreativ-ollama`: segunda pilha RAG interna.
- `dokploy`, `dokploy-postgres`, `dokploy-redis` e `dokploy-traefik`.
- Chatwoot, n8n, Evolution API, WordPress/MySQL/Redis, PocketBase e serviços Frappe.

O servidor é compartilhado por vários projetos. Nenhum container ou modelo deve ser removido supondo que pertence apenas ao Tutor TDS.

## IA e requisito sem DeepSeek

| Instância | Provider ativo | Modelo preferencial |
|---|---|---|
| `anythingllm` | OpenRouter | `google/gemini-2.5-flash-lite` |
| `kreativ-rag` | OpenRouter | `liquid/lfm-2.5-1.2b-thinking:free` |

O Ollama público possui `deepseek-v3.1:671b-cloud` baixado, mas ele não está selecionado em nenhuma das duas instâncias AnythingLLM auditadas. O Tutor TDS deve manter allowlist sem DeepSeek. A remoção do modelo não foi feita porque a VPS é compartilhada.

## Rede e exposição

O UFW está inativo e a chain `INPUT` do nftables aceita tráfego por padrão. Foram observadas escutas públicas, entre outras, em:

`22`, `25`, `80`, `110`, `143`, `443`, `587`, `631`, `993`, `995`, `2377`, `3000`, `3001`, `7946`, `8090` e `11434`.

Riscos prioritários:

1. AnythingLLM (`3001`), Ollama (`11434`), PocketBase (`8090`) e Dokploy (`3000`) estão publicados em todas as interfaces.
2. Portas de Docker Swarm (`2377` e `7946`) aparecem em escuta ampla.
3. O firewall do host não restringe explicitamente esses acessos.

Não alterar firewall ou bindings antes de mapear dependências, testar um segundo acesso SSH e preparar rollback.

## Risco crítico de disco e logs

- Um log JSON do container `kreativ-postgres` mede aproximadamente **235,9 GB**.
- `logrotate.service` falhou com `No space left on device` durante a rotação.
- O disco raiz está em 83% e o crescimento do log pode esgotá-lo.

A correção exige janela controlada: preservar amostra para diagnóstico, configurar rotação Docker (`max-size`/`max-file`), validar o motivo do volume de logs e somente então truncar/arquivar o arquivo com autorização.

## Serviços systemd com falha

- `logrotate.service`: falha por falta de espaço durante cópia do log Docker.
- `nginx.service`: falha ao ocupar a porta 80, já utilizada por outro processo Nginx. O tráfego web continua atendido, mas há conflito de responsabilidade entre Nginx do host e Traefik/containers.

## Backups

- `/backup` e `/backups` não existem.
- `/var/backups` contém apenas backups padrão do sistema (dpkg/apt), cerca de 3,1 MB.
- Não foi confirmada rotina de backup dos volumes Docker, bancos, AnythingLLM ou aplicações.
- Snapshots da Hostinger não foram auditados pelo shell.

Conclusão: backup de aplicação e restauração permanecem não demonstrados.

## Ações seguras seguintes

1. Corrigir crescimento de logs em janela aprovada.
2. Inventariar dependências das portas publicadas e propor fechamento gradual.
3. Criar backups versionados de PostgreSQL, volumes AnythingLLM e configuração Dokploy.
4. Criar `tdsdeploy`, testar segunda sessão e somente depois revisar acesso root.
5. Separar staging e produção antes das migrations da Onda 1.
