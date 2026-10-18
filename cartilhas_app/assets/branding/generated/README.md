# Assets gerados — identidade TDS (2026-10-18)

Assets ilustrativos gerados localmente para telas do app/portal, seguindo o
Manual de Identidade Visual TDS (ver `docs/design/BRAND_COMPLIANCE_AUDIT_2026-09-20.md`).

## Conformidade com o manual

- Paleta oficial nos prompts: azul `#093AF4`, vermelho `#FF341B`, amarelo `#F6D846`,
  verde `#18D010`, cinza `#262626`, fundo branco.
- **Nenhuma marca foi gerada por IA** — `splash_screen_white.png` e
  `splash_screen_pattern_band.png` compõem deterministicamente a marca oficial
  (`../marca_isolada_tds.png`) sobre fundo branco, sem tagline (splash).
- Arte gerada é somente elemento ilustrativo de fundo/tela — nunca logotipo,
  texto ou redesenho de símbolo.
- Público-alvo refletido: beneficiários CadÚnico do Tocantins — cerrado, palmeira
  buriti, rio Tocantins, capim dourado, agricultura familiar/agroecologia.

## Proveniência

- Gerado em GPU box dfd627, ComfyUI + `sd_xl_turbo_1.0_fp16` (4 passos, euler,
  cfg 1.5), 1024×1024, exportado JPEG q88.
- Prompts escritos com contexto local; LLM Nemotron local estava indisponível
  (servidor ocupado >15min) na sessão — contexto aplicado manualmente.
- Negative prompt: `text, watermark, logo, signature, blurry, photorealistic,
  complex, cluttered`.

| Arquivo | Uso pretendido |
|---|---|
| `splash_screen_white.png` | Splash: marca centralizada ~44% largura, fundo branco (1080×1920) |
| `splash_screen_pattern_band.png` | Variante splash com faixa inferior do padrão cerrado |
| `pattern_cerrado.jpg` | Textura/borda decorativa (motivos buriti + capim dourado) |
| `loading_hero.jpg` | Ilustração para TDSWaitExperience/loading |
| `error_offline_hero.jpg` | Tela de erro offline/sem sinal |
| `error_generic_hero.jpg` | Tela de erro genérico |
| `empty_courses_hero.jpg` | Estado vazio de cursos/matrícula |

## Limitações

- `marca_isolada_tds.png` (135×120) é o maior raster da marca no repo; o upscale
  para 1080px é determinístico (LANCZOS) — idealmente substituir por export
  oficial de maior resolução quando disponível.
- Fonte Poppins, tipografia e telas textuais ficam a cargo do app (estes assets
  não contêm texto renderizado).