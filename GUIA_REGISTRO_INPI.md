# Guia de Registro de Software — INPI
## Cartilhas TDS App · Versão 1.0.0

---

## O que é o Registro de Programa de Computador?

O registro no **INPI (Instituto Nacional da Propriedade Industrial)** é o mecanismo oficial brasileiro para proteger a autoria de um software. Ele não impede cópias, mas:

- Cria **prova legal de autoria** com data certa
- Permite **ação judicial** em caso de plágio ou uso indevido
- É **requisito** para alguns editais públicos e contratos governamentais
- Tem validade de **70 anos** a partir da publicação (Lei 9.609/98)

---

## Documentos Necessários

Separe os seguintes itens antes de iniciar:

### Obrigatórios
- [ ] **Código-fonte** (primeiras e últimas 70 páginas ou parte representativa)
- [ ] **Descrição funcional** do programa (o que faz, como funciona)
- [ ] **CNPJ** do IPEX (pessoa jurídica titular)
- [ ] **Procuração** se for representante (não obrigatório para o próprio titular)

### Para este software especificamente
- [ ] `CERTIFICADO_AUTORIA.txt` (já gerado nesta pasta)
- [ ] `CartilhasTDS_v1.0.0_2026-06-01.apk` (executável)
- [ ] Capturas de tela do aplicativo em funcionamento (mínimo 5)

---

## Passo a Passo do Registro

### 1. Acesse o portal do INPI
**URL:** https://www.gov.br/inpi/pt-br/servicos/programas-de-computador

Clique em **"Registrar Programa de Computador"** → você será redirecionado ao sistema **e-Processos**.

### 2. Crie ou acesse sua conta gov.br
- Use o CNPJ do IPEX para criar conta como pessoa jurídica
- Nível mínimo de conta: **Prata** (verificação por banco ou internet banking)

### 3. Preencha o formulário GRU (Guia de Recolhimento)
- Serviço: **Registro de Programa de Computador**
- Código: **199** (para pessoa jurídica)
- Taxa aproximada: **R$ 40,00** (pessoa jurídica, 2026)
- Pague via PIX ou boleto bancário e guarde o comprovante

### 4. Inicie o pedido no e-Processos
Preencha os campos:
```
Título do programa   : Cartilhas TDS — Tutor Digital do Programa TDS
Versão               : 1.0.0
Data de conclusão    : 2026-06-01
Linguagem            : Dart/Flutter
Tipo de programa     : Aplicativo Mobile (Android)
Finalidade           : Educacional / Inclusão produtiva
Titular              : IPEX — Instituto de Pesquisa e Extensão...
CNPJ titular         : [CNPJ do IPEX]
Autores (pessoas)    : Rafael [Sobrenome] + equipe de desenvolvimento
```

### 5. Anexe o código-fonte
O INPI aceita:
- **Primeiras 70 páginas** + **últimas 70 páginas** do código-fonte
- OU arquivo compactado (ZIP) com todo o código

**Como gerar o arquivo de código-fonte para o INPI:**
```bash
cd "/home/rafael/Documents/Cartilhas (Versão Chatbot)/cartilhas_app"
zip -r CartilhasTDS_codigo_fonte_v1.0.0.zip lib/ assets/ pubspec.yaml \
    android/app/src/main/AndroidManifest.xml google_apps_script.js
```

### 6. Preencha a Descrição Funcional
Cole o texto abaixo (já formatado para o INPI):

---

**DESCRIÇÃO FUNCIONAL — para submissão ao INPI**

> **Cartilhas TDS** é um aplicativo móvel para Android desenvolvido em Flutter/Dart, destinado à formação educacional de jovens e adultos em situação de vulnerabilidade social no Tocantins, no âmbito do Programa TDS — Territórios de Desenvolvimento Social e Inclusão Produtiva.
>
> O sistema implementa o protocolo ATUI (Agentic UI) proprietário, no qual um Modelo de Linguagem de Grande Escala (LLM), operado via servidor AnythingLLM com geração aumentada por recuperação (RAG), não apenas gera respostas textuais, mas também determina e renderiza componentes de interface do usuário em tempo real.
>
> **Funcionalidades principais:**
> 1. Apresentação interativa das 9 cartilhas pedagógicas do Programa TDS em formato conversacional, com questões de verificação de aprendizagem;
> 2. Tutor de IA baseado em RAG, treinado exclusivamente sobre o conteúdo das cartilhas, com modo adaptativo ("Minha Realidade") que personaliza respostas à situação do usuário;
> 3. Glossário digital com 130+ termos oficiais das cartilhas, com busca e aprofundamento via IA;
> 4. Sistema de certificado digital de conclusão, com notificação automática por e-mail ao administrador;
> 5. Analytics de funil (cadastro → início → conclusão) integrado ao Google Sheets via webhooks;
> 6. Suporte humano via chat integrado (Chatwoot) e WhatsApp;
> 7. Acessibilidade total: síntese de voz (TTS) e reconhecimento de fala (STT);
> 8. Download das cartilhas em PDF via Google Drive.

---

### 7. Envie e aguarde
- Prazo médio de análise: **60 a 90 dias**
- Você receberá um **número de processo** imediatamente após o protocolo
- Esse número já serve como **comprovante provisório de autoria** desde a data do protocolo

---

## Alternativa: Registro em Cartório

Para proteção **imediata e mais barata**, antes de finalizar o INPI:

1. Imprima o `CERTIFICADO_AUTORIA.txt`
2. Leve a um **cartório de notas** com o pendrive contendo o APK
3. Solicite **ata notarial** de conteúdo digital
4. Custo: ~R$ 50–120 dependendo do cartório
5. A ata notarial cria prova de existência do conteúdo naquela data

---

## Registro em Plataformas Internacionais (opcional)

### Copyright.gov (EUA)
- Protege a obra nos países da Convenção de Berna (180+ países)
- Taxa: US$ 65 (pessoa jurídica)
- URL: https://www.copyright.gov/registration/

### Creative Commons (para o conteúdo pedagógico)
As cartilhas impressas já têm licença CC BY-NC. O aplicativo pode adotar:
- **CC BY-NC-SA 4.0**: permite uso não-comercial com atribuição e mesma licença
- URL: https://creativecommons.org/licenses/by-nc-sa/4.0/deed.pt-br

---

## Hash para Comprovação de Autoria

Guarde estes valores junto ao `CERTIFICADO_AUTORIA.txt`. Eles provam que o software existia nesta forma nesta data:

```
Arquivo  : CartilhasTDS_v1.0.0_2026-06-01.apk
Data     : 2026-06-01 10:42:46 -0300
SHA-256  : 494858768ff37984168e8cfb9a2745dc3ee250c859f7aa9eb6b73593be49954d
SHA-1    : 97bfd726b7b90af2e1672ec68cb5b0777bd18d73
MD5      : ddffaf8c93fc2e3ac60e1ea41fd85754

Código-fonte (hash agregado SHA-256):
59a0d622e79923997a3482c262d22a4794f65e415d7819e1bf15d665afa9f851
```

**Como verificar:**
```bash
# Linux/Mac
sha256sum CartilhasTDS_v1.0.0_2026-06-01.apk

# Windows (PowerShell)
Get-FileHash CartilhasTDS_v1.0.0_2026-06-01.apk -Algorithm SHA256
```

---

## Contatos Úteis

| Órgão | Contato |
|---|---|
| INPI — Registro de Software | https://www.gov.br/inpi |
| INPI — Atendimento | 0800 707 4674 |
| IPEX (titular) | ead.ipexdesenvolvimento.cloud |
| E-mail do projeto | tdsdados@gmail.com |
