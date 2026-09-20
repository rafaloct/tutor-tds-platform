# Artefatos de release

## Atual

`Tutor-TDS-1.4.0+13-signed.aab` é o bundle candidato à Play Console para teste interno.

- tamanho: `64.711.735` bytes;
- SHA-256: `706e007de279010752ebe9d45bdff44f307eedc43f46d0e09a946cd6ef502946`;
- pacote: `com.tutortds_cartilhas`;
- versão: `1.4.0` (`versionCode 13`);
- target SDK: 36;
- alinhamento nativo: 16 KB;
- assinatura: chave de upload correspondente a `android/upload_certificate.pem`.

Não envie o `.jks`, `key.properties` nem `config/production.json`. Antes do
upload, confirme na Play Console que o certificado público versionado é a chave
de upload aceita e siga `PLAY_CONSOLE_CHECKLIST.md`.

## Históricos

Os bundles 1.1.0+10, 1.2.0+11 e 1.3.0+12 permanecem apenas como histórico. O artefato
1.1.0+10 é não assinado e nunca deve ser enviado.
