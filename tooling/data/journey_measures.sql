-- SQLite reference over the synthetic fixture, not a production BI adapter.
-- Validate replay with daily_activity before querying these raw activity rows.
WITH
visible_people AS (
    SELECT DISTINCT pessoa_id FROM participants
),
visible_activity AS (
    SELECT DISTINCT a.*
    FROM activity AS a
    WHERE EXISTS (
        SELECT 1 FROM visible_people AS p WHERE p.pessoa_id = a.pessoa_id
    )
        AND julianday(a.ocorreu_em) >= julianday(:since)
        AND julianday(a.ocorreu_em) < julianday(:until)
),
linked_journey AS (
    SELECT j.*
    FROM journey AS j
    JOIN participants AS p
        ON p.pessoa_id = j.pessoa_id
        AND p.turma_id = j.turma_id
        AND p.registro_id = j.registro_id
    WHERE p.status_vinculo = 'confirmed'
),
counts AS (
    SELECT
        COUNT(*) AS participacoes,
        COUNT(DISTINCT pessoa_id) AS pessoas,
        COUNT(CASE WHEN status_vinculo = 'confirmed' THEN 1 END) AS confirmados,
        COUNT(CASE WHEN status_vinculo = 'bi_link_pending' THEN 1 END) AS pendentes,
        COUNT(CASE WHEN status_vinculo IN (
            'enrollment_lineage_changed', 'bi_link_inconsistent'
        ) THEN 1 END) AS inconsistentes
    FROM participants
)
SELECT 'pessoas_snapshot' AS medida, pessoas AS valor, NULL AS denominador
FROM counts
UNION ALL
SELECT 'participacoes_snapshot', participacoes, NULL FROM counts
UNION ALL
SELECT 'vinculos_bi_confirmados', confirmados, NULL FROM counts
UNION ALL
SELECT 'vinculos_bi_pendentes', pendentes, NULL FROM counts
UNION ALL
SELECT 'vinculos_bi_inconsistentes', inconsistentes, NULL FROM counts
UNION ALL
SELECT 'cobertura_vinculo_percentual',
    100.0 * confirmados / NULLIF(participacoes, 0), participacoes FROM counts
UNION ALL
SELECT 'horas_estudo_snapshot', COALESCE(SUM(horas_estudo_validadas), 0), NULL
FROM linked_journey
UNION ALL
SELECT 'referencias_certificado_api',
    COUNT(CASE WHEN certificado_flag = 1 THEN 1 END), NULL FROM linked_journey
UNION ALL
SELECT 'certificado_desconhecido',
    COUNT(CASE WHEN certificado_flag IS NULL THEN 1 END), NULL FROM linked_journey
UNION ALL
SELECT 'pessoas_com_atividade', COUNT(DISTINCT pessoa_id), NULL
FROM visible_activity
UNION ALL
SELECT 'eventos_conta_janela', COUNT(*), NULL FROM visible_activity
UNION ALL
SELECT 'segundos_tela_janela',
    COALESCE(SUM(CASE WHEN evento = 'screen_engagement'
        THEN segundos_tela ELSE 0 END), 0), NULL FROM visible_activity
UNION ALL
SELECT 'capacitados', NULL, NULL
UNION ALL
SELECT 'elegiveis_mentoria', NULL, NULL
UNION ALL
SELECT 'followup_30d_concluido', NULL, NULL;
