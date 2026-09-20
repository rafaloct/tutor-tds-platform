# Mapa de Serviços

```text
Flutter Android / PWA
  |
  +--> Tutor TDS API (`/tutor-api`)
  |      +--> PostgreSQL 16 dedicado (rede interna)
  |      +--> conta, hierarquia, eventos, horas e analytics
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
  +--> API Tutor TDS + PostgreSQL dedicado
  +--> páginas públicas de privacidade/exclusão
  +--> TDS Sync
  +--> LMS Lite API + Dashboard
  +--> PostgreSQL/pgvector
  +--> RAG auxiliar + Ollama
  +--> n8n / Evolution / serviços compartilhados
```

O backend transacional foi publicado em 2026-09-20. O TDS Sync/Google Sheets
existente continua independente; conectá-lo formalmente à nova base permanece
uma etapa posterior de reconciliação, sem interromper o fluxo atual.
