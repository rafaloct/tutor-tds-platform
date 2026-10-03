# Guias de configuração por serviço

Este documento descreve **como preparar, verificar e registrar** cada serviço. Não contém valores secretos. Quando a instalação real divergir, registrar OBSERVED no inventário antes de adaptar.

## Regra universal

Para cada serviço novo ou reconstruído:

1. definir owner funcional e técnico;
2. usar conta institucional;
3. habilitar MFA quando suportado;
4. criar segundo administrador;
5. separar staging/produção;
6. registrar secrets somente no secret store autorizado;
7. configurar logs/monitor;
8. configurar backup/restore quando houver estado;
9. executar smoke test;
10. registrar versão, URL, dependências e evidência no SERVICE_REGISTRY.

---

## 1. GitHub

### Preparar
- repositório privado ou visibilidade institucional aprovada;
- branch padrão correta;
- membros por menor privilégio;
- Actions habilitado somente no necessário.

### Configurar
- branch/ruleset protection;
- checks obrigatórios;
- secret scan;
- CODEOWNERS quando equipe estiver definida;
- template de issue/PR;
- dependabot apenas se política aprovada;
- environment protection para production se secrets GitHub forem usados.

### Verificar
- PR falho não mergeia;
- docs-only não fica preso;
- force push/delete bloqueado;
- agente sem permissão administrativa ainda consegue abrir PR.

### Recuperar
- pelo menos dois admins;
- e-mail institucional de recuperação;
- export/clone espelhado opcional documentado.

---

## 2. Domínio e DNS

### Preparar
Inventariar zona oficial e registrar owner.

### Configurar
Cada hostname deve apontar para exatamente um propósito:
- portal;
- API;
- suporte se exposto;
- staging;
- mídia se necessário.

Não criar hostname “temporário” em produção sem registrar.

### Verificar
- resolução A/AAAA/CNAME;
- TLS;
- redirect HTTP→HTTPS;
- certificate expiry;
- host header correto.

### Recuperar
Documentar registrar/provedor, segundo admin e processo de renovação.

---

## 3. VPS Hostinger e Dokploy

### Preparar
- acesso SSH por chave individual;
- sem senha compartilhada;
- firewall;
- timezone/clock;
- espaço em disco.

### Configurar
- um projeto/compose por conjunto coerente;
- networks privadas;
- volumes explícitos;
- restart policy;
- env/secrets no Dokploy;
- health checks;
- limits quando possível;
- logs com rotação.

### Verificar
- containers esperados;
- nenhuma porta DB pública indevida;
- health;
- restart de um componente não derruba outro não relacionado;
- deploy de staging sem afetar production.

### Recuperar
- backup de config/compose;
- inventário dos IDs Dokploy;
- runbook de recriação;
- não depender de nome visual do painel como único identificador.

---

## 4. PostgreSQL

### Preparar
- instância/DB por ambiente;
- usuário dedicado da aplicação;
- usuário de backup quando aplicável.

### Configurar
- DATABASE_URL via secret;
- volume persistente;
- encoding UTF-8;
- acesso somente da rede necessária;
- migration Alembic.

### Verificar
- conexão interna;
- `alembic current`;
- upgrade em base vazia;
- upgrade em clone/restored snapshot;
- escrita/leitura sintética;
- backup recente.

### Recuperar
- dump criptografado externo;
- restore isolado;
- validar contagens, constraints e revision.

---

## 5. FastAPI

### Preparar
Imagem/build reproduzível com `uv.lock`.

### Configurar
- DATABASE_URL;
- PUBLIC_API_BASE_URL;
- JWT_SECRET;
- CPF_PEPPER;
- flags;
- integrações opcionais;
- environment explícito.

### Verificar
- `/health`;
- `/version`;
- schema revision;
- CORS;
- auth;
- endpoint público sem PII;
- endpoint privado nega não autorizado.

### Recuperar
Reimplantar mesma imagem/tag + env + DB restaurado. Não “consertar” produção editando container manualmente.

---

## 6. Flutter / Google Play

### Preparar
- package existente;
- upload key preservada;
- versão/versionCode;
- config de ambiente.

### Configurar
- URLs via build config;
- flags false por padrão para risco;
- privacy/account deletion URLs;
- build sem secrets.

### Verificar
- analyze;
- unit/widget tests;
- preflight;
- build somente quando gate autorizar;
- instalação/upgrade em dispositivo de teste;
- login/logout/offline.

### Recuperar
- Play mantém artefatos anteriores;
- rollback operacional normalmente significa corrigir release seguinte ou usar mecanismos oficiais da Play, não distribuir APK paralelo silenciosamente.

---

## 7. Cloudflare Worker / KV

### Preparar
- account institucional;
- projeto/worker por ambiente quando necessário;
- namespace KV documentado.

### Configurar
Secrets somente via secret mechanism:
- upstream IA;
- signing secret;
- allowed origins.

