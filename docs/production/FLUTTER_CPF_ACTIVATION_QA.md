# Roteiro de homologação: ativação de CPF no aplicativo

Escopo: cadastro online do app Tutor TDS com API de staging que exige convite.
Não registrar CPF, senha ou código no roteiro executado, em capturas ou em
analytics.

1. Com uma conta `admin` de staging, emitir `POST /auth/activation-invites`
   para um CPF sintético válido de teste e entregar o código por canal
   verificado.
2. No app, preencher o cadastro local e escolher **Criar conta**. Informar o
   código somente no campo **Código de ativação fornecido pela instituição**,
   a senha e a confirmação.
3. Confirmar que o cadastro chega a `POST /auth/register` com
   `activation_token`, recebe `201` e segue para o fluxo normal de
   consentimento/onboarding.
4. Encerrar a sessão, entrar com CPF e senha da conta recém-ativada e confirmar
   que o login continua usando somente `POST /auth/login` — sem pedir nem
   reenviar o código.
5. Em uma conta de teste separada, tentar código usado, expirado e emitido para
   outro CPF. Em todos os casos, confirmar erro genérico de validação, sem
   exibir o código, CPF de terceiros ou a resposta remota.
6. Verificar armazenamento do dispositivo: somente tokens de sessão podem
   estar no armazenamento seguro; o código de ativação não pode aparecer em
   preferências, cache, logs ou telemetria.

Critério de aceite: os passos 1–4 são aprovados em aparelho físico no staging;
o passo 5 não vaza dado sensível; e o passo 6 é inspecionado antes de avançar
para o isolamento entre contas (#80), que permanece fora deste escopo.

Nota: o SDK Flutter não está disponível no ambiente cloud; os testes focais
(`test/auth_repository_test.dart`, `test/welcome_account_test.dart`) dependem
dos checks autoritativos de CI.
