# Auditoria de implementação dos mockups - 2026-09-20

## Veredito executivo

Os nove mockups representam corretamente a intenção da especificação visual, mas não são uma referência de pixel perfeito. Após a fotografia inicial desta auditoria, a implementação passou a materializar capabilities por vínculo, Classroom, Monitor por exceção, Evidence, Assessment Sync e re-login; essas superfícies também receberam evidência física seletiva no Xiaomi.

Estimativa consolidada, baseada em inspeção visual dos PNGs, leitura do código atual e comparação com a especificação oficial:

| Dimensão | Aderência estimada | Leitura |
|---|---:|---|
| Intenção conceitual | Não recalculada | A estimativa inicial de 70% ficou obsoleta após Classroom, Monitor, Evidence, sync e re-login; exige nova rodada visual homogênea. |
| Cobertura funcional | Parcial avançada | As lacunas funcionais históricas principais foram implementadas/testadas; faltam Evidence/check-in e certificado físicos, Tutor real e conflito concorrente. |
| Fidelidade visual | Parcial | Há capturas reais em tema escuro e o checkerboard dos parceiros foi corrigido; ainda não há goldens/matriz claro-escuro/fonte/landscape. |

Não foi identificado P0 visual. Os P1 históricos de CPF, toolchain, Monitor, Classroom básico e sync foram corrigidos; permanecem gates físicos/visuais e externos descritos abaixo.

## Fontes e método

Foram inspecionados em resolução original com `view_image` os nove PNGs únicos abaixo. A pasta contém ainda duas cópias byte a byte (`(1) - Copia` e `(4) - Copia`), que não foram contadas como mockups adicionais.

1. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_41_36 (1).png` - Home do aluno.
2. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_41_36 (2).png` - TDS Monitor por exceção.
3. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_41_36 (3).png` - Perfil/Cadastro.
4. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_41_36 (4).png` - TDSWaitExperience.
5. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_43_51.png` - TDS Classroom professor.
6. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_44_04.png` - Tutor IA contextual.
7. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_44_13.png` - Quiz com IA em geração.
8. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_44_23.png` - Simulado com IA.
9. `C:\Users\Usuario\Downloads\ChatGPT Image 20 de set. de 2026, 12_44_31.png` - Cartões de estudo.

Também foram lidas as 34 páginas e renderizadas para conferência visual as páginas 23 e 28 a 31 de `C:\Users\Usuario\Downloads\Cartilhas (Versão Chatbot)\Tutor_TDS_Especificacao_Visual_Manutencao_v1.pdf`. O código comparado inclui tema, widgets compartilhados, telas reais, modelos e testes existentes.

O bloqueio de toolchain desta coleta foi resolvido posteriormente com
`C:\Users\Usuario\flutter-3.44.9` (Dart 3.12.2). A análise ficou limpa e a suíte
final terminou em 163/163. Também foram capturadas telas do APK `.dev` no Xiaomi;
isso ainda não substitui goldens ou a matriz visual completa.

## Precedência de branding

A ordem de autoridade usada nesta auditoria é:

1. especificação visual de manutenção;
2. tokens e assets oficiais já versionados no app;
3. mockups como referência de intenção e hierarquia, não como nova identidade visual.

O tema atual fixa Poppins e as cores `#093AF4` (azul), `#FF341B` (vermelho), `#F6D846` (amarelo) e `#18D010` (verde), além da marca isolada e faixa cromática. O manual oficial TDS v1.0/2026 e o vetor oficial foram localizados e auditados; área de proteção, redução, fundo e usos proibidos estão registrados em `BRAND_COMPLIANCE_AUDIT_2026-09-20.md`.

O defeito de checkerboard foi removido sem recriação por IA: FAPTO/CDR vieram das fontes vetoriais encontradas, IPEX do JPG limpo e todos usam card branco. A build `1.4.0-dev+13` confirmou o resultado no Xiaomi em modo escuro. Resta confirmar institucionalmente a ordem/assinatura conjunta.

## Matriz por mockup

Escala: conceitual mede a aderência à intenção; funcional mede comportamentos realmente disponíveis; visual mede hierarquia e composição, sem penalizar moldura de aparelho ou efeitos irreais.

