# Artefatos de release

## Atual

**Candidato validado: `Tutor-TDS-1.4.1+14-signed.aab`.**
`verify_release_readiness.dart --intent=upload` reporta READY; o upload no
Play Console permanece ação humana.

- SHA-256 do candidato:
  `D161451E16EF008DB51E2957441B19D2B2B9BC50D6059E011B3759CD727ECEB3`.

Nota de ciclo: o primeiro build 1.4.1+14 foi descartado por defeito de
empacotamento (`GeneratedPluginRegistrant` ausente do DEX, canais de plugin
inativos). O artefato válido foi reconstruído e o DEX do AAB/APK conferido
antes do QA físico no Xiaomi.

Mudanças do 1.4.1: cartilha "Aspectos Jurídicos para Startups"
(PEQUI-UFT / INOVATO / Finep) embarcada no catálogo e tema Claro como padrão
em novas instalações (preferência do usuário continua respeitada).

`Tutor-TDS-1.4.0+13-signed.aab` permanece registrado como histórico; o hash
aprovado do ciclo anterior consta em `release_status.json`.

Os dados abaixo são mantidos somente para rastreabilidade do artefato 1.4.0+13:

- SHA-256 aprovado no ciclo anterior:
  `31B90EEEB030C4D842C3F85BFB491757FA468C45AD644C2D713EB96AABCD05CA`;
- pacote: `com.tutortds_cartilhas`;
- versão: `1.4.0` (`versionCode 13`);
- target SDK: 36;
- assinatura: chave de upload correspondente a `android/upload_certificate.pem`.

## Freeze executável

`release/release_status.json` é a fonte local legível por máquina para o estado
do artefato e das evidências físicas obrigatórias. Enquanto
`release_build_allowed=false` ou um gate físico obrigatório estiver pendente,
o próprio `preReleaseBuild` do Gradle interrompe qualquer build release.

O verificador é somente leitura e deve ser executado antes de alterar o freeze
ou preparar upload:

```powershell
dart run tool/verify_release_readiness.dart --intent=audit
dart run tool/verify_release_readiness.dart --intent=build
dart run tool/verify_release_readiness.dart --intent=upload --artifact=release/NOVO-CANDIDATO.aab
```

O último comando também exige estado `candidate`, `upload_allowed=true`,
`matches_current_source=true` e SHA-256 idêntico ao manifesto. A Play Console continua sendo uma ação humana;
o verificador não envia arquivos.

Não envie este AAB, o `.jks`, `key.properties` nem `config/production.json`.
Depois do reteste e rebuild, confirme na Play Console que o certificado público
versionado é a chave de upload aceita e siga `PLAY_CONSOLE_CHECKLIST.md`.

## Históricos

Os bundles 1.1.0+10, 1.2.0+11 e 1.3.0+12 permanecem apenas como histórico. O artefato
1.1.0+10 é não assinado e nunca deve ser enviado.
