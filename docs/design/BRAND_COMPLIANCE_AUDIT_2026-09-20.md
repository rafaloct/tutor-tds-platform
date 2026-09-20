# Tutor TDS - auditoria de conformidade da marca

Data: 20/09/2026

## Fontes verificadas

- `C:\Users\Usuario\Downloads\Nova pasta (2)\Manual_Identidade_Visual_TDS.pdf`
  - título interno: *Manual de Identidade Visual - TDS*;
  - versão 1.0 / 2026;
  - 15 páginas inspecionadas visualmente;
  - SHA-256:
    `F9A5E5255BD48F5F2A3C3EEA593E884D39E2502814E0565478492C005355AB4F`.
- `C:\Users\Usuario\Downloads\Nova pasta (2)\logo-tds.svg`
  - SVG vetorial sem bitmap, padrão ou conteúdo base64;
  - SHA-256:
    `58CABBB10ED2DDA8692D3BD0D64C927226F8E8788E2620A1FBCEF628CBFAD25E`.
- exports oficiais encontrados em
  `FORMULÁRIOS-20260409T214310Z-3-001/FORMULÁRIOS/manualmarca/assets-exportados`.

## Regras oficiais aplicáveis ao app

- cores puras: azul `#093AF4`, vermelho `#FF341B`, amarelo `#F6D846` e
  verde `#18D010`;
- textos longos preferem cinza-escuro `#262626`; branco é o fundo neutro;
- família Poppins: Bold/ExtraBold para marca e títulos, Medium para destaques e
  Regular para corpo;
- a marca não pode ser distorcida, rotacionada, recolorida ou colocada em fundo
  de baixo contraste;
- área de proteção mínima equivalente à altura da letra T;
- no digital, logotipo completo com tagline exige no mínimo 120 px de largura;
  marca sem tagline, 80 px; símbolo detalhado, 48 px; simplificado, 16 px;
- ícone de app sempre usa fundo sólido branco ou azul, nunca transparente;
- splash usa a marca centralizada, sem tagline, em fundo branco ou azul;
- o símbolo D detalhado deve ocupar aproximadamente 66% da área central do
  foreground adaptativo e o ícone deve manter cerca de 20% de margem visual.

## Resultado no repositório

| Item | Estado | Evidência |
|---|---|---|
| Paleta TDS | Conforme | tokens do tema usam os quatro HEX oficiais |
| Tipografia | Conforme | Poppins está configurada e usada no app |
| Marca isolada e logotipo | Conforme | assets atuais coincidem com os exports do manual |
| Ícones Android | Conforme | `mdpi`, `hdpi`, `xhdpi`, `xxhdpi` e `xxxhdpi` são byte a byte iguais aos exports oficiais correspondentes |
| Fundo do ícone | Conforme | export oficial usa fundo sólido conforme o manual |
| Logos parceiros na Home | Conforme no recorte técnico | FAPTO/CDR foram rasterizados deterministicamente das fontes vetoriais, IPEX usa o JPG limpo e todos aparecem em cards brancos no modo escuro, sem o quadriculado anterior |
| FAPTO | Fonte vetorial localizada | `C:\Users\Usuario\Downloads\fapto logo.svg`, sem bitmap/base64 |
| CDR | Fonte vetorial localizada | `C:\Users\Usuario\Downloads\cd centro logo.svg`, sem bitmap/base64 |
| IPEX | Parcial | existe JPG limpo com fundo branco, mas não foi localizado SVG/PNG realmente transparente |
| Ordem/papel dos parceiros | Pendente institucional | o manual TDS não normatiza a assinatura conjunta IPEX/UFT/FAPTO/CDR |

## Decisão de implementação

1. Não redesenhar nem reconstruir logos com IA.
2. Rasterizar deterministicamente os vetores originais de FAPTO e CDR para PNG
   transparente, preservando proporção e cor.
3. Usar o JPG limpo do IPEX em card branco, sem tentar remover fundo ou
   inventar transparência.
4. Aplicar fundo branco e padding consistente a todos os parceiros na faixa da
   Home, garantindo contraste no tema escuro.
5. Preservar a ordem e os rótulos atuais até confirmação institucional.

## Validação física e gate restante

A identidade TDS está fundamentada pelo manual oficial. A build
`1.4.0-dev+13` foi instalada no Xiaomi em modo escuro e a captura
`docs/testing/evidence/2026-09-20/xiaomi-branding-partners-fixed.png` confirmou
os quatro parceiros legíveis, proporcionais e sem o quadriculado incorporado.

Resta somente a confirmação institucional da ordem/assinatura conjunta. Um
vetor oficial do IPEX continua desejável, mas não impede o uso seguro do JPG
limpo em card branco.