| Mockup | Intenção | Já implementado | Divergência funcional | Divergência visual | Risco e acessibilidade | Prioridade | Arquivo-alvo | Aderência C/F/V |
|---|---|---|---|---|---|---|---|---:|
| Home do aluno | Jornada antes das ferramentas: próxima ação, próximo passo, semana, pendências e recomendações curtas. | Saudação, retomada de cartilha/avaliação, progresso local, Tutor, estudo, vídeos, certificados e catálogo; professor/monitor recebem entradas diferentes por capability, provadas fisicamente. | Não há semana, pendências remotas ou navegação persistente; a lista de ferramentas/cursos ainda domina. Admin ainda não tem comparação física final. | App bar e cards seguem o tema, mas a composição não corresponde à hierarquia jornada-first nem ao bottom navigation; logos parceiros foram corrigidos e validados no modo escuro. | Cards densos precisam de fonte ampliada/TalkBack; progresso não pode depender apenas de cor. | P1 de QA; P2 visual | `lib/screens/home_screen.dart`, `lib/features/auth/`, assets oficiais | 75/75/50 |
| Monitor por exceção | Ocultar rotina normal e oferecer lista acionável somente para casos que precisam de intervenção. | Superfície dedicada `Monitor por exceção`, escopo por vínculo, estados normal/atenção e painel acionável; login/capability/dashboard foram provados fisicamente na turma sintética. | Falta prova física de outra turma/acesso negado, volume e ciclo completo de resolução/ocorrência. | Hierarquia funcional existe, mas não houve matriz visual claro/escuro/fonte/landscape. | Alertas usam texto e ícone além de cor; TalkBack e foco ainda precisam de teste físico. | P1 de QA, não de ausência | `lib/features/classrooms/`, `docs/testing/ANDROID_PHYSICAL_DEVICE_QA.md` | 80/80/55 |
| Perfil/Cadastro | Consolidar dados pessoais, papel/vínculos, progresso/conquistas e privacidade. | CPF usa armazenamento protegido com migração/remoção da chave legada; Configurações mostra sessão conectada, logout/re-login e preserva progresso local. | Perfil continua fragmentado e ainda não consolida horas, cursos, certificados e atividade recente. | Formulário/configurações não usam todas as seções-resumo do mockup. | Papel é derivado do vínculo e não de seletor local. Ainda testar TalkBack, autofill e fonte ampliada. | P2 funcional; P1 apenas para QA físico restante | `lib/screens/cadunico_screen.dart`, `lib/screens/settings_screen.dart`, `lib/features/auth/` | 70/70/35 |
| TDSWaitExperience | Evitar loading vazio com skeleton da próxima tela, conteúdo local, microatividade opcional e status real. | Componente compartilhado, skeleton estático, dica local, atividade opcional, `Semantics(liveRegion: true)` e ausência de spinner/progresso percentual falso. | Status é uma string única; não há etapas reais, streaming progressivo nem skeleton específico da próxima superfície. | Estrutura é mais simples que o mockup e usa tokens do tema, o que é aceitável. | Skeleton é excluído da árvore semântica e não há animação contínua, portanto reduzir movimento é respeitado na prática. O live region não deve repetir anúncios a cada rebuild. | P2, salvo se etapas forem necessárias ao contrato | `lib/widgets/tds_wait_experience.dart`, `lib/features/study_ai/presentation/study_async_view.dart` | 80/75/55 |
| Classroom professor | Sessão como unidade operacional: presença, QR, compartilhamento, interação, evidências e fechamento humano. | Dashboard por turma, entrada `Presença, QR e evidências`, sessão/QR/check-in, recuperação, exceções e relatório existem; professor/dashboard foram provados fisicamente. | Check-in físico permanece inconclusivo; falta provar rotação/expiração, offline, revisão Evidence completa e certificado. | A tela real usa composição Material própria, não o cockpit exato do mockup; fidelidade final ainda não foi medida. | Ações formais têm backend auditável; faltam TalkBack, fonte ampliada e estados físicos de erro. | P1 de QA/E2E | `lib/features/classrooms/`, `lib/features/evidence/`, `docs/testing/ANDROID_PHYSICAL_DEVICE_QA.md` | 80/75/50 |
| Tutor IA | Tutor contextual, resposta curta em camadas, fonte e ações de estudo; composer multimodal sob demanda. | Contexto no cabeçalho, três atalhos iniciais, bolhas, resposta direta + detalhe expansível, ouvir, cartões, quiz, continuar, follow-ups, feedback e microfone sob demanda. | Faltam revisar erros, continuar módulo como card, anexar documento/foto/câmera, vídeo relacionado e proveniência real. O card declara quando a fonte específica não veio do serviço, em vez de inventá-la - comportamento seguro. | Boa hierarquia Material, mas sem o seletor de curso, cards iniciais e composer multimodal do mockup. | Chips pequenos do mockup podem quebrar em fonte grande. Permissões devem continuar sob demanda. Botões de mídia precisam de rótulos/tooltip e preview antes de envio. | P1 proveniência/multimodal; P2 visual | `lib/screens/genui_assistant_screen.dart`, `lib/widgets/tutor_response_card.dart`, `lib/widgets/tutor_conversation_starter.dart` | 80/70/50 |
| Quiz em geração | Exibir skeleton de pergunta/alternativas, curiosidade local e etapas reais, sem progresso falso. | Quiz usa `StudyAsyncView` + `TdsWaitExperience`, sem spinner e com dica local; fonte, quantidade e dificuldade são escolhidas antes da chamada. | Skeleton é genérico e o status não evolui por etapa. Não há streaming do primeiro resultado. | Não reproduz a silhueta da questão e stepper do mockup. O composer de chat mostrado no mockup não pertence a esta tela e não deve ser copiado. | Stepper só por cor seria inadequado. Anunciar uma etapa real por mudança, sem inundar leitor de tela. | P2 | `lib/features/study_ai/presentation/study_async_view.dart`, `lib/widgets/tds_wait_experience.dart`, `lib/features/study_ai/presentation/assessment_screen.dart` | 75/65/50 |
| Simulado | Barra de prova, tempo, questão atual, autosave/offline, navegador, revisão e entrega protegida. | Cronômetro, progresso, autosave, fila/sync, estados 403/409, retomada cross-device sem nova IA, deck/progresso hidratados e estado `Sincronizado` foram implementados; o caso 1/1 e a jornada offline/morte/reconexão foram provados no Xiaomi. | Faltam conflito concorrente e tentativa concluída físicos; critério/preset do professor não foi provado. | Elementos existem, mas ainda não houve goldens nem sweep de fonte/landscape. | Cronômetro não deve ser anunciado a cada segundo; validar navegador e status com TalkBack/fonte 200%. | P1 de QA concorrente; P2 composição | `lib/features/study_ai/presentation/assessment_screen.dart`, serviço/fila de sync | 90/92/65 |
| Cartões de estudo | Sessão contextual com progresso, toque/frente-verso, áudio, autoavaliação e origem. | Fonte/quantidade/dificuldade, progresso, frente-verso por toque, transição curta, TTS, quatro níveis de lembrança, totais e origem textual. | Origem não abre o trecho original; avaliações não evidenciam agenda persistente de repetição espaçada; falta estimativa de tempo. | É a tela mais próxima do mockup, porém sem seletor compacto de curso e com controles de geração ocupando o topo. | Semântica identifica frente/verso, mas deve incluir ação/hint e mudança de estado. Movimento curto precisa obedecer configuração de animações reduzidas. | P2 | `lib/features/study_ai/presentation/flashcards_screen.dart`, `lib/features/study_ai/presentation/flashcard_review_status.dart`, persistência de revisão | 85/80/65 |

