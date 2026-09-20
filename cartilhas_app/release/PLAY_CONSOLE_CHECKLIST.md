# Checklist Play Console — 1.3.0+12

## Pronto localmente e na infraestrutura

- [x] `versionCode 12` maior que o publicado anteriormente (`11`).
- [x] Target/compile SDK 36 e min SDK 24.
- [x] AAB assinado, validado pelo Bundletool e alinhado a páginas de 16 KB.
- [x] Certificado do keystore local igual a `android/upload_certificate.pem`.
- [x] URLs produtivas HTTPS compiladas e validadas sem segredos.
- [x] API e banco produtivos saudáveis, 9 cursos carregados e backup diário local.
- [x] Cadastro, evento, analytics, exclusão e revogação testados externamente.
- [x] Exclusão dentro do app e página externa disponíveis.
- [x] Política de privacidade pública disponível.
- [x] Notas da versão em `whatsnew-pt-BR.txt`.

## Ações na Play Console

- [ ] Confirmar que a chave de upload exibida corresponde ao certificado PEM.
- [ ] Enviar `Tutor-TDS-1.3.0+12-signed.aab` para **Teste interno**.
- [ ] Informar a política: `https://cartilhas.ipexdesenvolvimento.cloud/privacy.html`.
- [ ] Informar a exclusão: `https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html`.
- [ ] Atualizar **Segurança dos dados** usando `DATA_SAFETY.md` e revisar contratos dos provedores.
- [ ] Confirmar público-alvo/classificação indicativa e declarar que o app não é dirigido a crianças, se isso refletir a decisão do Programa TDS.
- [ ] Executar o relatório de pré-lançamento e corrigir bloqueadores.
- [ ] Instalar pelo teste interno em pelo menos um Android 7/8 e um Android recente.
- [ ] Testar leitura offline, conta, voz, IA, suporte, certificado, exclusão e atualização sobre a versão 1.2.0.
- [ ] Promover com rollout gradual; monitorar erros, API e suporte antes de 100%.

## Critério de parada

Não promover se a Play apontar chave incorreta, política inacessível, falha de
16 KB, crash no pré-lançamento, formulário de dados incoerente ou falha no ciclo
de conta/exclusão.
