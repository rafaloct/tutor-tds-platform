# Issue #308 — handoff editorial e piloto 1420

Estado observado em 20/10/2026. Esta nota concilia decisões posteriores da [Issue #308](https://github.com/rafaloct/tutor-tds-platform/issues/308) com o ensaio original deste diretório; não altera conteúdo, permissões ou publicação.

| Gate | Estado e evidência |
| --- | --- |
| Pares MP4/VTT | **TESTED-LOCAL 48/48** em nove cursos: hashes, codec, duração, HTTP/Range, VTT e vínculo ao inventário. A [matriz e hashes](https://github.com/rafaloct/tutor-tds-platform/issues/308#issuecomment-6293103585) ficam no recibo do LARGeo. Isso não aprova pedagogia. |
| Android Samsung SM-T835/API 29 | **PASS automatizado**: após a tentativa inicial `BLOCKED_NETWORK`, HTTPS e Range funcionaram; abertura fria/quente, 35 cues, legendas e 120 s com avanço temporal/frames passaram. APK do commit `6f01ee4`, SHA-256 `2085B5844270E737073E1004D0238921FF9B97998F069522BDC1F79BF8339F7D`. [Recibo e limites](https://github.com/rafaloct/tutor-tds-platform/issues/308#issuecomment-6294035405). |
| Áudio no Samsung | **CONFIRMADO por declaração humana**: narração ouvida diretamente no aparelho. Não equivale a revisão pedagógica completa. [Atestação](https://github.com/rafaloct/tutor-tds-platform/issues/308#issuecomment-6304593770). |
| Controles por toque | **CONFIRMADO por declaração humana**: pausa e retomada no player QA. [Atestação](https://github.com/rafaloct/tutor-tds-platform/issues/308#issuecomment-6304652109). |
| TalkBack | **PENDING**: operador precisa ativar o leitor de tela e confirmar anúncio e acionamento dos controles de vídeo e legendas. Não repetir gate de áudio ou pausa/retomada sem regressão nova. |
| Decisão pedagógica | **PENDING 48/48**: nove pacotes por curso e fichas por aula preparados; cada instrutor deve registrar decisão individual por versão/hash. A revisão dos 47 pares restantes pode ocorrer em paralelo por curso. |
| Publicação | **NO 48/48** no readback registrado; aula 1420 revertida, currículo sem mídia e endpoint da aula 404. Nenhuma declaração humana acima altera flags. |

## Handoff da aula piloto 1420

Curso **1298 — Agricultura Sustentável**. No LARGeo, entregar ao instrutor a ficha `D:/AI-Shared/test-results/tutor-tds/issue308-transition-20261020/lesson1420-instructor-approval.md` e a ficha individual `review-packages/1298/aulas/1420.md`, com as fontes de cartilha/roteiro ali indicadas. Revisar as seis cenas e o vídeo completo: afirmações, imagens, narração real, VTT e sincronismo. Registrar nome/função, data, ressalvas por timecode e decisão explícita para estes hashes:

- MP4 SHA-256 `8bfcae0f98cd18175399fe5861c96b23b0ad6d523891823adf87fd455d021431`;
- VTT SHA-256 `515119b65c4e3c86b00345d075f40efcc54e114157320e1356b8e7254fb9fb42` (35 cues);
- conteúdo LearnPress SHA-256 `cb5e79c4bd6a9c4bae86664d3675e8cd3e1fa7ada769f602a2bf73122084f14d`;
- fingerprint editorial `0b2b5bfa36ba53b5b0c99cc8f8951ca99e70d76af7f131fc775998fed8e7f5c8`.

**HUMAN GATES restantes para o piloto:** atestação TalkBack, decisão pedagógica assinada para a aula 1420, decisão sobre o risco da intermitência antiga de tempo zero ainda sem causa demonstrada, revisão/integração humana da cadeia #307 → #310 → #311 e autorização operacional específica do responsável para publicar **somente** a 1420 com janela, backup, readback, Android E2E, revogação e rollback. O [roteiro do piloto](https://github.com/rafaloct/tutor-tds-platform/issues/308#issuecomment-6293103585) permanece preparado. Nenhuma das outras 47 aulas recebe autorização por esse piloto.
