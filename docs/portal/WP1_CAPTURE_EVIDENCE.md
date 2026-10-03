# WP-1 — Registro sanitizado de captura

Data da observação: 2026-10-03 UTC. Escopo: auditoria somente leitura do WordPress/Dokploy e export sanitizado do código customizado instalado.

## Fonte observada

- Host público: ead.ipexdesenvolvimento.cloud.
- Compose Dokploy observado: ead-wordpress-stack / compose-program-open-source-monitor-szkpni.
- Código customizado instalado em /root/tds-wordpress e bind-mounted no container WordPress.
- Git local observado: branch master, HEAD 5311fd7b65c0e6891660b234e9f47b5ff91b5635, sem remote configurado.
- Snapshot sanitizado produzido fora da VPS; .env, Git metadata, vendor e caches foram excluídos antes de versionar.

## Cadeia de captura

1. Inventário read-only de container, versões, mounts, temas, plugins, páginas, rotas e metadados Dokploy.
2. Cópia apenas do código customizado e arquivos operacionais permitidos.
3. Exclusão explícita de segredos e artefatos não necessários.
4. Sanitização de URLs tokenizadas de convites/formulários e valores de teste.
5. Varredura de segredos no recorte sanitizado.
6. Versionamento em wordpress/legacy-runtime como referência histórica, não como artefato de deploy.
7. Manifesto de integridade calculado sobre bytes de Git blob para ser estável entre checkouts Windows/Linux.

Arquivo de captura sanitizado intermediário: SHA-256 0F79F21FBEC37A2E21EB3A076CEE684E13D4107818CBBDC34D3A70C4E43DBB09.

Esse hash identifica a exportação sanitizada intermediária usada na auditoria; o estado canônico revisável é o conjunto de Git blobs listado em WP1_LEGACY_SOURCE_MANIFEST.json.

## Limites

- Nenhum dump de banco, uploads, mensagens, caixas postais, .env, segredo ou token foi incorporado.
- Nenhuma conclusão de comprometimento foi feita a partir do conteúdo legado; a proveniência permanece em #48.
- Staging e rollback foram planejados, não executados nesta captura.
