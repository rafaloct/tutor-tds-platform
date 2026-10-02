let
    Source = GoogleSheets.Contents("https://docs.google.com/spreadsheets/d/1MNM2QgA8xbneQoBFmlsbP7kgOIdGoh5wD_w8tIRP5TE/edit"),
    Raw = Table.PromoteHeaders(Source{[name="TDS_JORNADA_APP", ItemKind="Table"]}[Data], [PromoteAllScalars=true]),
    Filtered = Table.SelectRows(Raw, each [registro_id] <> null and Text.Trim(Text.From([registro_id])) <> ""),
    Typed = Table.TransformColumnTypes(Filtered, {{"registro_id", type text}, {"pessoa_id", type text}, {"turma_id", type text}, {"programa_id", type text}, {"curso_id", type text}, {"curso", type text}, {"curso_versao_id", type text}, {"matricula_contextual_id", type text}, {"status_baseline", type text}, {"vinculo_revisao", Int64.Type}, {"vinculo_conferido_em", type datetimezone}, {"carga_horaria_prevista", type number}, {"horas_estudo_validadas", type number}, {"progresso_estudo_percentual", type number}, {"certificado_flag", Int64.Type}, {"certificado_emitido_em", type datetimezone}, {"certificado_cobertura", type text}, {"data_ultima_interacao", type datetimezone}, {"interacoes_qtd", Int64.Type}, {"status_qualidade", type text}, {"atualizado_em", type datetimezone}}, "en-US"),
    DuplicateCount = Table.RowCount(Typed) - Table.RowCount(Table.Distinct(Typed, {"registro_id"})),
    Unknown = List.Difference(List.Distinct(Typed[registro_id]), List.Distinct(Baseline[registro_id])),
    Checked = if DuplicateCount <> 0 then error "Inscrições duplicadas no rastreio: conferir vínculos antes de atualizar."
              else if List.Count(Unknown) <> 0 then error "Inscrição do Tutor não existe no baseline: conferir a ponte."
              else Typed,
    Dates = Table.TransformColumns(Checked, List.Transform({"vinculo_conferido_em", "certificado_emitido_em", "data_ultima_interacao", "atualizado_em"}, (column) => {column, (value) => if value = null then null else DateTimeZone.RemoveZone(DateTimeZone.ToUtc(value)), type nullable datetime}))
in
    Dates
