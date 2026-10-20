"""Offline, read-only audit of retained synthetic MySQL dumps. Never print values."""
import hashlib
import json
import re
import sys
from pathlib import Path

EXPECTED = ('4dc75881fb3f2df0c01a9fa65f1e99973cb231a35ee84ddd0ee34a1ccbc81a16',
            '1ffeecf98e7999890ab7218ee4b3fbb7d142ccdad3bc29e292e5acb1cacecfa4')

def digest(data):
    return hashlib.sha256(data).hexdigest()

def rows(values):
    result=[]; row=[]; token=[]; quoted=False; escaped=False; active=False
    for c in values:
        if escaped:
            token.append(c); escaped=False; continue
        if quoted and c=='\\':
            escaped=True; continue
        if c=="'":
            quoted=not quoted; continue
        if quoted:
            token.append(c); continue
        if c=='(':
            if active: raise ValueError('nested SQL expression refused')
            active=True; row=[]; token=[]
        elif c==',' and active:
            row.append(''.join(token)); token=[]
        elif c==')' and active:
            row.append(''.join(token)); result.append(row); active=False; token=[]
        elif active:
            token.append(c)
        elif c not in ',; \r\n':
            raise ValueError('unexpected SQL token')
    if quoted or escaped or active: raise ValueError('truncated INSERT')
    return result

def parse(path, expected):
    data=path.read_bytes()
    if digest(data)!=expected: raise ValueError('retained dump hash mismatch')
    text=data.decode('utf-8')
    tables={name:{'rows':[], 'sql':b''} for name in re.findall(r'CREATE TABLE `([^`]+)`',text)}
    if not tables or any(not name.startswith('tdsqa_') for name in tables): raise ValueError('unexpected schema')
    for line in text.splitlines():
        if not line.startswith('INSERT INTO '): continue
        m=re.fullmatch(r'INSERT INTO `([^`]+)` VALUES (.*);',line)
        if not m or m[1] not in tables: raise ValueError('unsupported INSERT')
        tables[m[1]]['rows']+=rows(m[2])
        tables[m[1]]['sql']+=(line+'\n').encode()
    return data,tables

def audit(before,after):
    old,a=parse(before,EXPECTED[0]); new,b=parse(after,EXPECTED[1])
    if a.keys()!=b.keys(): raise ValueError('table set changed')
    table_report=[]
    for name in sorted(a):
        table_report.append(dict(table=name,before_rows=len(a[name]['rows']),after_rows=len(b[name]['rows']),
            before_sha256=digest(a[name]['sql']),after_sha256=digest(b[name]['sql']),identical=a[name]['sql']==b[name]['sql']))
    x={r[1]:r for r in a['tdsqa_options']['rows']}; y={r[1]:r for r in b['tdsqa_options']['rows']}
    options=[]
    for name in sorted(x.keys()|y.keys()):
        if x.get(name)!=y.get(name):
            options.append(dict(name=name,change='added' if name not in x else 'removed' if name not in y else 'modified',
                before_sha256=digest(json.dumps(x.get(name)).encode()),after_sha256=digest(json.dumps(y.get(name)).encode())))
    academic=[r for r in table_report if any(k in r['table'] for k in ('user_items','order','quiz','grade','certificate'))]
    # Only domains, not account names/password hashes, leave this process.
    domains=sorted({r[4].split('@')[-1] for r in a['tdsqa_users']['rows']})
    return dict(before_sha256=digest(old),after_sha256=digest(new),tables=table_report,
        changed_options=options,academic_tables=academic,user_count=len(a['tdsqa_users']['rows']),
        user_email_domains=domains,schema_outside_inserts_identical=re.sub(rb'^INSERT INTO .*\n',b'',old,flags=re.M)==re.sub(rb'^INSERT INTO .*\n',b'',new,flags=re.M),
        attribution='UNKNOWN: option differences alone do not identify the writer')

if __name__=='__main__':
    print(json.dumps(audit(Path(sys.argv[1]),Path(sys.argv[2])),indent=2))
