# Guia de Distribuição — App Cartilhas TDS

## 1. Hospedar o APK no Google Drive

1. Acesse drive.google.com com tdsdados@gmail.com
2. Crie uma pasta chamada **"TDS App"**
3. Faça upload do arquivo:
   `cartilhas_app/build/app/outputs/flutter-apk/app-release.apk`
4. Clique com botão direito no arquivo > **"Compartilhar"**
5. Em "Acesso geral", selecione **"Qualquer pessoa com o link"**
6. Copie o link

> ⚠️ O link do Google Drive para download direto precisa ser convertido.
> Troque o link de compartilhamento:
> `https://drive.google.com/file/d/ID_DO_ARQUIVO/view`
> Por:
> `https://drive.google.com/uc?export=download&id=ID_DO_ARQUIVO`

---

## 2. Gerar o QR Code

1. Acesse **qr.io** ou **qrcode-monkey.com** (gratuito)
2. Cole o link direto de download do APK
3. Escolha cor verde (#2E7D32) para combinar com o visual do TDS
4. Baixe em PNG (tamanho mínimo: 300x300px para impressão)

---

## 3. Guia de Instalação para o Aluno

Imprima ou envie via WhatsApp junto com o QR Code:

---

### Como instalar o App Cartilhas TDS no seu celular

**Passo 1 — Liberar instalação**
- Abra **Configurações** no seu celular
- Vá em **Segurança** (ou **Privacidade**)
- Ative **"Instalar apps desconhecidos"** ou **"Fontes desconhecidas"**
  - Em Xiaomi/Redmi: Configurações > Senhas e segurança > Privacidade > Instalar apps desconhecidos

**Passo 2 — Baixar o app**
- Aponte a câmera para o QR Code abaixo
- Ou abra o link no navegador do celular

**Passo 3 — Instalar**
- Toque no arquivo baixado (geralmente aparece na barra de notificações)
- Toque em **"Instalar"**
- Aguarde terminar

**Passo 4 — Abrir e se cadastrar**
- Abra o app **Cartilhas TDS**
- Preencha seu Nome, WhatsApp e CPF
- Pronto! Escolha sua trilha e comece a aprender

---

## 4. Distribuição por WhatsApp

Para turmas via WhatsApp, envie esta mensagem:

```
Olá! Segue o link para baixar o App Cartilhas TDS no seu celular 📲

🔗 [COLE O LINK AQUI]

Se precisar de ajuda para instalar, chame no suporte:
wa.me/5563993010823
```

---

## 5. Dashboard de Analytics (Looker Studio)

1. Acesse **lookerstudio.google.com** com tdsdados@gmail.com
2. Clique em **"Criar"** > **"Relatório"**
3. Conecte ao **Google Sheets** — selecione a planilha TDS Analytics
4. Gráficos sugeridos:
   - **Scorecard**: total de alunos cadastrados (conta linhas da aba Alunos)
   - **Gráfico de barras**: trilhas mais concluídas (conta COMPLETED por Detalhe)
   - **Linha do tempo**: novos cadastros por semana (REGISTERED por data)
   - **Tabela**: lista de alunos com último acesso

---

## 6. Atualizar o APK futuramente

Quando o app for atualizado:
1. Gere um novo APK: `cd cartilhas_app && flutter build apk --release`
2. No Google Drive, clique com botão direito no APK antigo > **"Gerenciar versões"** > **"Fazer upload de nova versão"**
3. O link permanece o mesmo — nenhuma alteração necessária no QR Code
