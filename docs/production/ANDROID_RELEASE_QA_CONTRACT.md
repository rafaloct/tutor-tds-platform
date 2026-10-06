# Contrato de QA Android para release

## Regra operacional

A partir de 2026-10-06, emulador é o executor padrão para QA funcional Android.

Devem rodar em emulador sempre que tecnicamente possível:

- fluxos funcionais;
- offline e reconexão;
- idempotência;
- persistência e reabertura;
- CourseVersion;
- certificado e revisão humana em staging;
- regressões e E2E.

O Xiaomi não deve ser usado para repetir essa matriz.

## Único gate físico obrigatório

pre_aab_xiaomi_smoke

Esse smoke acontece imediatamente antes de liberar a geração do AAB e deve ser curto, sem reexecutar toda a suíte. Seu objetivo é detectar diferenças de hardware e ROM que o emulador não cobre.

O smoke deve preservar a versão Play instalada.

## Compatibilidade do schema v1

release_status.json mantém a chave histórica required_physical_evidence para não quebrar o Gradle e o schema v1. O nome da chave não significa que todos os itens precisem de dispositivo físico.

Somente pre_aab_xiaomi_smoke exige Xiaomi. Os demais gates aceitam emulador.

## Regra de custo e tempo

Não bloquear uma frente funcional por indisponibilidade de Xiaomi se ela puder ser comprovada em emulador. Não repetir no Xiaomi um gate já aprovado em emulador, exceto o smoke físico final previsto acima.
