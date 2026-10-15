# Resolução e auditoria isoladas — #208

Estes manifests são **artefatos de auditoria**, não dependências do portal ativo.
O composer.json/lock principal continua igual ao staging11.4.10. Nenhum módulo
contrib foi habilitado, nenhum provider recebeu chave e nenhuma inferência ocorreu.

## Reprodução

Copiar somente composer.json/lock desta pasta para um diretório descartável;
usar PHP8.3 com extensões do Dockerfile.production e Composer2. Executar:

```sh
composer validate --strict
composer audit --locked
composer install --no-scripts --no-interaction --prefer-dist
```

Não executar Composer no diretório de produção. `--no-scripts` não desativa
plugins: o scaffold Drupal gera arquivos na fixture; allow-plugins permanece
explícito. Não executar recipe, instalar site ou habilitar contrib automaticamente.
Reprodução da instalação a partir do lock não exige chave OpenRouter.

OBSERVED no VPS em15/10/2026: validate strict PASS; audit locked sem advisories;
install a partir do lock PASS.23 pacotes adicionados, nenhuma versão preexistente
alterada; core11.4.10 preservado. Resolução inicial com pins exatos gerou warnings
semver em validate strict; constraints foram ajustadas para faixas de patch,
mantendo versões exatas no lock. Não houve relaxamento para beta/dev ou update global.
Hashes e versões estão em receipt.json. Advisory limpo não prova segurança do código.

## Revisão do código instalado

Paths abaixo relativos a web/modules/contrib da fixture. Fonte baixada pelo
Composer oficial/TLS; arquivo de revisão e arquivos citados têm hashes no recibo.

| Evidência | Limite para este piloto |
| --- | --- |
| ai_provider_openrouter/src/Service/OpenRouterClient.php:122 | OpenAI Factory não recebe withHttpClient; mock do http_client Drupal não intercepta chat. Timeout/redirect não são explícitos nesse caminho; defaults SDK não auditados. |
| mesmo arquivo:104,143 | registra mensagem bruta de exceção; sanitizar depois no controller é tarde demais |
| ai_ckeditor/ai_ckeditor.routing.yml:9 | exige use ai ckeditor, sem requisito CSRF declarado na rota |
| ai_ckeditor/src/Controller/AiRequest.php:94,145,153 | prompt vindo do cliente sem validação de entidade/bundle/acesso à edição/tamanho/quota do piloto |
| mesmo arquivo:149,168 | força streaming e registra exceção bruta |
| ai_provider_openrouter/src/Plugin/AiProvider/OpenRouterProvider.php:304,877 | enabled_models filtra listagem, não enforcement do chat; seleção vazia permite todos na listagem |
| ai_provider_openrouter/src/Form/OpenRouterConfigForm.php:158 | configuração/listagem pode consultar catálogo remoto; fixture offline requer bloquear transporte |
| key/src/Plugin/KeyProvider/EnvKeyProvider.php:95 | Environment lê chave no servidor e retorna NULL se ausente; mecanismo reutilizável |

Esses achados são incompatibilidades com a política deste piloto, não declaração
de vulnerabilidade geral dos projetos. Não foi feito teste de exploração ou
chamada ao modelo. AI Framework/eventos/logging e defaults SDK ainda precisam
revisão antes de qualquer ativação de contrib. Provider sem cobertura Drupal
security advisories exige análise além de composer audit.

## Escolha técnica para a próxima fatia

Reutilizar fornecedor OpenRouter/modelo candidato do Tutor por adapter TDS mínimo,
sem reutilizar workspace/chave/prompt acadêmico. Não ativar o caminho padrão
CKEditor AI e não aplicar patches diretamente em contrib/vendor.

Endpoint TDS deve exigir POST, CSRF, permissão e acesso de edição à entidade salva;
bundle/field determinados no servidor. Apenas seleção explícita,4000 caracteres,
512 tokens,10 tentativas/editor/hora e uma chamada concorrente. Transporte
injetável com endpoint/modelo fixos, stream:false, timeout, redirectsfalse e sem
retry automático. Não registrar mensagem de exceção upstream nem payload.
Resposta não salva/publica: usuário aceita sugestão manualmente. Quota precisa
reserva atômica, não apenas Flood isAllowed seguido de register sem exclusão.

Essa implementação ainda é TARGET. Provar tudo com fake e rede bloqueada antes
de chave editorial, orçamento, política de retenção e teste real autorizado.
