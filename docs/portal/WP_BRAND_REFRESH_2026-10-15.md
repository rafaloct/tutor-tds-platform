# WordPress — refinamento visual TDS

## Decisão e limites

O usuário escolheu manter o WordPress existente e melhorar a apresentação com
branding book e colaboração ACP/A2A. Decisão34 substitui Drupal como estratégia
alvo, preservando código, recibos e serviços Drupal. Não houve deploy, ativação
de tema, alteração de API/Flutter, conteúdo/banco produtivo ou credenciais.

Base `b0c39b2`; tema canônico `wordpress/tds-child-theme`, versão0.3.0 candidata.
Plugin/adapters existentes preservados. Os 14 slots, filtros, links configurados,
proveniência das estatísticas e estados indisponíveis continuam operacionais.
Apenas texto e apresentação mudam; não se cria login acadêmico WordPress ou
paridade implícita com os testes autenticados Drupal.

A quarentena continua protegendo `wordpress/legacy-runtime`: manifesto e
workflow permanecem intactos. A retomada autoriza evoluir o tema/core canônicos,
não instalar o snapshot antigo nem ampliar `tds-lms-core`.

## Marca e direção visual

Fonte: `design/BRAND_COMPLIANCE_AUDIT_2026-09-20.md`, manual v1.0/2026 com hash
F9A5E5255BD48F5F2A3C3EEA593E884D39E2502814E0565478492C005355AB4F, cuja presença
foi reconfirmada pelo coordenador. Não há nova homologação Stitch inferida.

- Branco e cinza262626 para leitura; azul093AF4 como direção, vermelhoFF341B,
  amareloF6D846 e verde18D010 como acentos oficiais, sem textos claros sobre amarelo.
- Poppins Regular400, Medium500, Bold700 e ExtraBold800 copiados byte a byte dos
  assets do app, servidos localmente com font-display:swap. Licença SIL OFL1.1
  incluída de google/fonts/ofl/poppins/OFL.txt; metadados dos TTF confirmam a licença.
- Logo e marca isolada existentes coincidem em SHA256 com os assets oficiais do
  app. Nenhum redesenho, recoloração ou distorção. Logo completo≥168px no header,
  sobre branco, com a área de respiro do próprio export preservada.
- Header claro, faixa discreta das quatro cores, hero em duas colunas com painel
  de navegação (não um mock de app), seções com respiro, cards com bordas suaves,
  footer institucional. Em mobile as colunas se empilham.
- Foco visível, skip link, menu progressivo sem JS e reduced-motion preservados.
  Textos ao público deixam de expor implementação ou administração dos adapters.

## Evidência

Proveniência dos logos conferida por hash. Node syntax PASS; verificador da
quarentena PASS56 arquivos. Lint completo PASS35 arquivos (PHP, CSS, JS e
varredura de conteúdo); Node executado localmente e em CLI QA efêmera. Preview
isolado e smoke WordPress real ainda pendentes.

Revisão ACP real coordenada via acpx/Codex no desktop: conferência proposta de
paleta/ink, quatro pesos locais, logo original e respiro, responsividade,
consistência dos CTAs, teclado/contraste e estado de catálogo vazio. A faixa de
quatro cores ficou discreta (4px); a revisão não equivale a aceite visual renderizado.
Não há aceite visual ou WCAG/performance completo por inspeção de código.
