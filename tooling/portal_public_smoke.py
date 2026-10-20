"""Read-only promotion checks; no registration or enrollment POSTs."""
import hashlib
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

BASE = 'https://ead.ipexdesenvolvimento.cloud'
IDS = [614, 1298, 1307, 1314, 1321, 1328, 1335, 1343, 1356]
FORBIDDEN = {'user_email', 'user_pass', 'correct_answer', 'user_id', 'grade', 'enrollments'}
results = []

def get(path, headers=None):
    request = urllib.request.Request(BASE + path, headers={'User-Agent': 'TutorTDS-Promotion-ReadOnly/1.0', **(headers or {})})
    try:
        response = urllib.request.urlopen(request, timeout=40)
    except urllib.error.HTTPError as error:
        response = error
    return response.status, dict(response.headers), response.read(), response.url

def check(name, passed, **details):
    results.append({'test': name, 'status': 'PASS' if passed else 'FAIL', **details})

def keys(value):
    if isinstance(value, dict):
        return set(value).union(*(keys(v) for v in value.values()))
    if isinstance(value, list):
        return set().union(*(keys(v) for v in value))
    return set()

def main():
    courses = []
    for cid in IDS:
        path = f'/wp-json/tds-learning/v1/courses/{cid}/curriculum'
        status, headers, body, _ = get(path)
        data = json.loads(body)
        check(f'curriculum-{cid}', status == 200, http=status)
        etag = next((v for k, v in headers.items() if k.lower() == 'etag'), None)
        conditional = get(path, {'If-None-Match': etag})[0] if etag else None
        check(f'etag-{cid}', conditional == 304, http=conditional)
        check(f'public-projection-{cid}', not (keys(data) & FORBIDDEN))
        items = [item for section in data.get('sections', []) for item in section.get('items', [])]
        lessons = [item for item in items if item.get('type') == 'lp_lesson']
        courses.append({'course_id': cid, 'title': data.get('title'), 'items': len(items),
                        'lessons': len(lessons), 'authorized_lessons': sum(x.get('mobile_content') is True for x in lessons),
                        'media': sum(x.get('media') is not None for x in lessons),
                        'response_sha256': hashlib.sha256(body).hexdigest(), 'etag': etag})
        private = next((x for x in lessons if not x.get('mobile_content')), None)
        if private:
            denied = get(f'/wp-json/tds-learning/v1/courses/{cid}/lessons/{private["id"]}')[0]
            check(f'non-opted-in-lesson-{cid}', denied == 404, http=denied)
    status, _, body, _ = get('/cadastro/?tds_curso=614')
    text = body.decode('utf-8', errors='replace')
    check('registration-course-context', status == 200 and bool(re.search(r'name="tds_curso"\s+value="614"', text)), http=status)
    check('registration-existing-login', 'redirect_to=' in text and 'wp-login.php' in text)
    status, _, body, _ = get('/cadastro/')
    check('registration-default', status == 200 and 'tds_cadastro' in body.decode('utf-8', errors='replace'), http=status)
    status, _, _, final = get('/cadastro/?tds_curso=https%3A%2F%2Fevil.invalid')
    check('external-redirect-rejected', final.startswith(BASE + '/cursos/') and 'curso-indisponivel' in final, http=status)
    status, _, _, final = get('/cadastro/?tds_curso=99999999')
    check('missing-course-rejected', final.startswith(BASE + '/cursos/') and 'curso-indisponivel' in final, http=status)
    status, _, _, _ = get('/wp-json/wp/v2/users/me')
    check('anonymous-user-denied', status == 401, http=status)
    result = {'base': BASE, 'mode': 'production-read-only', 'checks': results, 'courses': courses,
              'pass': sum(x['status'] == 'PASS' for x in results), 'fail': sum(x['status'] == 'FAIL' for x in results)}
    Path(sys.argv[1]).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=True))
    return int(result['fail'] > 0)

if __name__ == '__main__':
    raise SystemExit(main())
