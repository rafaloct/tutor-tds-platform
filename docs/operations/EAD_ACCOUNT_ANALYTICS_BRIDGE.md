# Tutor TDS — cadastro WordPress no aplicativo e atribuição GA4

Data: 21/10/2026. Estado: proposta implementada em **draft PR**, ainda sem merge, publicação ou SSO entre serviços.

## Fontes de verdade

- **WordPress/LearnPress** em `https://ead.ipexdesenvolvimento.cloud`: credenciais de EAD (e-mail/senha WordPress), conta WordPress, matrículas LearnPress, progresso pedagógico e páginas Minha Área e Certificados.
- **FastAPI Tutor TDS** em `/tutor-api`: conta CPF/senha própria, sessão JWT, vínculos e evidências oficiais de turma, operações, consentimento e relatórios. Essa autenticação **não** é substituída nem silenciosamente vinculada à conta WordPress por esta mudança.
- **O login único entre WordPress e FastAPI ainda NÃO está implementado.** Não copiar senha/cookie WordPress, não converter automaticamente conta de e-mail em CPF e não inferir equivalência de identidades.

## O que o aplicativo faz agora

- Botões na tela pública: `Criar conta gratuita no EAD` → `/cadastro/`; `Já tenho conta no EAD` → `/wp-login.php` com retorno interno somente para `/minha-area/`.
- Na lista de cursos: `Criar conta para este curso` → `/cadastro/?tds_curso=<ID-publicado>`. Após o cadastro, o WordPress preserva o curso na navegação de volta; a matrícula precisa ser confirmada no LearnPress por sua rota nativa, **não** acontece automaticamente por abrir curso ou criar conta.
- Navegação utiliza navegador integrado tipo Chrome Custom Tabs quando disponível, com fallback externo. O site conserva o login por seu próprio cookie de navegador; nenhum login/cookie/token é armazenado pela conta FastAPI.
- Os visitantes continuam podendo explorar as cartilhas e os cursos sem CPF nem conta. A tela de criação de conta FastAPI não exige mais código de ativação; o backend já opera com `CPF_ACTIVATION_REQUIRED` ausente (default `false`) na configuração observada.
- A seção de conta **TDS interna** fica explicitamente identificada como acesso separado do EAD para não prometer sincronização inexistente.

## Atribuição web/app por GA4 (sem PII)

O portal possui uma única tag GA4 observada no tema ativo, `G-7B9JLYWLH4`. Os destinos enviados pelo Flutter têm somente dados **fixos públicos**, sem CPF, e-mail, telefone, hash de aluno, session ID ou identificador de dispositivo:

| Campo | Valor |
| --- | --- |
| `utm_source` | `tutor_tds_app` |
| `utm_medium` | `app` |
| `utm_campaign` | `ead_signup`, `ead_login` ou `ead_catalog` |
| `utm_content` | `welcome_signup`, `welcome_login` ou `course_<ID público>` |

A tag GA4 já presente **pode** atribuir as páginas abertas a esses canais/campanhas, quando autorizada e sem bloqueios de coleta. A página do site é a proprietária da coleta web e da permissão de cookies. A alteração **não** injeta GA4 diretamente no aplicativo, não compartilha GA client ID/cookies com a API e não habilita `JOURNEY_TRACEABILITY_ENABLED` em produção.

**Limitação importante:** uma visita a `/cadastro/` não prova cadastro concluído. Para medir conversão real, adicionar em patch WordPress separado um evento `sign_up` após **`wp_insert_user` bem-sucedido**, uma única vez por conta, sem PII e somente conforme o consentimento/aviso de privacidade do portal. Matrícula concluída exige observação de evento real LearnPress pós-matrícula, não é `sign_up`. No painel, comparar contagens **agregadas** do GA4 com criação real de usuários e matrículas no LearnPress; não correlacionar pessoas por heurística.

## Evidência do portal sem escrita em produção

- `GET /cadastro/` HTTP 200, formulário `admin-post.php` com ação `tds_cadastro`, nonce presente e campos `nome`, `email`, `senha`.
- `GET /cadastro/?tds_curso=1298` e a mesma URL com parâmetros UTM HTTP 200, formulário preserva o `tds_curso=1298`.
- Página 1371 publicada usa o template `pages/cadastro.php`; a configuração WordPress `users_can_register=0` não bloqueia necessariamente o formulário institucional, que usa `admin_post_nopriv_tds_cadastro`.
- Execuções anteriores no WP isolado da Issue #299 documentam **32/32 testes HTTP sintéticos PASS**, incluindo criação/login e matrícula nativa sem duplicar inscrições; **nenhum POST de cadastro real** foi feito por este PR.
- O tema ativo e o plugin de integração editorial possuem gates de produção separados. A leitura do tema mostrou que o script GA4 é carregado incondicionalmente em `wp_head`. **Auditar consentimento LGPD/Google Consent Mode antes de ampliar a coleta**, sem copiar PII para analytics.

## Aceite e limites para próxima etapa

- Testes Flutter de URLs canônicas e navegador + telas de EAD (cadastro/login sem CPF, curso 1298) e testes de regressão da API.
- QA físico Android da **fonte final exata**, mantendo a versão Play 1.4.1+14 instalada.
- Registrar autorização para eventual SSO real: requer protocolo confiável entre WP e API (por exemplo OIDC ou fluxo de código de autorização com PKCE, estado, expiração, verificação no servidor e vínculo explícito/consentido) e tratamento de recuperação/revogação. **Não** simplesmente encaminhar senha WP à API nem trocar cookie por JWT TDS no Flutter.
- Este PR não altera contas, senhas, sessão, papéis, flags, banco, WP, API de produção, migrações, chaves, mídias, matrícula, notas, certificados ou o aplicativo publicado.
