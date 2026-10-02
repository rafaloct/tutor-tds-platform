"""Create an additive PBIP candidate from the inspected local TDS template."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import shutil


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def stabilize_legacy_numeric_types(source):
    """Keep the inspected model's integer contract after M expands untyped records.

    Scope is the two legacy queries validated in Desktop, never source Sheets.
    Preserve nulls and let invalid values fail instead of replacing them by zero.
    """
    declarations, partition = source.split('\n\tpartition ', 1)
    columns = re.findall(r'^\tcolumn ([^\n]+)\n\t\tdataType: int64$',
                         declarations, re.MULTILINE)
    before, marker, result = partition.rpartition('\n\t\t\t\tin')
    if not columns or not marker or not result.strip():
        raise ValueError('Expected inspected legacy numeric columns and final M expression')
    pairs = ', '.join('{"'+name.strip("'")+'", Int64.Type}' for name in columns)
    return (declarations+'\n\tpartition '+before+marker+'\n\t\t\t\t    '
            +'Table.TransformColumnTypes('+result.strip()+', {'+pairs+'}, "pt-BR")\n\n')


def table(name, columns, query, measures=()):
    parts = [f'table {name}\n']
    for column, kind in columns:
        parts.append(f'\tcolumn {column}\n\t\tdataType: {kind}\n\t\tsummarizeBy: none\n\t\tsourceColumn: {column}\n')
    for label, expression, format_string in measures:
        parts.append(f"\tmeasure '{label}' = {expression}\n\t\tformatString: {format_string}\n\t\tdisplayFolder: 11 | Rastreio App\n")
    parts.append(f'\tpartition {name} = m\n\t\tmode: import\n\t\tsource = ```\n')
    parts.extend('\t\t\t'+line+'\n' for line in query.splitlines())
    parts.append('\t\t\t```\n')
    return '\n'.join(parts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--template', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--app-spreadsheet-id', default='1MNM2QgA8xbneQoBFmlsbP7kgOIdGoh5wD_w8tIRP5TE',
                        help='Sheets destination for the three app snapshots; original baseline queries are preserved')
    parser.add_argument('--stabilize-legacy-numeric-types', action='store_true',
                        help='Restore explicit integer types in the copied Baseline/ComplementoBaseline queries after expansion')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]{20,100}', args.app_spreadsheet_id):
        raise SystemExit('Invalid app spreadsheet identifier')
    template, output = Path(args.template).resolve(), Path(args.output).resolve()
    if not (template/'TDS_Original.pbip').is_file(): raise SystemExit('Inspected TDS PBIP template required')
    if output.exists(): raise SystemExit('Use a new output directory; preserve existing BI artifacts')
    shutil.copytree(template, output, ignore=shutil.ignore_patterns('.pbi', '*.abf', '*.bak'))
    model = output/'TDS_Baseline.SemanticModel/definition'
    report = output/'TDS_Immersive.Report/definition'
    if args.stabilize_legacy_numeric_types:
        for legacy_name in ('Baseline', 'ComplementoBaseline'):
            legacy_path = model/'tables'/f'{legacy_name}.tmdl'
            legacy_path.write_text(stabilize_legacy_numeric_types(
                legacy_path.read_text(encoding='utf-8-sig')), encoding='utf-8')
    docs = Path(__file__).resolve().parents[2]/'docs/production/bi'
    journey_columns = [('registro_id','string'), ('pessoa_id','string'), ('turma_id','string'), ('programa_id','string'),
        ('curso_id','string'), ('curso','string'), ('curso_versao_id','string'), ('matricula_contextual_id','string'),
        ('status_baseline','string'), ('vinculo_revisao','int64'), ('vinculo_conferido_em','dateTime'),
        ('carga_horaria_prevista','double'), ('horas_estudo_validadas','double'), ('progresso_estudo_percentual','double'),
        ('certificado_flag','int64'), ('certificado_emitido_em','dateTime'), ('certificado_cobertura','string'),
        ('data_ultima_interacao','dateTime'), ('interacoes_qtd','int64'), ('status_qualidade','string'), ('atualizado_em','dateTime')]
    activity_columns = [('pessoa_id','string'), ('data_utc','dateTime'), ('evento','string'), ('alvo_tipo','string'),
        ('alvo_id','string'), ('eventos_qtd','int64'), ('segundos_tela','int64'), ('escopo','string'), ('nome_tela','string')]
    participant_columns = [('pessoa_id','string'), ('turma_id','string'), ('registro_id','string'), ('status_vinculo','string'), ('situacao_vinculo','string')]
    participant_measures = [('Contas no programa','DISTINCTCOUNT(ParticipantesApp[pessoa_id])','#,0'),
        ('Vínculos pendentes','CALCULATE(DISTINCTCOUNT(ParticipantesApp[pessoa_id]),ParticipantesApp[status_vinculo]<>"confirmed")','#,0')]
    scope = 'KEEPFILTERS(TREATAS(VALUES(ParticipantesApp[pessoa_id]),AtividadeApp[pessoa_id]))'
    journey_scope = 'KEEPFILTERS(TREATAS(VALUES(ParticipantesApp[pessoa_id]),JornadaApp[pessoa_id])),KEEPFILTERS(TREATAS(VALUES(ParticipantesApp[turma_id]),JornadaApp[turma_id]))'
    journey_measures = [('Inscrições vinculadas',f'CALCULATE(DISTINCTCOUNT(JornadaApp[registro_id]),{journey_scope})','#,0'),
        ('Pessoas identificadas',f'CALCULATE(DISTINCTCOUNT(JornadaApp[pessoa_id]),{journey_scope})','#,0'),
        ('Certificados registrados na API',f'CALCULATE(DISTINCTCOUNT(JornadaApp[registro_id]),JornadaApp[certificado_flag]=1,{journey_scope})','#,0')]
    activity_measures = [('Pessoas ativas no app',f'CALCULATE(DISTINCTCOUNT(AtividadeApp[pessoa_id]),{scope})','#,0'),
        ('Minutos por tela',f'CALCULATE(DIVIDE(SUM(AtividadeApp[segundos_tela]),60),AtividadeApp[evento]="screen_engagement",{scope})','#,0.0'),
        ('Pessoas com tempo em tela',f'CALCULATE(DISTINCTCOUNT(AtividadeApp[pessoa_id]),AtividadeApp[evento]="screen_engagement",{scope})','#,0'),
        ('Acessos às telas',f'CALCULATE(SUM(AtividadeApp[eventos_qtd]),AtividadeApp[evento]="page_viewed",{scope})','#,0'),
        ('Pedidos de ajuda ao Tutor',f'CALCULATE(SUM(AtividadeApp[eventos_qtd]),AtividadeApp[evento]="feature_used",AtividadeApp[alvo_id]="tutor_help_requested",{scope})','#,0'),
        ('Pedidos de ajuda à equipe',f'CALCULATE(SUM(AtividadeApp[eventos_qtd]),AtividadeApp[evento]="feature_used",AtividadeApp[alvo_id]="human_help_requested",{scope})','#,0'),
        ('Pedidos de ajuda','[Pedidos de ajuda ao Tutor] + [Pedidos de ajuda à equipe]','#,0'),
        ('Respostas pouco úteis',f'CALCULATE(SUM(AtividadeApp[eventos_qtd]),AtividadeApp[evento]="feature_used",AtividadeApp[alvo_id]="tutor_feedback_not_useful",{scope})','#,0')]
    for name, columns, query, measures in [
        ('JornadaApp',journey_columns,(docs/'JornadaApp.pq').read_text(encoding='utf-8'),journey_measures),
        ('AtividadeApp',activity_columns,(docs/'AtividadeApp.pq').read_text(encoding='utf-8'),activity_measures),
        ('ParticipantesApp',participant_columns,(docs/'ParticipantesApp.pq').read_text(encoding='utf-8'),participant_measures),
        ('PessoaApp',[('pessoa_id','string')],'let\n    Source = Table.Distinct(Table.SelectColumns(ParticipantesApp, {"pessoa_id"}))\nin\n    Source',[])]:
        query = query.replace('1MNM2QgA8xbneQoBFmlsbP7kgOIdGoh5wD_w8tIRP5TE', args.app_spreadsheet_id)
        (model/'tables'/f'{name}.tmdl').write_text(table(name,columns,query,measures), encoding='utf-8')
    with (model/'model.tmdl').open('a', encoding='utf-8') as file:
        file.write('\nref table JornadaApp\nref table AtividadeApp\nref table ParticipantesApp\nref table PessoaApp\n')
    with (model/'relationships.tmdl').open('a', encoding='utf-8') as file:
        file.write('\nrelationship BaselineJornadaApp\n\tfromColumn: JornadaApp.registro_id\n\ttoColumn: Baseline.registro_id\n')
        for name in ('JornadaApp','AtividadeApp','ParticipantesApp'):
            file.write(f'\nrelationship Pessoa{name}\n\tfromColumn: {name}.pessoa_id\n\ttoColumn: PessoaApp.pessoa_id\n')
    page_name = 'RastreioApp'
    page = json.loads((report/'pages/JornadaTDS/page.json').read_text(encoding='utf-8-sig'))
    page.update(name=page_name, displayName='10 | Rastreio no app')
    page['height'] = 1080
    write_json(report/'pages'/page_name/'page.json', page)
    title = json.loads((report/'pages/JornadaTDS/visuals/title/visual.json').read_text(encoding='utf-8-sig'))
    title['visual']['objects']['general'][0]['properties']['paragraphs'][0]['textRuns'][0]['value'] = 'TDS | Identidade e uso do aplicativo'
    write_json(report/'pages'/page_name/'visuals/title/visual.json', title)
    footnote = copy.deepcopy(title)
    footnote.update(name='note', position={'x':28,'y':520,'z':3,'height':70,'width':1200,'tabOrder':3})
    run = footnote['visual']['objects']['general'][0]['properties']['paragraphs'][0]['textRuns'][0]
    run['value'] = 'Tempo estimado nas telas com o app aberto. Pedidos de ajuda e avaliações são sinais de uso; a frequência e a certificação dependem dos registros oficiais.'
    run['textStyle']['fontSize'] = '14px'
    write_json(report/'pages'/page_name/'visuals/note/visual.json', footnote)
    card = json.loads((report/'pages/JornadaTDS/visuals/c_cert/visual.json').read_text(encoding='utf-8-sig'))
    cards = [('JornadaApp','Inscrições vinculadas'),('ParticipantesApp','Contas no programa'),
        ('ParticipantesApp','Vínculos pendentes'),('AtividadeApp','Minutos por tela'),
        ('AtividadeApp','Pedidos de ajuda'),('JornadaApp','Certificados registrados na API')]
    for index, (entity, label) in enumerate(cards):
        visual = copy.deepcopy(card)
        visual['name'] = f'app_card_{index}'
        visual['position'].update(x=28+(index%3)*410,y=150+(index//3)*145,width=390,height=125,z=100+index,tabOrder=100+index)
        projection = visual['visual']['query']['queryState']['Values']['projections'][0]
        projection['field']['Measure']['Expression']['SourceRef']['Entity'] = entity
        projection['field']['Measure']['Property'] = label
        projection['queryRef'] = entity+'.'+label
        visual['visual']['visualContainerObjects']['title'][0]['properties']['text']['expr']['Literal']['Value'] = "'"+label+"'"
        write_json(report/'pages'/page_name/'visuals'/visual['name']/'visual.json', visual)
    # Reuse a table actually inspected in the original report, retaining its
    # fonts/grid/container. Only projections, widths, sorting and title change.
    original_table = json.loads((report/'pages/Politicas/visuals/b_mun/visual.json').read_text(encoding='utf-8-sig'))
    tables = [('screen_time','Tempo por tela',610,180,[
        ('AtividadeApp','nome_tela','Column','Tela',570),
        ('AtividadeApp','Minutos por tela','Measure','Minutos estimados',200),
        ('AtividadeApp','Pessoas com tempo em tela','Measure','Pessoas',180),
        ('AtividadeApp','Acessos às telas','Measure','Acessos',200)]),
        ('identity_review','Participantes e conferência do baseline',810,230,[
        ('ParticipantesApp','pessoa_id','Column','ID de acompanhamento',470),
        ('ParticipantesApp','turma_id','Column','Turma (ID)',220),
        ('ParticipantesApp','registro_id','Column','Inscrição conferida',180),
        ('ParticipantesApp','situacao_vinculo','Column','Situação do vínculo',300)])]
    for name,label,y,height,fields in tables:
        visual = copy.deepcopy(original_table)
        visual.update(name=name, position={'x':28,'y':y,'z':210,'height':height,'width':1224,'tabOrder':210})
        projections = [{'field':{kind:{'Expression':{'SourceRef':{'Entity':entity}},'Property':prop}},
            'queryRef':entity+'.'+prop,'active':True,'displayName':display} for entity,prop,kind,display,_ in fields]
        visual['visual']['query'] = {'queryState':{'Values':{'projections':projections}},
            'sortDefinition':{'sort':[{'field':projections[0]['field'],'direction':'Ascending'}],'isDefaultSort':True}}
        visual['visual']['objects']['columnWidth'] = [{'properties':{'value':{'expr':{'Literal':{'Value':str(width)+'D'}}}},
            'selector':{'metadata':entity+'.'+prop}} for entity,prop,_,_,width in fields]
        visual['visual']['visualContainerObjects']['title'][0]['properties']['text']['expr']['Literal']['Value'] = "'"+label+"'"
        write_json(report/'pages'/page_name/'visuals'/name/'visual.json', visual)
    pages_file = report/'pages/pages.json'
    pages = json.loads(pages_file.read_text(encoding='utf-8-sig'))
    pages['pageOrder'].append(page_name); pages['activePageName'] = page_name
    write_json(pages_file, pages)
    project = json.loads((template/'TDS_Original.pbip').read_text(encoding='utf-8-sig'))
    write_json(output/'TDS_Rastreio.pbip', project)
    evidence = {'status':'local_candidate_unpublished', 'template': str(template), 'added_tables':['JornadaApp','AtividadeApp','ParticipantesApp','PessoaApp'],
        'baseline_sha256':hashlib.sha256((model/'tables/Baseline.tmdl').read_bytes()).hexdigest(),
        'legacy_numeric_types_stabilized':args.stabilize_legacy_numeric_types,
        'preserved_jornada_sha256':hashlib.sha256((model/'tables/Jornada.tmdl').read_bytes()).hexdigest(),
        'new_page':page_name, 'cloud_writes':False, 'requires_google_tabs':['TDS_JORNADA_APP','TDS_ATIVIDADE_APP','TDS_PARTICIPANTES_APP'],
        'validation':'JSON parsed; TMDL/M refresh and visual rendering pending in Power BI; not production acceptance'}
    write_json(output/'rastreio-candidate.json', evidence)
    print(json.dumps(evidence, ensure_ascii=False))


if __name__ == '__main__': main()
