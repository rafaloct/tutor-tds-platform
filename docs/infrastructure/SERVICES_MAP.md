# Mapa de Serviços

```text
Flutter Android / PWA
  |
  +--> Cloudflare Worker
  |      +--> AnythingLLM `anythingllm`
  |      |      +--> OpenRouter / Gemini 2.5 Flash Lite
  |      |      +--> Weaviate
  |      +--> Cloudflare KV (certificados)
  |
  +--> Google Apps Script --> Google Sheets
  |
  +--> Suporte Chatwoot

VPS / Dokploy
  +--> PWA Nginx
  +--> TDS Sync
  +--> LMS Lite API + Dashboard
  +--> PostgreSQL/pgvector
  +--> RAG auxiliar + Ollama
  +--> n8n / Evolution / serviços compartilhados
```

O backend transacional da Onda 1 ainda não existe como serviço identificado. Google Sheets e armazenamento local continuam sendo partes do fluxo produtivo atual.
