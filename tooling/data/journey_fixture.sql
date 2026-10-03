-- Synthetic overlay only; these are not production schema or migrations.
PRAGMA foreign_keys = ON;

CREATE TABLE participants (
    pessoa_id TEXT NOT NULL,
    turma_id TEXT NOT NULL,
    registro_id TEXT UNIQUE,
    status_vinculo TEXT NOT NULL CHECK (status_vinculo IN (
        'confirmed', 'bi_link_pending',
        'enrollment_lineage_changed', 'bi_link_inconsistent'
    )),
    PRIMARY KEY (pessoa_id, turma_id),
    UNIQUE (registro_id, pessoa_id, turma_id),
    CHECK ((status_vinculo = 'confirmed' AND registro_id IS NOT NULL)
        OR (status_vinculo <> 'confirmed' AND registro_id IS NULL))
);

CREATE TABLE journey (
    registro_id TEXT PRIMARY KEY NOT NULL,
    pessoa_id TEXT NOT NULL,
    turma_id TEXT NOT NULL,
    curso_id TEXT NOT NULL,
    curso_versao_id TEXT NOT NULL,
    matricula_contextual_id TEXT NOT NULL UNIQUE,
    horas_estudo_validadas REAL NOT NULL CHECK (horas_estudo_validadas >= 0),
    certificado_flag INTEGER CHECK (certificado_flag = 1),
    certificado_emitido_em TEXT,
    FOREIGN KEY (registro_id, pessoa_id, turma_id)
        REFERENCES participants (registro_id, pessoa_id, turma_id),
    CHECK ((certificado_flag IS NULL AND certificado_emitido_em IS NULL)
        OR (certificado_flag IS NOT NULL AND certificado_flag = 1
            AND certificado_emitido_em IS NOT NULL))
);

CREATE TABLE activity (
    event_id TEXT NOT NULL,
    pessoa_id TEXT NOT NULL,
    evento TEXT NOT NULL,
    alvo_tipo TEXT NOT NULL,
    alvo_id TEXT NOT NULL,
    ocorreu_em TEXT NOT NULL,
    segundos_tela INTEGER,
    escopo TEXT NOT NULL CHECK (escopo = 'conta_autenticada'),
    atribuicao_turma TEXT CHECK (atribuicao_turma IS NULL),
    CHECK ((evento = 'screen_engagement' AND segundos_tela IS NOT NULL
            AND segundos_tela BETWEEN 1 AND 60)
        OR (evento IN ('page_viewed', 'feature_used', 'resource_opened')
            AND segundos_tela IS NULL))
);

INSERT INTO participants VALUES
    ('SYN-P01', 'SYN-T01', 'SYN-B01', 'confirmed'),
    ('SYN-P01', 'SYN-T02', 'SYN-B02', 'confirmed'),
    ('SYN-P02', 'SYN-T01', NULL, 'bi_link_pending'),
    ('SYN-P03', 'SYN-T02', NULL, 'enrollment_lineage_changed');

INSERT INTO journey VALUES
    ('SYN-B01', 'SYN-P01', 'SYN-T01', 'SYN-C01', 'SYN-V01',
        'SYN-M01', 1.0, 1, '2026-09-01T12:00:00Z'),
    ('SYN-B02', 'SYN-P01', 'SYN-T02', 'SYN-C01', 'SYN-V02',
        'SYN-M02', 2.0, NULL, NULL);

INSERT INTO activity VALUES
    ('SYN-E01', 'SYN-P01', 'screen_engagement', 'page_id', 'home',
        '2026-10-01T23:00:00-03:00', 30, 'conta_autenticada', NULL),
    ('SYN-E01', 'SYN-P01', 'screen_engagement', 'page_id', 'home',
        '2026-10-01T23:00:00-03:00', 30, 'conta_autenticada', NULL),
    ('SYN-E02', 'SYN-P01', 'page_viewed', 'page_id', 'home',
        '2026-10-02T10:00:00Z', NULL, 'conta_autenticada', NULL),
    ('SYN-E03', 'SYN-P02', 'screen_engagement', 'page_id', 'study_hub',
        '2026-10-02T11:00:00Z', 15, 'conta_autenticada', NULL),
    ('SYN-E04', 'SYN-P03', 'feature_used', 'feature_id', 'course_pdf_open_requested',
        '2026-10-02T12:00:00Z', NULL, 'conta_autenticada', NULL),
    ('SYN-E05', 'SYN-P04', 'page_viewed', 'page_id', 'home',
        '2026-10-02T12:00:00Z', NULL, 'conta_autenticada', NULL),
    ('SYN-E06', 'SYN-P01', 'page_viewed', 'page_id', 'home',
        '2026-10-01T00:00:00Z', NULL, 'conta_autenticada', NULL),
    ('SYN-E07', 'SYN-P01', 'page_viewed', 'page_id', 'home',
        '2026-10-03T00:00:00Z', NULL, 'conta_autenticada', NULL);
