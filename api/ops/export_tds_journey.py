"""Read-only authorized snapshot. No writes to Google Sheets, Fabric or baseline."""
import argparse
from collections import defaultdict
import csv
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def read_pages(base, token, class_id, resource, *, window=None, fetch=None):
    expected = 'tds-journey-v1' if resource == 'journey-export' else 'tds-activity-v1'
    offset, total, rows, pending = 0, None, [], []
    opener = build_opener(NoRedirect())
    def get(url):
        with opener.open(Request(url, headers={'Authorization': 'Bearer ' + token}), timeout=30) as response:
            return json.load(response)
    fetch = fetch or get
    while True:
        params = {'offset': offset, 'limit': 100} | (window or {})
        page = fetch(f'{base}/classes/{class_id}/{resource}?' + urlencode(params))
        if page.get('contract') != expected or page.get('offset') != offset or page.get('limit') != 100:
            raise ValueError('Unexpected export contract')
        current_total = page.get('total')
        if not isinstance(current_total, int) or not 0 <= current_total <= 100000:
            raise ValueError('Export size exceeds reviewed snapshot limit')
        if total is not None and total != current_total:
            raise ValueError('Source changed during snapshot; retry')
        total = current_total
        rows.extend(page['items']); pending.extend(page.get('pending', []))
        offset += 100
        if offset >= total: return rows, pending


def daily_activity(rows):
    seen = {}
    grouped = defaultdict(lambda: {'eventos_qtd': 0, 'segundos_tela': 0})
    for row in rows:
        identity = row['event_id']
        if identity in seen:
            if seen[identity] != row: raise ValueError('Conflicting activity ID')
            continue
        seen[identity] = row
        when = datetime.fromisoformat(row['ocorreu_em'].replace('Z', '+00:00'))
        if when.tzinfo is None: raise ValueError('Activity timestamp missing timezone')
        # Reporting day explicitly uses UTC, avoiding local desktop timezone drift.
        key = (row['pessoa_id'], when.astimezone(timezone.utc).date().isoformat(), row['evento'], row['alvo_tipo'], row['alvo_id'])
        grouped[key]['eventos_qtd'] += 1
        if row['evento'] == 'screen_engagement':
            seconds = row['segundos_tela']
            if type(seconds) is not int or not 1 <= seconds <= 60: raise ValueError('Invalid screen duration')
            grouped[key]['segundos_tela'] += seconds
    return [dict(zip(('pessoa_id', 'data_utc', 'evento', 'alvo_tipo', 'alvo_id'), key),
                 **values, escopo='conta_autenticada') for key, values in sorted(grouped.items())]


JOURNEY_COLUMNS = ['registro_id', 'pessoa_id', 'turma_id', 'programa_id', 'curso_id', 'curso', 'curso_versao_id',
    'matricula_contextual_id', 'status_baseline', 'vinculo_revisao', 'vinculo_conferido_em', 'carga_horaria_prevista',
    'horas_estudo_validadas', 'progresso_estudo_percentual', 'certificado_flag', 'certificado_emitido_em',
    'certificado_cobertura', 'data_ultima_interacao', 'interacoes_qtd', 'status_qualidade', 'atualizado_em']
ACTIVITY_COLUMNS = ['pessoa_id', 'data_utc', 'evento', 'alvo_tipo', 'alvo_id', 'eventos_qtd', 'segundos_tela', 'escopo']
PARTICIPANT_COLUMNS = ['pessoa_id', 'turma_id', 'registro_id', 'status_vinculo']


def participants(rows, pending):
    result = [dict(pessoa_id=row['pessoa_id'], turma_id=row['turma_id'],
        registro_id=row['registro_id'], status_vinculo='confirmed') for row in rows]
    result.extend(dict(pessoa_id=row['pessoa_id'], turma_id=row['turma_id'],
        registro_id=None, status_vinculo=row['status']) for row in pending
        if row['status'] != 'inactive_or_inconsistent')
    keys = [(row['pessoa_id'], row['turma_id']) for row in result]
    if len(keys) != len(set(keys)): raise ValueError('Duplicate participant lineage')
    return result


