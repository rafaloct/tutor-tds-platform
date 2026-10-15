# WordPress — refinamento visual TDS

## Decisão e limites

O usuário escolheu manter o WordPress existente e melhorar a apresentação com
branding book e colaboração ACP/A2A. Decisão34 substitui Drupal como estratégia
alvo, preservando código, recibos e serviços Drupal. Não houve deploy, ativação
de tema, alteração de API/Flutter, conteúdo/banco produtivo ou credenciais.

Base `b0c39b2`; tema canônico `wordpress/tds-child-theme`, versão0.3.1 candidata.
O core recebeu adapter HTTP público opt-in; contratos e sanitização existentes preservados. Os 14 slots, filtros, links configurados,
proveniência das estatísticas e estados indisponíveis continuam operacionais.
O catálogo consulta a API pública quando habilitado; não se cria login acadêmico WordPress ou
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
isolado e smoke WordPress reais: PASS180 verificações em WordPress7.1.2,
PHP8.4.26 e Astra4.13.1, antes do refinamento posterior abaixo.

Revisão ACP real coordenada via acpx/Codex no desktop: conferência proposta de
paleta/ink, quatro pesos locais, logo original e respiro, responsividade,
consistência dos CTAs, teclado/contraste e estado de catálogo vazio. A faixa de
quatro cores ficou discreta (4px); a revisão não equivale a aceite visual renderizado.
Não há aceite visual ou WCAG/performance completo por inspeção de código.


## Revisão visual do preview e refinamento posterior

Preview descartável:180 checks PASS, WordPress7.1.2/PHP8.4.26/Astra4.13.1.
Browser em1440/390/360px sem overflow horizontal, erros JS ou imagens quebradas;
quatro fontes carregadas e menu toggle/Escape PASS. Isso difere da produção
observada pelo coordenador (WordPress6.7.2/PHP8.2.28); não inferir equivalência
integral sem o gate de compatibilidade/deploy.

A captura completa revelou página desktop de7310px com avisos amarelos
repetidos em slots vazios. Corrigido no candidato0.3.1: indisponível/desabilitado/
vazio usam superfícies neutras, ícones e texto menores. Seções sem cards ou
conteúdo têm padding proporcional e cabeçalho/status lado a lado em desktop;
mobile mantém coluna única. Slots/estados/fallbacks não são removidos. Erros
acionáveis conservam destaque. Texto do catálogo passa a orientar nova tentativa,
sem expor conexão ou implementação. Preview preenchido e rerender deste ajuste
aguardam o coordenador. Issue213 acompanha o refinamento; nenhum deploy.


## Recibo final — candidato 1b4ee37 / PR #214 / issue #213

OBSERVED: manual oficial lido (15 páginas); SHA256 coincide com a auditoria.
ACP executado via acpx/Codex no desktop, seguido por implementação e revisão
independente do adapter. Nenhuma alegação de homologação automática da marca.

TESTED: rerender do tema0.3.1 em Chrome/Playwright, 1440×1000,390×844,360×800:
sem overflow horizontal, exceções JS ou imagens quebradas; quatro pesos locais
Poppins carregados; menu mobile abre e Escape fecha. Inspeção visual de desktop
 e mobile confirmou hierarquia, proporções e legibilidade. Imagens lazy foram
aguardadas por decode antes de registrar o resultado. Não é auditoria WCAG completa.

HTTP REAL: WordPress descartável consumiu o endpoint público existente
`https://ead.ipexdesenvolvimento.cloud/tutor-api/public/courses` via adapter,
sem autenticação: state ready,6 cursos na página,total9. Os três viewports
renderizaram6 cards. O transporte fsocket inicialmente apresentou timeout;
habilitar a extensão nativa cURL no PHP QA resolveu, sem desabilitar TLS ou
relaxar validação de destino. Egress do QA restrito a GET desse endpoint;
e-mail bloqueado. A flag foi ativada somente na cópia QA.

Ambiente: WordPress7.1.2/PHP8.4.26/Astra4.13.1/SQLite sintético local.
Produção observada: WordPress6.7.2/PHP8.2.28,childtheme2.0.0 e LearnPress ativo.
Compatibilidade exata com esse ambiente, backup/rollback de tema e conteúdo e
mapeamento dos links/configurações produtivos ainda são gates de promoção.
Não houve deploy ou alteração do banco produtivo. Conteúdo institucional da
prévia é ilustrativo; títulos com QA são fixtures, não conteúdo para publicar.

Evidências versionadas:
- [Desktop](evidence/wp-brand-2026-10-15/desktop-top.png)
- [Mobile](evidence/wp-brand-2026-10-15/mobile-top.png)
- [Resultados browser](evidence/wp-brand-2026-10-15/browser-results.json)

Retorno seguro: candidato ainda não ativado em produção. Na promoção futura,
guardar o tema ativo e opções atuais; voltar a esses arquivos/opções e desligar
`TDS_PUBLIC_CATALOG_ENABLED` em caso de regressão. Não remover volumes/serviços.
Área privada e IA não foram adaptadas nesta fatia. A fonte acadêmica continua API.
