# Checklist Play Console — 1.4.0+13

> **STOP:** `Tutor-TDS-1.4.0+13-signed.aab` com SHA-256
> `B93FAD21CE8AE92AB464FCAFE8FB69E66C07C6E712DB0DBFCA0AE580B2844B66`
> está superseded e não deve ser enviado. Aguardar reteste físico do Evidence
> offline e novo rebuild.

## Estado histórico e bloqueio atual

- [x] Freeze legível por máquina em `release/release_status.json`.
- [x] `preReleaseBuild` bloqueia release enquanto
  `release_build_allowed=false` ou existir evidência física obrigatória pendente.
- [x] `dart run tool/verify_release_readiness.dart --intent=audit` confirma
  versão/pacote/SDKs, flags, configuração produtiva e identidade de assinatura;
  o estado atual falha somente pelos bloqueios deliberados do freeze.

- [x] Auditoria somente leitura observou `versionCode 13` disponível; revalidar
  imediatamente antes do upload porque outro envio pode consumir o código.
  Evidência: `PLAY_CONSOLE_READONLY_AUDIT_2026-09-20.md`; os únicos pacotes
  visíveis eram `11 (1.2.0)` e `2 (1.1.0)`.
- [x] Target/compile SDK 36 e min SDK 24.
- [x] O AAB superseded foi assinado, validado pelo Bundletool e alinhado a
  páginas de 16 KB; o novo bundle deverá repetir esses gates.
- [x] Certificado do keystore local igual a `android/upload_certificate.pem`.
- [x] URLs produtivas HTTPS compiladas e validadas sem segredos.
- [x] API e banco produtivos saudáveis, 9 cursos carregados e backup diário local.
- [x] Código atual com 183/183 testes; validação do bundle superseded preservada
  apenas como histórico.
- [x] Exclusão dentro do app e página externa disponíveis.
- [x] Política de privacidade pública disponível.
- [x] Notas da versão em `whatsnew-pt-BR.txt`.

## Ações na Play Console

- [ ] Revisar o rascunho `Teste fechado - App` e a mudança de testadores ainda
  não enviada, para que não sejam submetidos por acidente junto do novo release.
- [ ] Após o reteste físico, registrar o gate como `passed` e liberar build de
  forma explícita no manifesto; não remover o verificador do Gradle.
- [ ] Depois do rebuild e dos gates do AAB, registrar novo caminho/hash como
  `candidate`, `upload_allowed=true` e `matches_current_source=true`.
- [ ] Executar `dart run tool/verify_release_readiness.dart --intent=upload --artifact=release/NOVO-CANDIDATO.aab`;
  só prosseguir se retornar `READY`.
- [ ] Confirmar que a chave de upload exibida corresponde ao certificado PEM.
- [ ] Após reteste/rebuild, registrar novo nome/hash e enviar somente o **novo
  AAB** para Teste interno. Nunca enviar o hash superseded acima.
- [ ] Informar a política: `https://cartilhas.ipexdesenvolvimento.cloud/privacy.html`.
- [ ] Informar a exclusão: `https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html`.
- [ ] Atualizar **Segurança dos dados** usando `DATA_SAFETY.md` e revisar contratos dos provedores.
- [ ] Resolver as perguntas e divergências técnicas de `PLAY_CONSOLE_HUMAN_REVIEW_1.4.0+13.md`.
- [ ] Confirmar por OpenAPI/smoke que o backend produtivo expõe as rotas usadas pelo AAB antes de anunciar vídeos, retomada entre aparelhos, área de equipe ou Evidence.
- [ ] Confirmar público-alvo/classificação indicativa e declarar que o app não é dirigido a crianças, se isso refletir a decisão do Programa TDS.
- [ ] Executar o relatório de pré-lançamento e corrigir bloqueadores.
- [ ] Instalar pelo teste interno em pelo menos um Android 7/8 e um Android recente.
- [ ] Testar atualização sobre a versão atualmente publicada, login/logout/reentrada, leitura offline, voz/TTS, IA, vídeos, simulado cross-device, suporte, certificado e exclusão.
- [ ] Promover com rollout gradual; monitorar erros, API e suporte antes de 100%.

## Critério de parada

Não promover se a Play apontar chave incorreta, política inacessível, falha de
16 KB, crash no pré-lançamento, formulário de dados incoerente ou falha no ciclo
de conta/exclusão.
