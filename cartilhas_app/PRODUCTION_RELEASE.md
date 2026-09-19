# Tutor TDS — preparação da versão 1.2.0+11

Esta atualização mantém o fluxo pedagógico já testado e prepara o aplicativo
`com.tutortds_cartilhas` para uma nova versão na Play Store.

## Requisitos validados

- Flutter 3.44.9 e Dart 3.12.2.
- Android `compileSdk` e `targetSdk` 36; `minSdk` 24.
- Android Gradle Plugin 9.0.1, Gradle 9.1.0 e NDK 28.2.13676358.
- App Bundle configurado com alinhamento de bibliotecas nativas de 16 KB.
- Versão `1.2.0` e código `11`.
- Build `release` sem fallback para chave de depuração.

## 1. Publicar e configurar o gateway

Siga [cloudflare/tutor-tds-gateway/README.md](cloudflare/tutor-tds-gateway/README.md).
O AnythingLLM e o modelo continuam no VPS/Dokploy; a Cloudflare é apenas o
gateway público e guarda a credencial de servidor.

Copie `config/production.example.json` para `config/production.json` e informe
a URL HTTPS criada pela Cloudflare. O arquivo real está ignorado pelo Git.

O aplicativo não lê mais `ANYTHING_LLM_API_KEY`, `OPENAI_API_KEY` ou outra
chave de modelo. Antes de cada build de produção, execute:

```powershell
dart run tool/validate_production_config.dart config/production.json
```

Esse comando bloqueia configurações com chaves conhecidas e exige uma URL HTTPS
para o gateway. Sem gateway configurado ou se ele estiver indisponível, as
cartilhas continuam funcionando e o Tutor mostra uma mensagem amigável.

### Central Estudar com IA

A atualização adiciona uma central Material 3 sem substituir as telas já
testadas. O estudante escolhe uma das cartilhas incluídas no aplicativo e pode
usar:

- Chat com IA contextualizado;
- cartões de estudo com revisão dos itens difíceis;
- quiz com correção e explicação imediatas;
- resumo rápido ou detalhado, com cópia local;
- simulado com cronômetro, nota e temas para revisar.

Nesta versão não existe upload de arquivos. O app envia ao gateway apenas o
título da cartilha selecionada e os parâmetros do material (tipo, dificuldade,
quantidade ou tamanho). Chaves, prompts internos, modelo e workspace não ficam
no AAB.

### Carteira de certificados verificáveis

- A emissão ocorre somente após todas as perguntas da cartilha serem respondidas.
- O Worker valida a cartilha em uma lista fechada, emite ID, SHA-256 e assinatura
  HMAC, e guarda o registro público no KV `CERTIFICATES`.
- O CPF trafega somente na emissão, por HTTPS, e é convertido em HMAC para evitar
  duplicidade. O número não é salvo no KV, no PDF, no QR Code ou na página pública.
- O app recalcula o hash antes de aceitar o registro, gera o PDF A4 paisagem e o
  guarda na área privada do aplicativo.
- A carteira acumula certificados e permite seleção múltipla para imprimir,
  exportar, compartilhar ou enviar por e-mail pelo seletor nativo do Android.
- Cada QR Code abre `/verify/ID`; a API pública `/v1/certificates/ID` recompõe o
  hash e verifica a assinatura antes de declarar o registro válido.

O registro prova que o certificado foi emitido e não adulterado. Nesta versão,
a conclusão ainda é informada pelo cliente Flutter; ela não substitui uma
certificação acadêmica oficial nem uma validação remota de avaliação. Play
Integrity e progresso assinado no servidor continuam como reforços posteriores.

## 2. Configurar assinatura

A nova chave de upload já foi criada, protegida e copiada para o backup local.
Antes de gerar o AAB final, a redefinição do certificado de upload precisa estar
aprovada na Play Console. Envie apenas `android/upload_certificate.pem` no fluxo
**Solicitar redefinição da chave de upload**; nunca envie o `.jks`, as senhas ou
`key.properties`.

O Gradle não assina `release` com chave de debug quando `key.properties` está
ausente. Isso impede uma publicação incorreta.

## 3. Validar e gerar o AAB

No Windows, o Flutter/Android pode falhar quando o caminho do projeto tem
acentos. Faça o build a partir de uma cópia com caminho ASCII, por exemplo
`D:\cartilhas_release\cartilhas_app`.

```powershell
dart run tool/validate_production_config.dart config/production.json
flutter clean
flutter pub get
dart analyze
flutter test test
flutter build appbundle --release --dart-define-from-file=config/production.json
```

O arquivo final fica em `build/app/outputs/bundle/release/app-release.aab`.

Antes do upload, confirme:

- pacote `com.tutortds_cartilhas`;
- versão `1.2.0` e código maior que o último da Play;
- `targetSdkVersion 36`;
- assinatura com a nova chave de upload aprovada;
- `TUTOR_GATEWAY_URL` apontando para o Worker já testado;
- Tutor, webhook, suporte, voz, PDFs e emissão/carteira de certificados em teste
  interno.

## 4. Play Console e privacidade

Publique uma Política de Privacidade em URL HTTPS e mantenha a declaração de
Segurança dos dados coerente com o app. Revise pelo menos:

- nome, telefone e CPF;
- progresso nas cartilhas;
- perguntas enviadas ao Tutor de IA;
- tema da cartilha e materiais de estudo gerados pela IA;
- suporte via Chatwoot/WhatsApp;
- microfone opcional para transcrição, sem retenção de áudio pelo app;
- criptografia em trânsito e procedimento de exclusão/correção de dados.

Na declaração de certificados, detalhe que nome, cartilha, data, ID e hash ficam
públicos por escolha do usuário no momento da emissão; CPF e WhatsApp não ficam
no registro público. A desinstalação remove a carteira local, mas não o registro
de validação no servidor.

Atualize também descrição, notas da versão, classificação indicativa, contato
de suporte e capturas reais das telas.

## Escopo propositalmente adiado

- Tradução completa, pois o conteúdo ainda está validado em Português (Brasil).
- Mudança estrutural de navegação ou identidade visual, para preservar o fluxo
  aprovado pelos testers.
- Migração antecipada para Built-in Kotlin, enquanto plugins ainda dependem do
  Kotlin Gradle Plugin.
- Integração da Play Integrity, prevista como reforço posterior ao gateway e ao
  rate limiting, sem bloquear esta atualização conservadora.
