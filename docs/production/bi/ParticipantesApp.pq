let
    Source = GoogleSheets.Contents("https://docs.google.com/spreadsheets/d/1MNM2QgA8xbneQoBFmlsbP7kgOIdGoh5wD_w8tIRP5TE/edit"),
    Raw = Table.PromoteHeaders(Source{[name="TDS_PARTICIPANTES_APP", ItemKind="Table"]}[Data], [PromoteAllScalars=true]),
    Keep = Table.SelectColumns(Raw, {"pessoa_id", "turma_id", "registro_id", "status_vinculo"}),
    Typed = Table.TransformColumnTypes(Keep, {{"pessoa_id", type text}, {"turma_id", type text}, {"registro_id", type text}, {"status_vinculo", type text}}),
    Filtered = Table.SelectRows(Typed, each [pessoa_id] <> null and Text.Trim([pessoa_id]) <> ""),
    DuplicateCount = Table.RowCount(Filtered) - Table.RowCount(Table.Distinct(Filtered, {"pessoa_id", "turma_id"})),
    Allowed = {"confirmed", "bi_link_pending", "enrollment_lineage_changed", "bi_link_inconsistent"},
    UnknownStatus = List.Difference(List.Distinct(Filtered[status_vinculo]), Allowed),
    Checked = if DuplicateCount <> 0 or List.Count(UnknownStatus) <> 0 then error "Participantes: conferir duplicatas e estado do vínculo."
              else Filtered,
    Labels = [confirmed="Vínculo conferido", bi_link_pending="Conferência pendente", enrollment_lineage_changed="Matrícula requer conferência", bi_link_inconsistent="Referência requer conferência"],
    Named = Table.AddColumn(Checked, "situacao_vinculo", each Record.Field(Labels, [status_vinculo]), type text)
in
    Named
