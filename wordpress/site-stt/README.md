# Tutor TDS | STT acessível do site, não dos vídeos

Este componente é um **candidato independente**, não um deploy nem uma extensão instalada automaticamente. É um plugin WordPress comum, opt-in, com `tds-site-stt.php` e arquivos JS/CSS estáticos. Não toca LearnPress, FastAPI, Chatwoot, vídeos, certificados, matrículas ou RAG.

## Para o participante

Quando **ativado**, oferece botão de microfone nos campos públicos `input[type=search]`, `input[name=s]` e `textarea[name=mensagem]`. O navegador reconhece fala em **pt-BR** e insere somente o texto final no campo, sempre sujeito a revisão da pessoa. Nunca envia o formulário sozinho.

- Prioriza `SpeechRecognition.processLocally = true` **se** o navegador oferecer reconhecimento no dispositivo e o idioma estiver disponível.
- Caso o idioma exija instalação, oferece a opção explícita de instalar pacote local.
- Se só houver processamento pelo serviço do navegador, apresenta aviso sobre envio potencial de voz ao provedor **e exige consentimento separado** antes de ouvir.
- Sem suporte de reconhecimento de fala, sem microfone autorizado, sem conexão ou com erro, a digitação normal permanece disponível.
- Áudio não é enviado, armazenado ou transcrito em servidores do WordPress/Tutor TDS por este plugin. **Em modo não local, o navegador pode processar a voz em serviços externos**. Não há garantia de que funciona offline em todos os navegadores.

Não é TTS (leitura em voz alta), não transcreve vídeo e não monitora o microfone automaticamente.

## QA reprodutível e implantação segura

Rodar `cd tests && npm ci && npm test` (Node 20+), `node --check ../assets/site-stt.js` e `php -l ../tds-site-stt.php`. Opcionalmente usar navegador real para conferir permissão, navegação por teclado, rotulagem acessível, layout mobile e tratamento de rede.

Empacotar somente `tds-site-stt.php`, `assets/site-stt.js` e `assets/site-stt.css` dentro de uma pasta `tds-site-stt/` e validar em WordPress de QA. Exigir backup e decisão humana **antes de instalar/ativar** no site público; não copiar arquivos diretamente para `mu-plugins` porque isso faria ativação automática, contrariando o gate.

O plugin não requer Devin, Nemotron, GPU alugada, modelos locais persistentes no VPS, tokens de API, Worker, WP REST ou qualquer endpoint de inferência. Apenas WordPress para servir JS/CSS e recursos opcionais do navegador.

## GPU para auditoria do STT, não runtime

O script `scripts/offline_whisper_canary.py` testa gravações **criadas para ditado do site**, nunca conteúdo de vídeos. Ele executa `faster-whisper` em dispositivo CUDA somente quando houver memória livre suficiente ou em CPU explicitamente. Requer um WAV e sua frase de referência; produz transcrição e taxa de erro em palavras, sem nenhum upload. Um `--allow-model-download` explícito é necessário quando o modelo ainda não estiver no cache; depois é reproduzível offline. Esse modelo é apenas uma ferramenta de verificação, não é chamado pela interface WordPress.

Exemplo: `python scripts/offline_whisper_canary.py --audio canary_ptbr.wav --reference "Quero buscar cursos de agricultura familiar e cooperativismo no Tocantins." --out report.json --allow-model-download`.

## Restrições / HUMAN_GATE

- Não instalar em produção antes de teste funcional **em navegador real** com HTTPS.
- Não armazenar gravações de usuários, não adicionar endpoint no servidor, não ativar REST de áudio sem revisão de privacidade/LGPD.
- O modo local (`processLocally`) é experimental e varia entre versões/navegadores. A existência da API não comprova suporte no Android WebView.
- O STT depende da opção escolhida pelo participante; não garante reconhecimento se o navegador não oferece o recurso.
- Implementar atualização em PR específico; sem auto-merge nem force push, sem disputar com o agente de vídeos.

Referências: https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition ; https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition/processLocally
