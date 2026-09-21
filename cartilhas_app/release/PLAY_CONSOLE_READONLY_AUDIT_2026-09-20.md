# Auditoria somente leitura da Play Console — 20/09/2026

Escopo: inventário de versões, trilhas e mudanças pendentes do app
`com.tutortds_cartilhas`. Nenhum arquivo foi enviado, nenhuma versão foi
criada/editada, nenhuma mudança foi submetida e nenhuma trilha foi pausada ou
promovida.

> Esta disponibilidade de `versionCode 13` **não libera o AAB local existente**.
> O hash `B93FAD21…B2844B66` está superseded/não uploadável após a mudança de
> Evidence offline. O freeze em `release/release_status.json` exige reteste no
> Xiaomi, novo rebuild e verificador local `READY` antes de qualquer upload.

## Versões e pacotes observados

| Superfície | Estado observado |
|---|---|
| Produção | `betav0.2`, código `11`, nome `1.2.0`, lançamento completo em 25/08/2026, 100% |
| Pacote mantido em produção | código `2`, nome `1.1.0` |
| Teste fechado Alpha | `betav0.1`, código `2`, lançamento completo |
| Teste interno | `betav0.1`, código `2`, faixa inativa |
| Pacotes mais recentes | somente códigos `11` e `2` |

Conclusão verificável nesta fotografia: **o `versionCode 13` não aparece entre
os pacotes enviados e está disponível para o novo candidato**, desde que outra
pessoa não faça upload antes da submissão planejada. Esse fato deve ser
revalidado imediatamente antes do upload.

O pacote produtivo `11 (1.2.0)` declara mínimo API 24 e target API 36. A página
mostrou 16 instalações e nenhuma métrica suficiente de crash/ANR.

## Estado que não deve ser enviado por acidente

- A visão geral de publicação contém **uma mudança ainda não enviada para
  revisão**: testadores do `Teste fechado - App` definidos pelo Grupo do Google
  já configurado na conta.
- `Teste fechado - App` aparece como rascunho sem versão/pacote próprio,
  sincronizado com produção.
- A faixa Alpha antiga aparece como candidata a pausa por estar superada pela
  produção há mais de 90 dias. Nenhuma pausa foi executada.
- A Play ainda mostra recomendação de revisão de edge-to-edge para o artefato
  publicado. O novo candidato deve manter o gate físico em Android 15+.

Antes do upload do AAB 1.4, revisar explicitamente a mudança pendente para não
enviá-la junto por engano. O upload deve ocorrer primeiro em **Teste interno**;
o botão de envio à revisão e qualquer promoção permanecem ações humanas
separadas.

## Limites desta evidência

Esta leitura não valida chave de upload, Data Safety, política, classificação,
relatório de pré-lançamento nem comportamento do novo AAB. Ela prova apenas o
estado visível das versões/trilhas no momento da inspeção e não substitui a
revalidação imediatamente anterior ao upload.
