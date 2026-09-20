# Tutor TDS - intervenções externas e autenticações

Este documento separa o que pode ser automatizado do que exige uma pessoa
autorizada. Senhas, tokens e JSON de service account não devem ser enviados em
mensagens nem versionados.

## 1. Branding

Manual TDS, vetor oficial e fontes FAPTO/CDR foram localizados; o defeito visual
dos logos foi corrigido e validado no Xiaomi em modo escuro. Resta intervenção
institucional para:

- confirmar a ordem e o papel das marcas parceiras na tela Sobre/Home;
- fornecer um vetor IPEX, caso exista, para substituir futuramente o JPG limpo.

## 2. Google Sheets - staging

Necessário para fechar o gate da Onda 1:

1. criar uma planilha exclusiva de staging;
2. criar/selecionar uma service account no projeto Google autorizado;
3. compartilhar somente a planilha de staging com o e-mail da service account;
4. instalar `GOOGLE_SERVICE_ACCOUNT_JSON` diretamente no secret/env do
   Dokploy, nunca no repositório;
5. informar ao processo de deploy somente o `GOOGLE_SHEET_ID` e o nome da aba;
6. executar evento, retry, deduplicação e reconciliação antes de configurar a
   planilha de produção.

## 3. Dokploy/VPS - staging (implantação inicial concluída)

Em 20/09/2026 foram autorizados e concluídos: diretório/banco isolados, rota
HTTPS, migrations, seed sintético e smokes público/autenticado. Sheets segue
desligado e produção permaneceu saudável.

Uma nova confirmação de janela continua necessária antes de:

- executar o teste de restauração em base vazia;
- alterar firewall, usuário root ou serviços compartilhados.

O staging não reutiliza banco, JWT, pepper, planilha nem credenciais de
produção.

## 4. Drive, YouTube e vídeo

Necessário antes de publicar o primeiro vídeo:

- Shared Drive/pasta institucional e responsáveis;
- canal YouTube institucional, se o piloto usar vídeos não listados;
- confirmação de direitos autorais, voz e imagem;
- política de retenção de masters, legendas e evidências;
- decisão sobre Cloudflare Stream/R2 quando houver conteúdo restrito ou escala.

Ativar Stream/R2 pode gerar cobrança e sempre exige autorização explícita.

## 5. Creator e comercial

Necessário antes de sair do modo simulado:

- modelo de negócio e regra de remuneração;
- termos do creator e aprovação jurídica/tributária;
- provedor de pagamento e conta comercial verificada;
- sandbox, webhooks, conciliação e aprovadores;
- autorização explícita para a primeira transação real.

Até esse gate, `RevenueLedger` permanece `simulated` e o adapter de pagamento
permanece `disabled`.

## 6. Google Play

Somente após freeze e piloto:

- revisão da ficha Segurança dos dados;
- confirmação das URLs de privacidade e exclusão;
- upload no teste interno;
- aceite de avisos/declarações da Play Console;
- promoção gradual para produção.

Nenhuma promoção para produção deve ser feita automaticamente.

## 7. Xiaomi - concluído para o APK `.dev`

A confirmação “Instalar via USB” foi fornecida. O upgrade para
`com.tutortds_cartilhas.dev` `1.4.0-dev+13` preservou sessão/progresso, e o
package Play permaneceu intacto em `1.2.0+11`. Novas intervenções locais só são
necessárias para os casos físicos ainda abertos ou para instalar o candidato pela
trilha interna da Play.
