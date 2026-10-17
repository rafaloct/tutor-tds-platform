# LearnPress → Tutor TDS: ponte segura de mídias

Issue: https://github.com/rafaloct/tutor-tds-platform/issues/216

Status do código: candidato local, sem deploy e sem publicação editorial.

## Base observada em 16-17/10/2026

- Auditoria WP/LearnPress: 45 lições com IDs existentes, MP4, VTT, poster e duração, em 9 cursos; 12 aulas IA já vinculadas ao currículo WP 614.
- YouTube não listado: 10 de 45 vídeos enviados até o início de 17/10, 35 pendentes; tarefa diária LARGeo às 13h.
- Dos 10 uploads, somente o piloto SAF 1425 tem competency_id e followup_activity_id preenchidos no mapa atual.
- Vídeo piloto 1425: YouTube FG14ksTaMCE, mídia de staging d166f3b7-7f46-4e3e-bff5-8a340e87d1a9; playback em emulador aprovado em 16/10.
- Banco produção auditado em 16/10: media_assets vazio, só instituição/programa QA e uma oferta QA. Nunca usar QA como linhagem real.
- Em 17/10 o domínio ead.ipexdesenvolvimento.cloud sofreu timeout em três computadores; a integração WPVibe confirmou resposta Cloudflare HTTP 522 às 10:57:54Z. DNS e conexão TCP 443 existiam, mas a origem não respondeu. A causa interna permanece desconhecida.

## Contrato do candidato

O script api/ops/sync_learnpress_media.py transforma snapshot LearnPress + mapa de entrega YouTube + revisão humana opcional em payloads compatíveis com POST /admin/media.

- Modo padrão: dry-run local, sem chamadas à rede.
- Rejeita lesson IDs duplicados, asset de provedor reutilizado entre lições, fonte imprevista, lição não publicada, upload ausente, videoId inválido e IDs pedagógicos vazios.
- As 12 aulas IA exigem aprovação explícita do module_id; a sugestão module_id_proposed não aprova o currículo.
- Preserva rights_confirmed=false, offline_policy=forbidden, visibility=enrolled salvo escolha explícita no mapa.
- Modo --execute: uma lição por chamada, HTTPS fixo de staging, reconsulta estrutural read-only dos nove currículos LearnPress antes de qualquer POST, ambiente confirmado na rota /version, linhagem completa e credenciais privadas por variáveis de ambiente. HTTP 522, ausência, reordenação ou alteração da grade impedem o POST.
- Não chama publish, não altera CourseVersion, WordPress, matrícula, frequência nem certificado.
- Checkpoint atômico vinculado à URL e fingerprint do payload. HTTP 409 registra conflito, sem afirmar sucesso.

O importador trabalha sobre o manifesto auditado e ainda não equivale a um sincronizador contínuo. O verificador `api/ops/verify_learnpress_curriculum.py` consulta apenas os endpoints públicos GET LearnPress de cada curso, compara IDs, seções, ordem e títulos das 33 aulas verificadas. Não acessa `post_content` privado, não comprova hashes/duração dos MP4 atuais nem alterações textuais dentro da mesma aula. O próximo passo para delta completo requer exportação incremental autenticada do conteúdo, revisão do instrutor, draft, aprovação coordenador e inclusão em CourseVersion via fluxo editorial.

## Conferência sem escrita no LARGeo

No PowerShell, execute cada linha:

    $repo = 'D:\AI-Shared\work\tds-issue216-learnpress-media'
    $audit = 'D:\AI-Shared\work\tds-wp-app-media-audit-20261016'
    py -3.13 "$repo\api\ops\sync_learnpress_media.py" --manifest "$audit\learnpress_to_tutor_tds_manifest_v2.json" --delivery "$audit\delivery_map.json"

Este comando não precisa de CPF/senha nem conectividade. Para verificar a estrutura do LearnPress quando o HTTP voltar, use um GET auditado, somente leitura:

    py -3.13 "$repo\api\ops\verify_learnpress_curriculum.py" --manifest "$audit\learnpress_to_tutor_tds_manifest_v2.json"

O resultado precisa indicar status PASS e 9 cursos/45 lições. Caso o site responda 522, a conferência é BLOCKED e nenhuma importação deve ocorrer. Com revisão pedagógica aprovada, o arquivo externo de review pode usar a estrutura abaixo:

    {
      "1396": {
        "approved": true,
        "module_id": "tipos",
        "competency_id": "id_real_aprovado",
        "followup_activity_id": "id_atividade_real"
      }
    }

IDs de exemplo não são prova de revisão; aprovação de módulo não substitui atestação nominal de direitos.

## Criar rascunho somente em staging após novos gates

Verificar HTTPS online, creator ativo, ProgramCourse existente, instituição e programa QA e ausência de asset prévio. Configurar TDS_ADMIN_CPF e TDS_ADMIN_PASSWORD em ambiente privado. Nunca registrar credenciais em argv/chat/commit.

    $env:TDS_INSTITUTION_ID='staging-qa-institution'
    $env:TDS_PROGRAM_ID='staging-qa-program'
    $env:TDS_CREATOR_USER_ID='staging-qa-admin'
    py -3.13 "$repo\api\ops\sync_learnpress_media.py" --manifest "$audit\learnpress_to_tutor_tds_manifest_v2.json" --delivery "$audit\delivery_map.json" --lesson-id 1425 --execute --state "$audit\sync-staging-state.json"

ATENÇÃO: #1425 já está publicado em staging; a linha mostra a interface, não autoriza duplicação. Um HTTP 409 exige reconciliação do ID e do checkpoint, nunca mudança artificial do provider_asset_id.

## Gates e reversão

- HUMAN_GATE=NO para código, testes, inventário offline.
- HUMAN_GATE=YES para instituição/programa reais, 9 vínculos de oferta, responsáveis reais, atestação de direitos, publicação e edição de CourseVersion.
- API visibility=unlisted não corresponde a vídeo YouTube não listado: o catálogo da API exclui unlisted.
- A versão Android candidata reproduziu o YouTube em staging, mas a distribuição dessa feature pela Play Store ainda precisa de prova.
- Upload/playback/eventos não criam matrícula, presença ou certificado.
- Rollback do código: retirar ponte da branch. Rascunhos staging exigem arquivamento por editor autorizado via API. Nenhuma migration nem escrita em produção.

## Testes

    Set-Location 'D:\AI-Shared\work\tds-issue216-learnpress-media\api'
    py -3.13 -m unittest discover -s tests -p test_sync_learnpress_media.py -v
    py -3.13 -m unittest discover -s tests -p test_verify_learnpress_curriculum.py -v
    py -3.13 -m py_compile ops\sync_learnpress_media.py ops\verify_learnpress_curriculum.py
    git diff --check

Aceite em produção exige HTTPS real, revisão dos 9 cursos, avaliação das lições LearnPress atuais, reconciliação sem duplicata, smoke de app distribuído, backup/rollback.