## Achados confirmados por prioridade

### P0

Nenhum achado visual P0. Não houve teste contra produção, publicação, instalação no pacote Play ou alteração do app nesta auditoria.

### P1

1. **Tutor real não provado.** A UI não inventa fonte, porém o gateway de staging está desligado; proveniência, ações e latência continuam sem E2E.
2. **Evidence/check-in físico inconclusivo.** Classroom/Evidence existem, mas o token não produziu resultado observável confiável na rodada física; repetir sem atribuir falha ao backend.
3. **Acessibilidade/layout sem matriz física.** Faltam TalkBack, fonte 200%, claro/escuro, landscape e teclado nas superfícies críticas.

Encerrados desde a fotografia inicial: capability de professor/monitor, Monitor
por exceção, Classroom/Evidence básico, CPF em armazenamento protegido,
Assessment Sync, re-login e toolchain Flutter reproduzível.

### P2

- Criar um shell de navegação consistente e adaptativo, sem copiar cegamente o bottom bar gerado.
- Unificar cards, espaçamentos, raios, estados e semântica em componentes compartilhados.
- Fazer o skeleton refletir pergunta/alternativas e expor etapas apenas quando vierem de estados reais.
- Reunir cronômetro, questão, sync e finalizar em uma barra de prova responsiva.
- Tornar origem de flashcard/quiz acionável e adicionar hint semântico ao gesto de revelar.
- Testar light/dark, contraste, fonte 1.0/1.3/2.0, 360 x 800 e 412 x 915 antes de qualquer “polimento”.