def csv_value(value):
    if value is None: return ''
    if isinstance(value, str) and value.lstrip().startswith(('=', '+', '-', '@')): return "'" + value
    return value


def write_csv(path, rows, columns):
    with path.open('x', encoding='utf-8-sig', newline='') as file:
        writer = csv.DictWriter(file, fieldnames=columns, extrasaction='ignore')
        writer.writeheader()
        for row in rows: writer.writerow({key: csv_value(row.get(key)) for key in columns})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api-url', required=True)
    parser.add_argument('--class-id', required=True, action='append')
    parser.add_argument('--since', required=True, help='Inclusive ISO timestamp with timezone')
    parser.add_argument('--until', required=True, help='Exclusive ISO timestamp with timezone')
    parser.add_argument('--output-dir', required=True, help='New directory; never overwrites exports')
    args = parser.parse_args()
    base = args.api_url.rstrip('/')
    parsed = urlsplit(base)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise SystemExit('Supply an HTTPS API base without credentials or query')
    if any(not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,35}', value) for value in args.class_id):
        raise SystemExit('Invalid class identifier')
    try:
        start, end = [datetime.fromisoformat(value.replace('Z', '+00:00')) for value in (args.since, args.until)]
    except ValueError: raise SystemExit('Invalid activity window') from None
    if start.tzinfo is None or end.tzinfo is None or not start < end or (end-start).days > 31:
        raise SystemExit('Review at most 31 days per activity snapshot, with explicit timezone')
    token = os.environ.get('TDS_BI_EXPORT_TOKEN', '')
    if not token: raise SystemExit('Set TDS_BI_EXPORT_TOKEN in the protected process environment')
    rows, activity, pending = [], [], []
    try:
        for class_id in dict.fromkeys(args.class_id):
            result, queue = read_pages(base, token, class_id, 'journey-export')
            rows.extend(result); pending.extend(dict(item, turma_id=class_id) for item in queue)
            result, _ = read_pages(base, token, class_id, 'journey-activity', window={'since': args.since, 'until': args.until})
            activity.extend(result)
        ids = [row['registro_id'] for row in rows]
        if len(set(ids)) != len(ids): raise ValueError('Duplicate inscription; reconcile before BI import')
        daily = daily_activity(activity)
        people = participants(rows, pending)
        if not {row['pessoa_id'] for row in daily}.issubset({row['pessoa_id'] for row in people}):
            raise ValueError('Activity owner not in enrolled snapshot')
        output = Path(args.output_dir).resolve()
        output.mkdir(exist_ok=False)
        write_csv(output / 'TDS_JORNADA_APP.csv', rows, JOURNEY_COLUMNS)
        write_csv(output / 'TDS_ATIVIDADE_APP.csv', daily, ACTIVITY_COLUMNS)
        write_csv(output / 'TDS_PARTICIPANTES_APP.csv', people, PARTICIPANT_COLUMNS)
        (output / 'review.json').write_text(json.dumps({'contract': 'tds-export-review-v1',
            'generated_at': datetime.now(timezone.utc).isoformat(), 'since': args.since, 'until': args.until,
            'inscricoes_conferidas': len(rows), 'participacoes_no_programa': len(people), 'atividade_diaria_linhas': len(daily), 'pending': pending,
            'source_is_primary_database': True, 'external_writes': False}, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(json.dumps({'status': 'review_snapshot_created', 'inscriptions': len(rows), 'daily_activity_rows': len(daily), 'pending': len(pending)}))
    except HTTPError as error:
        raise SystemExit(f'Export HTTP {error.code}; no response body or token emitted') from None
    except (URLError, ValueError, FileExistsError, KeyError, TypeError):
        raise SystemExit('Export incomplete: verify permissions, snapshot consistency and output destination') from None


if __name__ == '__main__': main()
