# Tutor TDS — cadastro público, convite institucional e gestão do código

Atualizado em 21/10/2026. Escopo: autenticação da **API Tutor TDS**, separada do WordPress/LearnPress e do código de check-in das turmas.

## Diagnóstico observado

- O Flutter na tag `v1.4.1` e na fonte integrada até #321 obrigava o campo **Código de ativação fornecido pela instituição** em **Criar conta**, mesmo sem exigência do servidor.
- A API lê `CPF_ACTIVATION_REQUIRED` com padrão **`false`**. Consultas **somente leitura** no contêiner de produção `tutor-tds-api-api-1` e no staging `tutor-tds-staging-api-staging-1` encontraram essa variável **não definida**; portanto, segundo o código da configuração, o cadastro comum não exige convite em ambos. Essa observação não altera uma eventual decisão futura de exigir convites.
- A documentação Swagger de produção responde `GET https://ead.ipexdesenvolvimento.cloud/tutor-api/docs` HTTP 200 e o OpenAPI publica os contratos `POST /auth/register`, `POST /auth/login` e `POST /auth/activation-invites`.
- **Login existente não usa convite**: usa CPF + senha. A aplicação exibiu o código na criação da conta, não no login.
- A API `POST /auth/register` sempre cria o papel global `student`; não concede automaticamente vaga, matrícula, presença, nota ou certificado.
- O botão **Explorar cursos do EAD sem cadastro** permanece independente desses fluxos.

## Correção proposta nesta branch

- Código de ativação passa a ser **opcional no formulário**.
- `AuthRepository.register` **omite completamente** `activation_token` quando o campo está vazio ou contém só espaços; quando preenchido, envia o valor apenas na requisição HTTPS, como antes.
- A autorização permanece **exclusivamente no servidor**: se um dia `CPF_ACTIVATION_REQUIRED=true`, registro sem convite válido retorna HTTP 403. Nenhuma mudança em `api/app/auth.py` ou em configuração/deploy de produção.
- O código de convidado não fica armazenado nos tokens de sessão, nos arquivos locais ou nos logs do aplicativo.
- O campo CPF continua necessário à criação da conta online; isso **não** impede acesso ao catálogo público sem conta.

## Como emitir um convite institucional hoje (somente administradores da API)

A emissão já existe, mas **não há um painel de convites implementado no Flutter/WordPress para essa API**.

1. Entre na documentação da API: `https://ead.ipexdesenvolvimento.cloud/tutor-api/docs`.
2. Uma conta com papel global `admin` na **API Tutor TDS** autentica por `POST /auth/login`, usando seu próprio CPF e senha. Não confunda com o usuário WordPress `tds_admin`, cuja permissão não concede automaticamente acesso à API.
3. Com o token **access** da sessão admin, faça `POST /auth/activation-invites` e defina, no corpo JSON, o **CPF do participante** e `expires_in_hours` entre 1 e 168 (padrão 24). Use `Authorization: Bearer <TOKEN_ADMIN>` no campo correspondente da API.
4. A API retorna **`activation_token` somente na resposta da emissão**, para repassar privadamente à pessoa vinculada ao mesmo CPF. Não cole o token em issues, arquivos públicos, capturas de tela ou nesta conversa.
5. Quando exigido pelo servidor, a pessoa preenche o código em **Criar conta**. O convite é **vinculado ao CPF, de uso único e expira**. Após cadastrar-se, o usuário faz **Entrar** com CPF e senha, sem precisar de novo código.

O código não é um PIN compartilhado entre todos os alunos. Os códigos numéricos **de 6 dígitos**, usados para **presença/check-in em encontros**, têm fluxo separado de emissão/rotação pela equipe da turma; nunca use um no lugar do outro.

## Limitações administrativas atuais e solução alvo

A API oferece a emissão de convite; **não implementa ainda endpoints de listagem/revogação/auditoria de convites para operadores**, nem um painel acessível aos administradores institucionais. Em caso de convite não utilizado, ele expira; para nova pessoa/novo CPF é preciso emitir outro. Evite alterar a tabela diretamente para operar convites.

Para gestão permanente pela equipe, desenhar um painel **Administração → Convites**, autenticado e com RBAC, com geração individual vinculada a CPF, expiração configurável, estado pendente/usado/expirado/revogado, revogação explícita, registro de auditoria e envio por canal privado. A implementação dessa interface e do endpoint de revogação deve ter revisão de segurança antes da implantação.

A criação de **contas gerenciadas da equipe** (`POST /admin/accounts`) é outro fluxo: cria vínculos e perfis formalmente autorizados. Não deve ser substituída por convites de aluno.

## Limites de liberação

Este ajuste de interface **não foi implantado na Play Store**: só entra no aplicativo depois de merge/release e novo AAB aprovado. O build em preparação segue sujeito aos gates de fonte final, QA Xiaomi, assinatura de upload e Play. Não alterar `release_build_allowed=false` nem registrar falso PASS de pre-AAB com testes históricos. A publicação editorial da aula1420 é independente.
