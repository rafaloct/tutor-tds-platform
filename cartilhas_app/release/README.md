# Artefatos de release

## Atual

`Tutor-TDS-1.3.0+12-signed.aab` é o bundle candidato à Play Console.

- tamanho: `63.044.125` bytes;
- SHA-256: `8c1981323f446505e62901f875d609dafb8b3be652174a41bc4e47b22504fdd1`;
- pacote: `com.tutortds_cartilhas`;
- versão: `1.3.0` (`versionCode 12`);
- target SDK: 36;
- alinhamento nativo: 16 KB;
- assinatura: chave de upload correspondente a `android/upload_certificate.pem`.

Não envie o `.jks`, `key.properties` nem `config/production.json`. Antes do
upload, confirme na Play Console que o certificado público versionado é a chave
de upload aceita e siga `PLAY_CONSOLE_CHECKLIST.md`.

## Históricos

Os bundles 1.1.0+10 e 1.2.0+11 permanecem apenas como histórico. O artefato
1.1.0+10 é não assinado e nunca deve ser enviado.
