# Artefatos de release

## Atual

**Não há AAB atual liberado para upload.**

`Tutor-TDS-1.4.0+13-signed.aab`, hash
`B93FAD21CE8AE92AB464FCAFE8FB69E66C07C6E712DB0DBFCA0AE580B2844B66`, está
**superseded e não deve ser enviado à Play Console**. Ele antecede a mudança de
retomada offline segura do Evidence/check-in, validada no código pela suíte
Flutter 177/177. Um novo bundle só deve ser gerado depois do reteste físico no
Xiaomi reconectado.

Os dados abaixo são mantidos somente para rastreabilidade do artefato
superseded:

- tamanho: `64.716.303` bytes;
- SHA-256: `b93fad21ce8ae92ab464fcafe8fb69e66c07c6e712db0dbfca0ae580b2844b66`;
- pacote: `com.tutortds_cartilhas`;
- versão: `1.4.0` (`versionCode 13`);
- target SDK: 36;
- alinhamento nativo: 16 KB;
- assinatura: chave de upload correspondente a `android/upload_certificate.pem`.

Não envie este AAB, o `.jks`, `key.properties` nem `config/production.json`.
Depois do reteste e rebuild, confirme na Play Console que o certificado público
versionado é a chave de upload aceita e siga `PLAY_CONSOLE_CHECKLIST.md`.

## Históricos

Os bundles 1.1.0+10, 1.2.0+11 e 1.3.0+12 permanecem apenas como histórico. O artefato
1.1.0+10 é não assinado e nunca deve ser enviado.
