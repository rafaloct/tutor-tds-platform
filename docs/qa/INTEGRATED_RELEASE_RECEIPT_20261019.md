# Recibo do candidato integrado IPEX — 19/10/2026

Escopo: integração local dos PRs #292 e #295, testes focais e AAB não assinado
para inspeção. Nenhum merge de PR, deploy, produção, chave real ou Play Store.

## Proveniência

| Campo | Valor |
| --- | --- |
| candidato integrado | `c853db021368f4b536521800ed9dc33ef68e3aac` |
| árvore Git | `8a9fb19a59ffe1c0ea3099cc287aa801739abb39` |
| pai #295 + recibos | `2d61805a982643c6ec16b4275d6f7f7633baa26b` |
| pai #292 | `e8b60569e36da42b0cf11e98e4adced3da6631d6` |
| branch | `agent/release-candidate-ipex-integrated-20261019` |
| worktree | `D:\AI-Shared\work\tds-release-candidate-ipex-integrated-20261019` |
| lockfile SHA-256 | `3E044DE97EA5EABE70563B12D84345DC685192241185F64AC964A23186DE1BFE` |

O merge `--no-ff` preserva os dois históricos e não teve conflito. O delta do
#292 adiciona somente o teste/recibo WordPress runtime; não sobrepõe arquivos da
cadeia #293/#295.

## AAB de inspeção

- caminho estável:
  `D:\AI-Shared\builds\tutor-tds\release-candidate-c853db021368f4b536521800ed9dc33ef68e3aac\Tutor-TDS-1.4.0+13-c853db0-inspection-unsigned.aab`
- SHA-256: `F671CC61BDDEB7CD45D3E7953F98CD4A85F44B1A34B274AE0D6E3FA453776ADC`
- tamanho: 68.474.022 bytes; 426 entradas.
- package `com.tutortds_cartilhas`, versionName `1.4.0`, versionCode `13`,
  minSdk 24, targetSdk 36, compileSdk 36.
- ABIs: arm64-v8a, armeabi-v7a e x86_64; cada ABI contém `libapp.so` e
  `libflutter.so`.
- `jarsigner -verify`: `jar is unsigned`; `key.properties` ausente. O artefato
  é deliberadamente **NOT_FOR_UPLOAD**.

O build foi executado pelo `flutter_tools.snapshot` do Flutter 3.44.9 porque o
`flutter.bat` do host entra em loop sem processo Dart filho até em `pub get`.
Em worktree limpa, o fluxo direto regenerou o registrant e o Gradle compilou Java
e Kotlin sem o erro dev-only observado na worktree anterior. Portanto não há
defeito de código confirmado no player ou no runner versionado; o bloqueio
anterior foi estado gerado contaminado combinado ao wrapper local.

Foi usado `config/production.example.json`, validado pelo verificador. O scan dos
`libapp.so` encontrou os endpoints aprovados da API e gateway e não encontrou
URL localhost, `10.0.2.2`, staging ou sufixo `dynamicqa`. Bibliotecas genéricas
do Flutter contêm palavras como localhost, portanto a conclusão é limitada ao
binário da aplicação. Nomes de flags QA não foram encontrados. O sentinel
fail-closed `https://tutor-tds.invalid` continua intencionalmente presente.

## Testes integrados

| Gate | Resultado |
| --- | --- |
| merge #292 + #295 | PASS, sem conflito |
| contrato editorial PHP | 63/63 PASS |
| lint PHP | quatro arquivos PASS |
| runtime WordPress completo | PASS local; prova #292 reutilizada e nova instalação limpa executada |
| LearnPress real sintético | 76/76 PASS; WP 7.1.2 + LP 4.3.6, rota/modelos/CURD/hooks reais |
| Flutter player | 9/9 PASS |
| analyze focal | PASS, zero issues |
| preflight estrutural | 3/3 PASS; `structural_pass=true` |
| config de produção | PASS |
| lockfile | preservado antes/depois do build |
| AAB | PASS para inspeção; não assinado |

O PHP disponível no LARGeo emitiu warnings preexistentes de configuração
(`mysqli` duplicado e `pdo_firebird` ausente), mas o contrato, os quatro lints e
a prova final LearnPress retornaram exit 0. A nova prova não registrou rota
simulada: criou curso/seção/aulas pelos tipos e CURD do LearnPress e consumiu a
rota nativa. Log SHA-256
`40E949E804342D284047A5A2F7AB7DCCB47388F7F3BBB78FB563464C51CF1D5B`;
recibo em `ead-learnpress-real-integrated-20261019/README.md`.

## Gates restantes

1. revisão humana da cadeia e decisão de manter os PRs stacked ou consolidar;
2. TalkBack falado e áudio acústico;
3. homologação institucional do WordPress/LearnPress, sem confundi-la com a
   instalação sintética já aprovada;
4. build oficial com `config/production.json` custodiado, assinatura de upload e
   verificador de readiness somente após autorização;
5. upload em Teste interno/Play e promoção requerem autorização específica.

O AAB versionado antigo continua superseded. Este AAB não altera
`release_status.json`, não é candidato de upload e não libera produção.
