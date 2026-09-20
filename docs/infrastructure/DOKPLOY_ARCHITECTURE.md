# Arquitetura Dokploy e Docker

> Estado observado em 2026-09-19, somente leitura.

## Plano de controle

- Dokploy `0.29.1` em Docker Swarm.
- PostgreSQL 16 e Redis 7 dedicados ao Dokploy.
- Traefik `3.6.7` publica HTTP/HTTPS.
- O host também possui Nginx fora do fluxo do Dokploy, atualmente com conflito na porta 80.

## Pilhas relacionadas ao TDS

```text
Internet
  |
  +--> Traefik / Nginx
         |
         +--> PWA Cartilhas TDS
         +--> AnythingLLM + Weaviate
         +--> LMS Lite API + Dashboard
         +--> TDS Sync
         +--> Chatwoot / n8n / Evolution API
         +--> PostgreSQL/pgvector + Ollama + RAG auxiliar
```

## Restrições

- A VPS é multiaplicação; nomes `kreativ-*` e outros composes podem atender projetos externos ao app.
- Não remover imagens, volumes, modelos ou redes por nome sem rastrear o consumidor.
- Não usar diretamente o PostgreSQL existente como banco transacional do novo backend sem isolamento, backup e teste de capacidade.

## API Tutor TDS publicada

Em 2026-09-20, a API passou a rodar em compose isolado em
`/opt/tutor-tds-api`, ligada à rede externa `dokploy-network` somente no serviço
HTTP. O PostgreSQL dedicado permanece na rede interna. O Traefik publica
`https://ead.ipexdesenvolvimento.cloud/tutor-api` e as duas páginas de política.

## Staging proposto

Criar um projeto Dokploy separado, rede separada e banco/schema separado. Publicar apenas via Traefik com TLS e health check. O staging deve receber migrations e validação antes de produção.