## O que é replicável e o que é estética de IA

### Replicável sem substituir o branding

- hierarquia jornada-first;
- cards de próxima ação, pendência e recomendação curta;
- cabeçalho contextual e barras operacionais;
- agrupamento de ações por intenção;
- skeleton com forma da próxima tela;
- texto redundante para estados, além de cor;
- espaçamento generoso e áreas de toque mínimas de 48 dp;
- lista por exceção e ações contextuais;
- navegação principal por papel/capability, adaptada a telefone e tablet.

### Não copiar

- moldura física do aparelho, ilha dinâmica/furo de câmera e barras de status desenhadas dentro do app;
- mistura inconsistente de chrome iOS com Material/Android;
- blur, glow, vidro e sombras excessivos;
- logos ou cores reinterpretados pela IA;
- dados fictícios como percentuais, presenças, horários e status de sync sem fonte real;
- CPF completo e seletor de papel que pareça conceder privilégio;
- stepper/progresso calculado sem etapas reais;
- composer de chat em telas de quiz/flashcard quando não houver conversa;
- textos e chips pequenos que só funcionam na imagem estática e quebram com acessibilidade.

## Plano de ajustes sem redesenho total

1. **Fechar os E2E restantes.** Evidence/check-in, conflito concorrente, certificado e Tutor/proveniência, sem reabrir contratos já implementados.
2. **Congelar os assets auditados.** Reusar `AppTheme`, não trocar paleta/fonte/marca e aguardar somente a confirmação institucional da assinatura conjunta.
3. **Evoluir componentes compartilhados apenas onde o QA apontar falha.** Priorizar semântica, responsividade e estados honestos, não redesenho amplo.
4. **Aplicar fidelidade visual seletiva.** Adotar hierarquia, densidade e estados dos mockups; rejeitar moldura, status bar, glow e dados simulados.
5. **Gerar evidência visual reproduzível.** O ambiente já está fixado; faltam goldens e matriz de tela/fonte/tema.
6. **Completar no dispositivo de desenvolvimento.** O APK `.dev` já está validado contra staging; executar somente os casos físicos restantes, sem tocar o pacote Play.

## Evidência de QA atualizada

- SDK fixado: Flutter 3.44.9 / Dart 3.12.2.
- Análise Dart com `--fatal-infos`: zero achados.
- Suíte Flutter final: **163/163 testes aprovados**.
- Cobertura crítica: certificados 88,01%, Study IA 83,43% e sync/outbox
  88,62%; cobertura total 68,24%.
- APK físico: `com.tutortds_cartilhas.dev` `1.4.0-dev+13`; package Play
  `1.2.0+11` preservado.
- Capturas de Home/cache, offline/morte/reconexão, mídia, Assessment Sync,
  logout/re-login, professor, monitor e branding corrigido em
  `docs/testing/evidence/2026-09-20`.

Essa evidência corrige a limitação histórica de toolchain e as afirmações de
ausência das superfícies implementadas. Ela não aprova goldens, a assinatura
institucional conjunta,
TalkBack, Evidence/check-in, certificado, Tutor real ou performance.
