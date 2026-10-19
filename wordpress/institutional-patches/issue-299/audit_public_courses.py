"""Anonymous GET-only catalog evidence. No instructor/student data is retained."""
from collections import Counter
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import subprocess

origin = 'https://ead.ipexdesenvolvimento.cloud'
ids = [614,1298,1307,1314,1321,1328,1335,1343,1356]
def get(path):
    # urllib is rejected by the public edge; curl's normal GET is supported.
    raw = subprocess.check_output(['curl.exe', '-sS', '--max-time', '30',
        '-w', '\n%{http_code}', origin + path]).decode('utf-8')
    body, status = raw.rsplit('\n', 1)
    return int(status), json.loads(body)

courses = []
for course_id in ids:
    status, data = get('/wp-json/learnpress/v1/courses/' + str(course_id))
    route_status, route = get('/wp-json/tds-learning/v1/courses/' + str(course_id) + '/curriculum')
    items = [item for section in data.get('sections', []) for item in section.get('items', [])]
    courses.append({'id':course_id, 'slug':data.get('slug'), 'url':data.get('permalink'),
        'learnpress_http':status, 'sections':len(data.get('sections', [])),
        'items':len(items), 'item_types':dict(Counter(item.get('type') for item in items)),
        'public_preview_items':sum(item.get('preview') is True for item in items),
        'editorial_http':route_status, 'editorial_error':route.get('code'),
        'internal_app_content':'UNAVAILABLE_ROUTE_NOT_INSTALLED',
        'curriculum':[{'id':i.get('id'), 'type':i.get('type'), 'title':i.get('title')} for i in items]})
status, catalog = get('/wp-json/wp/v2/lp_course?per_page=100&status=publish&_fields=id,slug')
result = {'observed_utc':datetime.now(timezone.utc).isoformat(), 'method':'anonymous GET only',
    'catalog_http':status, 'catalog_count':len(catalog),
    'extra_courses':[row for row in catalog if row['id'] not in ids],
    'courses':courses, 'total_curriculum_items':sum(row['items'] for row in courses),
    'media_count':'UNKNOWN: curriculum items are not a count of MP4/VTT assets or editorial approvals'}
Path(sys.argv[1]).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
for row in courses:
    print(row['id'], row['learnpress_http'], row['sections'], row['items'], row['item_types'], row['editorial_http'], row['editorial_error'])
print('CATALOG_COUNT', len(catalog), 'CURRICULUM_ITEMS', result['total_curriculum_items'])