### Verificar
- health;
- chat com payload sintético;
- timeout;
- certificate lookup;
- CORS;
- não expõe secret.

### Recuperar
Código versionado + bindings + secrets recuperáveis por processo institucional. Exportar/registrar estratégia de KV conforme criticidade.

---

## 8. AnythingLLM / provider de IA

### Preparar
- workspace correto;
- documentos autorizados;
- provider/model aprovado.

### Configurar
- API key no servidor/gateway;
- limites;
- timeout;
- corpus.

### Verificar
- resposta baseada no corpus;
- falha upstream tratada;
- custo/latência observáveis;
- nenhum segredo no app.

### Recuperar
Recriar workspace a partir de corpus master/documentado quando possível.

---

## 9. Cloudflare R2 / S3

### Preparar
- bucket por finalidade ou prefixo fortemente separado;
- credencial mínima;
- lifecycle.

### Configurar
- endpoint;
- access key/secret no secret store;
- CORS somente quando browser realmente envia;
- encryption/age para backup quando previsto;
- chave privada fora do mesmo destino.

### Verificar
- put/get de objeto sintético;
- checksum;
- delete somente no prefixo autorizado;
- presigned URL expira;
- staging não lê production.

### Recuperar
Conta institucional + segundo admin + inventário de buckets/prefixos + chave de decrypt separada.

---

## 10. Google Drive

### Papel
Master/acervo, não CDN.

### Configurar
- pasta institucional;
- ownership claro;
- service account somente se necessário;
- permissões por grupo/equipe;
- naming/versionamento.

### Verificar
- owner institucional;
- arquivo acessível aos papéis corretos;
- link público somente quando conteúdo é público;
- IDs master não enviados ao aluno quando não necessários.

### Recuperar
Drive institucional e grupos devem sobreviver à troca de pessoa.

---

## 11. Google Sheets

### Papel
Projeção/operacional analítico, não fonte transacional.

### Configurar
- arquivo por ambiente;
- range exclusivo;
- service account writer;
- HMAC de pseudonimização separado;
- worker opt-in.

### Verificar
- sentinela sintético;
- readback;
- replay sem duplicata;
- contagem DB vs Sheet;
- nenhum CPF novo.

### Recuperar
Planilha pode ser regenerável do PostgreSQL quando contrato permitir; documentar quais abas manuais NÃO são regeneráveis.

---

## 12. Power BI / Fabric

### Preparar
- workspace;
- owner;
- fonte;
- credenciais/refresh.

### Configurar
- queries versionadas quando possível;
- data dictionary;
- relações por IDs canônicos;
- refresh agendado;
- RLS se necessário.

### Verificar
- refresh;
- filtros;
- totais vs fixtures;
- nulls;
- nenhuma inferência indevida.

### Recuperar
PBIP/source versionado quando possível + configuração de gateway/fonte documentada.

---

## 13. Chatwoot

### Preparar
- versão/licença real;
- account;
- inbox;
- agents/teams;
- owner.

### Configurar
Primeiro staging/sintético:
- widget/inbox;
- identidade segura server-side;
- competências;
- webhook somente após autenticação comprovada;
- retenção/anexos.

### Verificar
- visitante;
- autenticado;
- A→B em aparelho compartilhado;
- mensagens;
- nota interna não visível;
- logout;
- resposta tardia;
- isolamento entre turmas/ambientes.

### Recuperar
DB/config/anexos conforme topologia real. Não assumir que backup do Tutor DB cobre Chatwoot.

---

## 14. WordPress

### Preparar
- instância staging;
- admin institucional;
- child theme;
- plugins mínimos.

### Configurar
- permalink;
- HTTPS;
- tema;
- páginas canônicas;
- REST posts;
- integração read-only com Tutor API;
- SMTP apenas se necessário;
- cache;
- analytics separado.

### Verificar
- publicar draft/post;
- editor sem acesso técnico;
- mobile;
- acessibilidade;
- API Tutor offline;
- 404;
- backup/restore.

### Recuperar
DB + wp-content + lista de versões de core/plugins/tema.

---

## 15. Backup e monitoramento

### Configurar
- schedule;
- retenção;
- storage externo;
- criptografia;
- alertas;
- monitor externo.

### Verificar
- execução por relógio;
- cópia;
- checksum;
- restore;
- falha controlada;
- alerta recebido.

### Recuperar
Runbook deve funcionar para pessoa que não escreveu a automação.

---

## 16. Checklist final de serviço

Nenhum serviço é considerado “operável” até existir:

- [ ] owner;
- [ ] segundo admin ou risco formal;
- [ ] config documentada;
- [ ] secrets fora do repo;
- [ ] health/smoke;
- [ ] backup se stateful;
- [ ] restore se crítico;
- [ ] monitor;
- [ ] custo/renovação;
- [ ] rollback;
- [ ] registro no inventário.
