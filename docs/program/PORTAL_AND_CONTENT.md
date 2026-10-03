# Portal público, consulta e notícias

## 1. Papel

O portal é a presença web pública e editorial do Programa TDS. Ele complementa o app, mas não duplica o núcleo transacional.

O arquivo raiz `pagina_wordpress.html` é **legado de referência**, não especificação atual. Ele contém instruções de APK e versão antigas e deve ser substituído por componentes coerentes com Play Store/API atuais.

## 2. Público-alvo

- participante atual;
- pessoa interessada;
- familiares/apoio;
- equipe de campo;
- parceiros institucionais;
- imprensa/público;
- usuário que precisa verificar certificado;
- usuário que procura suporte, privacidade ou exclusão de conta.

## 3. Mapa do site alvo

```text
/
├── O Programa
│   ├── objetivos
│   ├── territórios/municípios
│   ├── instituições e responsabilidades
│   └── perguntas frequentes
├── Cursos
│   ├── catálogo público
│   └── página de curso
├── Acessar
│   ├── baixar/abrir app oficial
│   ├── como entrar
│   └── problemas de acesso
├── Notícias
│   ├── lista
│   ├── categorias
│   └── notícia
├── Agenda
├── Materiais públicos
├── Resultados / transparência pública
├── Verificar certificado
├── Suporte
├── Privacidade
├── Solicitar exclusão / direitos
└── Contato institucional
```

## 4. Autoridades

| Conteúdo | Autoridade |
|---|---|
| notícias, páginas, agenda, FAQ | WordPress |
| catálogo/curso publicado | FastAPI; portal consome read-only |
| inscrição/matrícula | FastAPI em fluxo autenticado/autorizado |
| progresso/frequência | FastAPI; nunca WordPress |
| certificado | Worker/API de verificação |
| materiais públicos | metadados API/WordPress; arquivo em storage autorizado |
| suporte | Chatwoot |
| política/termos | documento institucional publicado e versionado |

## 5. Integração WordPress ↔ API

Preferir endpoints públicos explícitos, sem token administrativo:

```text
GET /public/program
GET /courses
GET /public/courses/{slug}
GET /public/materials
GET /version
```

Se endpoints não existirem, criar issue própria. Não fazer WordPress ler PostgreSQL diretamente.

### Cache
WordPress pode cachear resposta pública por curto período. Deve exibir “indisponível temporariamente” se a API falhar, sem mostrar dado obsoleto como matrícula/progresso.

## 6. Notícias no app

A opção preferida é feed público do WordPress:

```text
GET /wp-json/wp/v2/posts?... 
```

O app mostra título, resumo, data, imagem e link. O app não precisa persistir notícia no PostgreSQL salvo se houver requisito de analytics de leitura, tratado como evento não acadêmico.

## 7. Autenticação

Não reutilizar login WordPress para aluno.

- público: sem login;
- editor WordPress: conta editorial separada;
- aluno/equipe: autenticação Tutor TDS;
- painel sensível: API/RBAC Tutor TDS.

SSO futuro deve ser projeto próprio, não improvisação.

## 8. Conteúdo e workflow editorial

```text
rascunho → revisão → aprovado → publicado → atualizado/arquivado
```

Papéis mínimos:
- Autor: cria/edita rascunho.
- Revisor: revisa linguagem, links e acessibilidade.
- Publicador: agenda/publica.
- Administrador técnico: plugins, tema, backup; não é aprovação de conteúdo.

Mudança crítica em política, logo institucional ou informação oficial requer dono de conteúdo definido em RACI.

## 9. Requisitos de página

- responsivo;
- contraste e navegação por teclado;
- heading hierarchy correta;
- imagens com alt;
- linguagem simples;
- OpenGraph/social;
- sitemap;
- canonical URLs;
- analytics sem capturar dado sensível;
- consentimento/cookies quando aplicável;
- banner não deve bloquear uso essencial;
- links externos identificados;
- erro 404/500 útil;
- performance mobile.

## 10. Segurança WordPress

- atualizações de core/plugins/tema controladas;
- mínimo de plugins;
- MFA para administradores quando disponível;
- contas individuais;
- sem compartilhamento de senha;
- menor privilégio;
- backup de banco + wp-content;
- staging antes de update maior;
- WAF/rate limit quando disponível;
- XML-RPC desabilitado se não necessário;
- REST API sensível restrita;
- uploads validados;
- segredo nunca no tema/repositório.

## 11. Dados proibidos no WordPress público

CPF, NIS, renda, baseline, matrícula individual, presença, nota, telefone privado, tokens, IDs internos úteis a enumeração, transcrição de atendimento, anexo sensível.

## 12. Verificação de certificado

Portal deve apenas encaminhar/embutir o verificador oficial. Não duplicar lógica criptográfica.

## 13. Métricas permitidas

Page views, origem, dispositivo, cliques de acesso, busca, notícia lida, download público. Separar analytics público de jornada acadêmica.

## 14. Critérios de aceite da primeira versão

- home e mapa de navegação aprovados;
- catálogo lido da API ou placeholder explícito;
- notícias publicáveis por editor sem deploy;
- acesso aponta para canal oficial atual;
- privacidade/exclusão disponíveis;
- suporte funcional;
- certificado verificável;
- sem PII no HTML/logs;
- Lighthouse/acessibilidade documentados;
- backup e restore do WordPress testados em staging;
- runbook para publicar notícia e recuperar site.
