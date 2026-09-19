# Artefatos de release

`Tutor-TDS-1.2.0+11-signed.aab` é o bundle de produção atual. Ele foi gerado
com `config/production.json`, contém apenas a URL HTTPS do gateway e está
assinado com a chave de upload cujo SHA-256 é
`16:44:39:F5:EF:57:F6:E9:C7:B8:58:A3:4F:59:2C:26:1D:CC:EC:AD:B3:B3:59:98:F0:7C:40:1F:6C:34:3F:50`.
Envie-o somente depois que esse certificado aparecer como chave de upload
aceita na Play Console.

`Tutor-TDS-1.1.0+10-unsigned.aab` é um artefato de validação, compilado sem
credenciais de serviços e sem chave de upload. Ele não deve ser enviado à Play
Console.
