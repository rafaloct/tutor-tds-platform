# Artefatos de release

## Atual

`Tutor-TDS-1.4.0+13-signed.aab` é o candidato final validado para envio à
trilha de teste interno. Ele foi reconstruído depois da correção P1 de mídia e
do reteste físico de grant/HLS, velocidades e retomada. O upload e a promoção
permanecem ações humanas.

- tamanho: `64.716.303` bytes;
- SHA-256: `b93fad21ce8ae92ab464fcafe8fb69e66c07c6e712db0dbfca0ae580b2844b66`;
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
