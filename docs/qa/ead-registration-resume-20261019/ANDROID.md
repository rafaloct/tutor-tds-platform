# Android independente — smoke, não E2E integrado

2026-10-19, LARGeo, Pixel_8_Pro/emulator-5554, Android15/API35.
APK existente reinstalado com sucesso, sem rebuild ou alteração Flutter:
`D:\AI-Shared\builds\tutor-tds\pr295-b05eaa058fb4b0c86c5569215652b893c55b517d\tutor-tds-pr295-b05eaa0-qa-debug.apk`.
SHA-256 reconfirmado:
`F5BD7623521E7ACC115E68994F55497862DC78BE9525A3BDFD20E789F4C5596A`.
Fonte APK: b05eaa058fb4b0c86c5569215652b893c55b517d; não confundir com HEAD
do novo PR de QA. Package isolado termina em `rb05eaa058fb4b0c86c5569215652b893`.

## Quatro checkpoints PASS

1. Inicialização e entrada pública sem criar conta ou informar dados pessoais.
2. Catálogo: 11 ofertas, preservando ofertas extras além dos nove cursos TDS.
3. Percurso Agricultura Sustentável: 8 seções, 13 itens, 6 aulas em seções de vídeo.
4. Retorno pelo botão Voltar ao catálogo com 11 ofertas.

Interações derivadas de bounds do UIAutomator, não de estimativa em screenshots.
Captura do catálogo inspecionada visualmente. XML do retorno confirma catálogo.

Ocorrências preservadas: Android mostrou ANR de Settings durante boot frio;
selecionado Wait, sem encerrar processo de outro agente. Primeiro carregamento do
catálogo mostrou indisponibilidade; uma tentativa de recuperação carregou11.
Primeiro dump durante transição não gerou XML; segundo dump foi obtido.
Essas ocorrências não foram ocultadas nem classificadas como teste de robustez
integral. Nenhuma falha Flutter foi diagnosticada/alterada nesta rodada.

## Evidências

Diretório local: `D:\AI-Shared\test-results\tutor-tds\issue299-resume-20261019`.
Inclui capturas iniciais, XML de onboarding, erro transitório, catálogo, percurso
e retorno. Cópias selecionadas neste diretório Git:

| Captura | SHA-256 |
|---|---|
| android-catalog.png | `D56B2D69F64C1046687F22400B1DFF0F94BF13D7F0EAA3ABC00037B1E670A723` |
| android-course.png | `B59CB32026BD13EDB2B05720AB211CF49A5E9285924503876A000D1E2BDEA81D` |

## Limites

Sem sessão WordPress/FastAPI ou matrícula neste smoke. Nenhum POST produtivo.
Não clicado o laboratório sintético após STOP da base; nenhum transporte ao VPS
foi aberto. O texto de indisponibilidade interna mostrado no percurso não prova
rejeição editorial: o plugin público continua ausente, conforme auditoria anterior.
Não testar nem aprovar reprodução MP4/VTT com esta evidência. Legendas, áudio,
TalkBack e E2E matrícula→app nesta rodada: UNKNOWN/BLOCKED.

AAB anterior permanece unsigned/NOT_FOR_UPLOAD, hash histórico
`F671CC61BDDEB7CD45D3E7953F98CD4A85F44B1A34B274AE0D6E3FA453776ADC`;
não gerado nem revalidado nesta rodada. Nenhum Xiaomi utilizado.
