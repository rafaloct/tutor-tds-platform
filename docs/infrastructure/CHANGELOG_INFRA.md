# Changelog de Infraestrutura

## 2026-09-19 - Auditoria somente leitura

- Responsável: Codex.
- Serviço: VPS Tutor TDS.
- Alteração: nenhuma em produção; inventário e verificação SSH.
- Resultado: acesso por chave validado, topologia registrada e riscos de disco/rede identificados.
- Rollback: não aplicável.

## 2026-09-20 - API transacional e páginas de política

- Responsável: Codex.
- Serviço: Tutor TDS API.
- Alteração: nova pilha Docker Compose com API FastAPI, PostgreSQL 16 dedicado,
  páginas de política/exclusão e rotas Traefik HTTPS. Migrations Alembic e nove
  cartilhas carregadas.
- Segurança: segredos gerados diretamente na VPS, `.env` modo 600, banco sem
  porta pública, logs limitados e exclusão autenticada da conta.
- Backup: dump diário às 03:20 UTC, retenção local de 14 dias; primeiro dump
  validado.
- Verificação: health/cursos 200; cadastro 201; evento 201; analytics 200;
  exclusão 204; token revogado 401; políticas públicas 200.
- Rollback: parar a pilha `docker-compose.production.yml`; o volume dedicado é
  preservado e não deve ser removido.
