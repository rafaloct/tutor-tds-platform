# Tutor TDS - trilha segura de build e instalação Android DEV

## Garantias da trilha

- Release permanece `com.tutortds_cartilhas` com rótulo `Tutor TDS`.
- Debug usa `com.tutortds_cartilhas.dev`, sufixo de versão `-dev` e rótulo visível `Tutor TDS DEV`.
- Todo build debug exige `TUTOR_ENVIRONMENT=staging`.
- `TUTOR_API_URL` deve coincidir exatamente com `TUTOR_STAGING_API_URL` e com a rota aprovada `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`.
- A rota produtiva `/tutor-api` e qualquer outro endpoint são rejeitados pelo Gradle e pelo instalador.
- O Tutor IA pode ficar desligado no QA. Se configurado, seu gateway também precisa de host de staging explícito.
- A instalação automatizada valida package ID, rótulo e assinatura antes de chamar ADB.
- A instalação consulta `GET /health` por HTTPS e exige API/banco saudáveis antes de chamar ADB.
- A versão Play nunca é desinstalada, limpa ou substituída.

O gate Gradle também protege builds iniciados diretamente pelo Flutter ou Android Studio. Um comando debug sem configuração de staging falha antes de compilar o aplicativo.

## Estado atual e bloqueio

Existe um Compose de staging local e a rota planejada é `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api`, separada da produção por Traefik. A rota ainda não está publicada/respondendo com health HTTPS, portanto ainda não é um ambiente de QA disponível para o Xiaomi.

Por isso, nenhum APK novo deve ser instalado ainda. Usar a URL de produção para contornar esse bloqueio é proibido pela validação.

## Configuração sem segredo

Copie `cartilhas_app/config/staging.example.json` para um arquivo temporário fora do repositório, por exemplo:

```powershell
$qaConfig = Join-Path $env:TEMP 'tutor-tds-staging.json'
Copy-Item .\cartilhas_app\config\staging.example.json $qaConfig
```

Preencha somente URLs públicas de staging. O arquivo não deve conter senha, token, chave de API, CPF ou conta real.

Campos de controle:

| Campo | Regra |
|---|---|
| `TUTOR_ENVIRONMENT` | valor exato `staging` |
| `TUTOR_STAGING_API_URL` | URL completa aprovada da API de staging |
| `TUTOR_API_URL` | a mesma URL completa, usada pelo Flutter |
| `TUTOR_STAGING_GATEWAY_URL` | URL completa do gateway de IA de staging ou vazio |
| `TUTOR_GATEWAY_URL` | URL HTTPS correspondente ou vazio para desativar IA |

## Build sem instalar

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\build_install_android_dev.ps1 `
  -StagingConfigPath $qaConfig `
  -BuildOnly
```

O script gera o APK e comprova:

- package `com.tutortds_cartilhas.dev`;
- rótulo `Tutor TDS DEV`;
- assinatura APK válida;
- hash SHA-256.

## Instalação no Xiaomi

Somente depois de o staging responder ao health check e conter dados sintéticos:

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\build_install_android_dev.ps1 `
  -StagingConfigPath $qaConfig `
  -Serial <serial-retornado-por-adb>
```

O script usa `adb install -r` apenas depois da validação do package `.dev` e de `GET /health` confirmar o staging. Ele não inicia o aplicativo e compara os metadados da versão Play antes e depois da instalação.

## Dados sintéticos obrigatórios

- Nome: `Aluno QA Xiaomi`.
- Telefone: número reservado/interno definido para QA, nunca contato real.
- CPF: valor sintético válido e identificado na base como conta de teste.
- Instituição/programa/turma: prefixo `QA-`.
- Cursos e eventos: IDs com prefixo ou namespace de staging.
- Certificados: marca d'água `SEM VALIDADE - STAGING` quando esse fluxo for habilitado.

O seed sintético deve ser idempotente e sua limpeza deve ocorrer somente no banco isolado de staging.

## Gate para liberar a instalação

- [ ] DNS/URL HTTPS de staging aprovado.
- [ ] Banco e credenciais exclusivos de staging.
- [ ] `GET /health` confirma banco de staging.
- [ ] CORS/origens e logs não apontam para produção.
- [ ] Google Sheet, caso habilitada, é planilha de staging.
- [ ] Worker de certificado não emite artefato produtivo.
- [ ] Gateway IA é staging ou está vazio/desligado.
- [ ] Dados sintéticos carregados.
- [ ] Commit e testes da fatia estão verdes.
- [ ] Hash do APK registrado.
- [ ] Package e rótulo DEV validados.

## Rollback local seguro

Se o APK DEV apresentar defeito, não execute `pm clear` ou `adb uninstall` automaticamente. Preserve os dados para diagnóstico e instale uma build DEV corrigida com `-r`. A remoção do pacote `.dev` exige decisão explícita sobre as evidências de teste.
