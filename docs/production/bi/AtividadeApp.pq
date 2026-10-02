let
    Source = GoogleSheets.Contents("https://docs.google.com/spreadsheets/d/1MNM2QgA8xbneQoBFmlsbP7kgOIdGoh5wD_w8tIRP5TE/edit"),
    Raw = Table.PromoteHeaders(Source{[name="TDS_ATIVIDADE_APP", ItemKind="Table"]}[Data], [PromoteAllScalars=true]),
    Filtered = Table.SelectRows(Raw, each [pessoa_id] <> null and Text.Trim(Text.From([pessoa_id])) <> ""),
    Keep = Table.SelectColumns(Filtered, {"pessoa_id", "data_utc", "evento", "alvo_tipo", "alvo_id", "eventos_qtd", "segundos_tela", "escopo"}),
    Typed = Table.TransformColumnTypes(Keep, {{"pessoa_id", type text}, {"data_utc", type date}, {"evento", type text}, {"alvo_tipo", type text}, {"alvo_id", type text}, {"eventos_qtd", Int64.Type}, {"segundos_tela", Int64.Type}, {"escopo", type text}}, "en-US"),
    DuplicateCount = Table.RowCount(Typed) - Table.RowCount(Table.Distinct(Typed, {"pessoa_id", "data_utc", "evento", "alvo_tipo", "alvo_id"})),
    Unknown = List.Difference(List.Distinct(Typed[pessoa_id]), List.Distinct(ParticipantesApp[pessoa_id])),
    Checked = if DuplicateCount <> 0 then error "Resumo de atividade duplicado: importar snapshot integral, não anexar períodos sobrepostos."
              else if List.Count(Unknown) <> 0 then error "Pessoa sem matrícula no snapshot de participantes."
              else Typed,
    Names = [home="Início", welcome="Boas-vindas", onboarding="Apresentação", ai_assistant="Tutor", tutor="Tutor", study_hub="Ferramentas de estudo", classroom_course="Curso da turma", user_guide="Como usar", support="Atendimento", videos="Vídeos", video_player="Vídeo", certificate_wallet="Carteira de certificados", certificate_details="Certificado", certificate_requests="Solicitações de certificado", certificate_review="Conferência de certificado", profile="Perfil", settings="Configurações", privacy_consent="Autorização de acompanhamento", privacy_policy="Privacidade", flashcards="Cartões de estudo", assessment="Avaliação", summary="Resumo", classroom_roster="Alunos da turma", content_catalog="Catálogo", course_editor="Editor de curso", course_editor_preview="Prévia de curso", evidence_cockpit="Acompanhamento", glossary="Glossário", guided_lesson="Estudo guiado", session_presence="Frequência", student_followup="Acompanhamento do aluno"],
    Named = Table.AddColumn(Checked, "nome_tela", each if [alvo_tipo] = "page_id" then Record.FieldOrDefault(Names, [alvo_id], "Outra tela") else null, type nullable text)
in
    Named
