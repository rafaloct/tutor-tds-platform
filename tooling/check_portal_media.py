"""Read-only static media checks; availability is never rights or playback proof."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import json
import urllib.parse
import urllib.request

ROOT = Path('/opt/tds-institutional-backups/20261020T003715Z')
data = json.loads((ROOT / 'media-inventory.json').read_text())

def inspect(item):
    result = dict(item)
    result['files'] = []
    for kind in ('mp4', 'vtt'):
        for url in item[kind]:
            parsed = urllib.parse.urlsplit(url)
            assert parsed.scheme == 'https' and parsed.hostname == 'ead.ipexdesenvolvimento.cloud'
            assert not parsed.query and not parsed.fragment
            relative = urllib.parse.unquote(parsed.path).lstrip('/')
            file = (ROOT / 'restore-files' / relative).resolve()
            assert file.is_relative_to((ROOT / 'restore-files/wp-content/uploads/tutor-tds').resolve())
            sha = hashlib.sha256()
            with file.open('rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    sha.update(block)
            request = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'TutorTDS-Media-ReadOnly/1.0'})
            with urllib.request.urlopen(request, timeout=30) as response:
                status = response.status
                content_type = response.headers.get('Content-Type')
            result['files'].append({'kind': kind, 'url': url, 'http': status, 'content_type': content_type,
                                    'backup_sha256': sha.hexdigest(), 'bytes': file.stat().st_size,
                                    'vtt_header_valid': file.read_bytes().startswith(b'WEBVTT') if kind == 'vtt' else None})
    result['playback_proven'] = False
    return result

with ThreadPoolExecutor(max_workers=4) as pool:
    data['items'] = list(pool.map(inspect, data['items']))
data['http_pass'] = sum(f['http'] == 200 for x in data['items'] for f in x['files'])
data['http_fail'] = sum(f['http'] != 200 for x in data['items'] for f in x['files'])
(ROOT / 'media-checked.json').write_text(json.dumps(data, ensure_ascii=True, indent=2))
print(json.dumps({k: v for k, v in data.items() if k != 'items'}))
