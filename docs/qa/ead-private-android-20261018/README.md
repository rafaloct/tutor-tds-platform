# Tutor TDS / LearnPress: QA Android real com atualização dinâmica

**Cenário:** Issue #241 / PR #242. **Captura:** noite de 17/10/2026 em Palmas (18/10 UTC). **Natureza:** aplicativo QA isolado e curso fictício. **Não é produção nem vídeo de campanha autorizado.**

## Identidade e integridade

- Fonte Git: `b58fffbe43d2b2ab12685749237584a20a543964` do candidato EAD-first com rota de laboratório somente debug.
- APK: `com.tutortds_cartilhas.dev.dynamicqa.r00ad5b420ca34272893828e84024326c`, debug x86_64, build validado no DESKTOP-8T5DRBS. SHA256 `181B743E3249C56A75EEC7FAABD43BBDCFFA5B9CCA4A846B4F918136FA825E47`.
- AVD Android API 35 com WHPX, perfil `tutor_tds_remote_catalog_qa`, tela 1080×1920. O pacote Play `com.tutortds_cartilhas` não foi instalado/alterado.
- Backend: WordPress 6.7.2 / LearnPress 4.3.6 / MySQL 8.0.45 **100% sintéticos** numa rede Docker interna, sem portas publicadas; tráfego ADB reverse → SSH local → contêiner privado.
- Integridade de PNG e MP4 no `evidence_manifest.json`. Vídeos master originais no diretório de evidências privado do desktop; o preview anexado é derivado dos quadros reais via FFmpeg NVENC.

## Resultados de navegação reproduzíveis

| Etapa | Prova | Resultado |
| --- | --- | --- |
| Abertura anônima sem cadastro e tema azul TDS | `02-welcome-ready.png` | PASS |
| Catálogo público WordPress com 11 ofertas, laboratório separado | `03-ead-catalog.png` | PASS |
| Curso sintético SAF id 12, uma seção e dois itens (aula id13 e quiz sintético) | `04-private-saf-path.png` | PASS |
| Aula autor. pública mostra HTML saneado, revisão e YouTube ID aprovado | `05-authorized-lesson.png` | PASS |
| Alterar título/conteúdo da aula no WordPress sintético, refrescar no **mesmo APK** | `06-lesson-updated-without-rebuild.png` | PASS |
| Revogar `mobile_content` no WordPress, refrescar e bloquear texto/vídeo | `07-lesson-revoked-blocked.png` | PASS |
| Restabelecer o opt-in sintético e recuperar aula sem reinstalar APK | `08-lab-restored.png` | PASS |
| Captura real de tela e clipe derivado | `preview-android35-dynamic-ead-1080x1920.mp4` | PASS, observando limites de FPS/áudio |

**Revisão WordPress comprovada:** aula original `Aula QA - Agroecologia`, depois `Aula QA - Agroecologia REVISAO 2 no LearnPress` e texto atualizado, ETag SHA256 alterado. O Flutter exibiu título e conteúdo novos mediante o botão Atualizar, sem recompilar. Ao revogar a permissão, o app passou a mostrar aviso de conteúdo indisponível, sem mostrar dados antigos.

## Limites do vídeo

- Os originais vieram de `adb shell screenrecord` (MP4 H.264, sem áudio do sistema). O arquivo publicado é um corte 1080×1920, H.264 NVENC, 30 fps de saída com eventual duplicação de quadros porque a captura original tem frame rate variável/baixo. **Não apresentar este clipe como material publicitário final sem edição e análise de fluidez.**
- Vídeo YouTube **não foi reproduzido dentro do app**: o botão aparece quando o WordPress permite vídeo, mas seu fluxo atual usa abertura externa. Quizzes, inscrições, tentativas e certificados não foram exercitados neste caso de teste.
- Texto, dados e títulos do curso são sintéticos. Nenhum CPF, gabarito, matrícula ou conteúdo de produção foi registrado no vídeo.

## Design observado no dispositivo

- **PASS:** tema azul institucional, Poppins, cartões visíveis, botão público sem cadastro e navegação de retorno.
- **CORRIGIR:** AppBar `Percurso de aprendizagem` truncado em 1080×1920 com fonte padrão; usar título mais curto com semântica preservada.
- **CORRIGIR:** pluralização `1 seções`, `1 aulas` e `2 item(ns)` no resumo de percurso. Substituir por regras pt-BR de singular/plural.
- **AMPLIAR:** layout para fontes 150%, Android 36 e tela tablet; esse conjunto só comprovou Android 35. AAVD36 falhou anteriormente com ANR do System UI por memória baixa e não foi reensaiado nesta execução.
- **AMPLIAR:** renderizador textual não mostra ainda imagens, HTML complexo/links clicáveis inline/VTT; navegação YouTube externa não equivale a player integrado.

## Segurança, rollback e próximos gates

- No fim do QA, o WordPress sintético teve conteúdo da aula e `mobile_content=1` restaurados ao estado anterior; contêineres de QA continuam em rede Docker interna sem publicar portas.
- Somente o emulador iniciado nesta sessão (`emulator-5554`) e o túnel SSH com bind local `127.0.0.1:18731` foram encerrados. WordPress, Traefik, APIs e Play de produção não foram tocados.
- Módulo de debug só conecta ao QA se `kDebugMode`, package isolado, run id hex e URL loopback exata. O Gradle release impede novas defines QA; manifesto principal continua HTTPS-only.
- Próximos: homologar Android 36 e acessibilidade, corrigir dois problemas de texto, validar player vídeo/legenda e conteúdo de 48 aulas, autenticação federada e execução real de quiz no LMS, Tutor IA com contexto aprovado, gates de assinatura/AAB antes da Play.

**Não foi feito merge, implantação no EAD, atualização na Play Store nem reprodução das 48 videoaulas de produção.**
