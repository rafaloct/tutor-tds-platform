# EAD Identity Broker — design de vínculo TDS ↔ LearnPress (Issue #272)

**Status: TARGET / NOT IMPLEMENTED — documento de decisão, zero implementação.**

Avaliação da arquitetura concreta para vincular voluntariamente a conta
institucional TDS (FastAPI) à conta EAD (WordPress/LearnPress), de modo que o
app Flutter possa oferecer Minha Área/reader autenticado **sem SSO caseiro** e
sem mutação em produção.

## Documentos

| Arquivo | Conteúdo |
|---|---|
| `01_OBSERVED_CAPABILITIES.md` | Fatos verificados (código + sandbox sintético) sobre autenticação em cada lado |
| `02_ALTERNATIVES_MATRIX.md` | Matriz de decisão das abordagens A/B/C + recomendação |
| `03_TARGET_PROTOCOL.md` | Protocolo de vínculo proposto: fluxos, artefatos, revogação |
| `04_THREAT_MODEL.md` | Matriz de ameaças + casos negativos obrigatórios |
| `tooling/qa/ead_identity_broker_design/` | Vetores de teste offline (sem rede, sem segredo) |

## Resumo executivo

- **Não existe federação disponível hoje.** O sandbox WP 7.1.3 + LP 4.3.6 não
  tem provider OIDC/OAuth2 instalado; `wp_is_application_passwords_available()`
  retorna `no` (HTTP loopback); o único token usuário-scoped é o **JWT do
  LearnPress** (`POST /learnpress/v1/token`), válido **7 dias**, **não aceito
  pelo WP core** e **não revogado por logout**.
- **Recomendação rev.2:** Alternativa **B0** — *dois logins separados*,
  EAD sempre no navegador do sistema, **sem vínculo de contas** e sem reader
  autenticado no Flutter. É a única opção que hoje atende à ADR #249 por
  completo.
- **B1 (broker futuro) é BLOCKED**: depende de um mecanismo WP **auditado**
  de confirmação recente de posse/consentimento (browser + provider ou
  endpoint oficial). `token/validate` prova validade, **não** autenticação
  fresca — JWT LP de 7 dias completaria um challenge novo. A variante que
  trafegava senha WP pelo Flutter foi **removida** por violar a ADR.
- **A** (provider OIDC/OAuth2 dedicado no WP) é o alvo ideal de longo prazo,
  igualmente **BLOCKED** hoje: exige plugin de terceiro, homologação e
  instalação por humano.
- **Por que JWT LP não é `EadSessionProof`:** TTL 7d ≫ 15min; aud=LP-REST,
  não broker; logout WP não revoga; sem refresh/escopo; e — novo — um bool
  `brokerVerified` vindo do cliente **não é autenticação**: o proof precisa
  ser artefato assinado ou id opaco resolvido server-side a cada leitura.

## Decisão humana mínima solicitada

1. **B0 confirmado** como política vigente: dois logins, EAD só no browser
   do sistema, sem vínculo — reafirma a ADR, sem implementação nova.
2. **B1/A permanecem BLOCKED**: só voltam à mesa quando existir provider WP
   auditado de proof/consentimento recente — exige decisão humana explícita
   antes de qualquer Issue de implementação.
