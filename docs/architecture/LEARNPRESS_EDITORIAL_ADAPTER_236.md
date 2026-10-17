# Tutor TDS / LearnPress: adaptador editorial dinâmico v0.1

**Issue**: [#236](https://github.com/rafaloct/tutor-tds-platform/issues/236). **Status**: candidato em branch isolada para testes, **não instalado no WordPress real**.

## Papel

Este plugin WordPress apenas **projeta a fonte editorial LearnPress** para consumo móvel. Não replica arquivos ou estrutura acadêmica em tabelas próprias, não altera grade, conteúdo, matrícula, nota, certificado, inscrição ou papéis.

- Fonte: posts nativos `lp_course`, `lp_lesson`, `lp_quiz` e a API interna pública do LearnPress `GET /learnpress/v1/courses/{id}` via `rest_do_request()` (sem loopback HTTP, secrets ou cache de DB duplicado).
- Endpoints novos (após instalação/ativação autorizada): `GET /wp-json/tds-learning/v1/courses/{id}/curriculum` e `GET /wp-json/tds-learning/v1/courses/{id}/lessons/{lesson_id}`.
- Uma aula/quiz precisa estar **publicada** e vinculada à grade de um curso `lp_course` publicado. Conteúdo de lição só é exibido publicamente quando editor autorizado marca a checkbox **Publicar o texto desta aula no app para visitantes**. **Padrão: desmarcado.**
- HTML de lições públicas passa por `strip_shortcodes` + `wp_kses`, permitindo apenas parágrafos, títulos, listas, negrito, ênfase, citação e âncoras HTTPS. Não executa `the_content` ou shortcodes e não embute JavaScript.
- Vídeo só aparece se título da lição opt-in, YouTube ID válido **e** checkbox de autorização editorial/direitos. Alterar YouTube ID revoga automaticamente a aprovação e exige nova confirmação em outra gravação do editor.
- Poster/legenda VTT só podem usar HTTPS e o host oficial WordPress sob `wp-content/uploads`, com extensões esperadas.
- Quiz em seção: apenas id, título, revisão e link no mesmo domínio /quizzes/. **Não exporta questões, gabaritos, tentativas, notas, CPF, cookies ou dados de matriculados.**
- `ETag` SHA256 do payload público + header `Cache-Control: public, max-age=0, must-revalidate`; um `If-None-Match` idêntico retorna HTTP 304. Renovar título, grade, vídeo, checkbox ou revisão muda o ETag, sem novo APK.

## Exemplo de consulta pública de outline (somente após aprovação de plugin)

`GET https://ead.ipexdesenvolvimento.cloud/wp-json/tds-learning/v1/courses/1356/curriculum`

Resposta esquemática (dados ilustrativos):

```json
{
  "schema_version": 1,
  "authority": "learnpress",
  "course_id": 1356,
  "title": "Sistemas Agroflorestais (SAF)",
  "sections": [
    {"id": 80, "title": "Assista em vídeo", "items": [
      {"id": 1425, "type": "lp_lesson", "title": "Aula SAF", "revision": "...", "mobile_content": false, "media": null}
    ]}
  ],
  "revision": "sha256(hex)"
}
```

**Importante**: conteúdo ilustrativo acima, não coletado do endpoint novo. Em uma instalação nova os vídeos e textos ficam omitidos até a aprovação de cada lição. GETs públicos atuais do LearnPress continuam funcionando.

## Como o instrutor configura no site (após instalação autorizada)

1. Abra a aula do curso no editor administrativo LearnPress.
2. No quadro **Tutor TDS: conteúdo no aplicativo**, revise se o texto pode ser mostrado publicamente; ative a checkbox apenas se não contiver material restrito nem dados pessoais.
3. Informe o videoId YouTube não listado/aprovado (11 caracteres), confirme direitos no quadro e salve. Na primeira alteração de ID, os direitos retornam para 'não aprovado'; inspecione a mídia e marque a checkbox novamente, em novo save.
4. Se houver poster ou VTT hospedado no WordPress, informe os links HTTPS locais para serem validados. A publicação do MP4 no YouTube é fluxo separado.
5. Para quiz, use o mecanismo nativo do LearnPress para **inserir quiz na seção publicada**; o plugin só refletirá sua presença, sem transmitir gabaritos.
6. Cliente Flutter reconsulta ao abrir/atualizar ou usa HTTP 304. Nada exige novo build quando o **conteúdo já tem autorização editorial e o adaptador está disponível**.

## Testes locais verificados

Na VM Linux isolada:

```bash
php -l wordpress/tds-learnpress-editorial/tds-learnpress-editorial.php
php -l wordpress/tds-learnpress-editorial/includes/class-tds-learnpress-editorial.php
php -l wordpress/tds-learnpress-editorial/includes/class-tds-learnpress-editorial-admin.php
php wordpress/tds-learnpress-editorial/tests/test-contract.php
```

O harness sem banco simula WordPress/LP REST e valida autorização/nonce, quiz sem gabarito, exclusão de draft, publicação opt-in, direitos, ETag 200/304, mudança de título, exclusão de lição da grade e rejeição de dados malformados. **Isso não substitui WordPress staging integrado e os testes Android reais.**

## Gates ainda abertos

- Fazer backup restaurável do WordPress e clone de staging com versão LearnPress/tema/plugins idênticos; instalar **somente no clone staging** para verificar hooks, metabox, GET e permissões.
- Testar com curso SAF e quiz sintético em staging para comprovar inclusão/exclusão, ETag, 304, 401/403 por papéis, HTML, YouTube, poster e VTT sem exposições indevidas.
- Auditoria atual: 29 quizzes e 282 questões existentes, nenhum quiz inserido nas grades publicadas; não associar automaticamente por título, ordem ou similaridade.
- Flutter ainda não lê os dois endpoints deste plugin; o PR #237 oferece apenas grade e links de quiz nativos do LearnPress. A próxima fatia Flutter precisa consumir o JSON deste adaptador para realmente atualizar **textos e mídias**. Não declarar integração completa antes disso.
- Definir política de acesso de lições *enrolled-only* e identidade/SSO, se forem para renderização dentro do app. Esta v0.1 é exclusivamente conteúdo **explicitamente marcado público**. Não copiar quizzes autenticados nem emitir notas via clique.
- Aprovadores precisam verificar direitos, CORS/SSL, privacidade, política de cache e rollback; produção depende de autorização humana específica.

## Reversão

Esta entrega são arquivos novos no Git, não há migração ou mutação no WP. Desativar o plugin no staging retorna os endpoints novos a 404 e preserva LearnPress, sem afetar o site. Dados de meta opt-in não são destruídos ao desativar; reativação só após nova inspeção editorial.

**MERGE_ALLOWED=NO; WP_PRODUCTION_INSTALL=NO.**

## Homologação adicional com WordPress e LearnPress reais, sem produção (17/10/2026)

- Ambiente **isolado** na VM L4, servidor HTTP acessível somente por `127.0.0.1:18731`, WordPress **6.7.2**, LearnPress **4.3.6**, PHP 8.3 e SQLite Database Integration **3.1.0**. Conteúdo totalmente **sintético**: um curso SAF, duas aulas (uma privada) e um quiz sintético. Não se utilizou banco, credenciais ou matrículas da produção.
- Plugin instalado/ativado neste WordPress sintético, e a API interna original `GET /learnpress/v1/courses/{id}` respondeu **HTTP 200** com seção e itens reais do LMS.
- Um roteiro `wp-cli eval-file` verificou **27/27 condições PASS** no WP real: metadados e ordem, ocultação de draft, opt-in público, permissões de edição, confirmação/revogação de direitos, sanitização, ETag 304, atualização de texto sem recompilar, retirada de aula da grade e bloqueio de curso privado.
- No servidor HTTP loopback: `GET /tds-learning/v1/courses/11/curriculum` **200**, mesmo ETag com `If-None-Match` **304**, aula 12 autorizada **200** e aula 13 privada **404**. A resposta de aula foi verificada sem script ou shortcode não registrado; continha apenas material sintético e YouTube ID previamente aprovado.
- **Correção de segurança descoberta pela homologação real:** `wp_kses` retirava a tag `script` mas podia deixar seu texto. Commit de correção `5093b9b` retira o elemento ativo inteiro antes da sanitização e também elimina tags de shortcode não registradas. Os testes reais passaram após a correção.
- O WordPress sintético exigiu conceder ao **administrador de QA** as capacidades próprias `edit_lp_lesson`, `edit_lp_lessons`, `edit_others_lp_lessons` e `edit_published_lp_lessons` para exercitar a metabox. Isso foi feito exclusivamente no SQLite sintético, sem mudar permissões de produção.
- O projeto Flutter recebeu, no ramo do PR #240, fixtures JSON extraídas dessas respostas HTTP reais. Testes de contrato/frontend passaram para curso, texto e ETag; não se expuseram gabaritos.

**Limites:** SQLite não representa a compatibilidade com MySQL/MariaDB e os demais plugins do EAD de produção. Ainda é necessária homologação de staging **com MariaDB e plugins correspondentes**, inspeção de roles de instrutor, CORS, mídia, HTTPS e restauração. O localhost foi encerrado ao terminar os testes e nunca recebeu acesso público. **Não instalar ou publicar o plugin em produção sem gate humano.**
