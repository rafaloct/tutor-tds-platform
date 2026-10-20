"""Bounded read-only QA transport: loopback HTTP -> pinned TLS/tailnet -> SSH.

Never forwards cookies/authentication or arbitrary paths. No public interface bind.
"""
import argparse
import http.client
import http.server
import json
import socket
import ssl
import threading
import urllib.parse

p=argparse.ArgumentParser()
p.add_argument('mode',choices=['client','server'])
p.add_argument('--cert',required=True)
p.add_argument('--key')
p.add_argument('--duration',type=int,default=900)
a=p.parse_args()
ROUTES={'/tds-learning/v1/courses/12/curriculum','/tds-learning/v1/courses/12/lessons/13'}
class PinnedConnection(http.client.HTTPSConnection):
    def connect(self):
        self.sock=self._context.wrap_socket(socket.create_connection(('100.122.9.70',18735),10),server_hostname='tds-qa-private.invalid')

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_GET(self):
        if a.mode=='server' and self.client_address[0]!='100.111.132.8':
            self.send_error(403); return
        if self.headers.get('Cookie') or self.headers.get('Authorization'):
            self.send_error(403); return
        parsed=urllib.parse.urlsplit(self.path)
        health=self.path=='/healthz'
        query=urllib.parse.parse_qs(parsed.query)
        route=query.get('rest_route',[])
        valid=parsed.path=='/' and set(query)=={'rest_route'} and len(route)==1 and route[0] in ROUTES
        if not health and not valid:
            self.send_error(404); return
        if health and a.mode=='server':
            body=b'{"qa":"immutable-editorial","transport":"TLS-tailnet-SSH","read_only":true}'
            self.send_response(200); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body); return
        try:
            if a.mode=='client':
                conn=PinnedConnection('tds-qa-private.invalid',18735,context=ssl.create_default_context(cafile=a.cert),timeout=15)
                headers={'Host':'tds-qa-private.invalid'}
            else:
                conn=http.client.HTTPConnection('127.0.0.1',18732,timeout=15)
                headers={'Host':'tds-registration-299'}
            if self.headers.get('If-None-Match'): headers['If-None-Match']=self.headers['If-None-Match']
            conn.request('GET',self.path,headers=headers)
            r=conn.getresponse(); body=r.read()
            self.send_response(r.status)
            for name in ['Content-Type','ETag','Cache-Control']:
                if r.getheader(name): self.send_header(name,r.getheader(name))
            self.send_header('Content-Length',str(len(body))); self.end_headers(); self.wfile.write(body)
            print(json.dumps({'method':'GET','path':self.path,'status':r.status,'bytes':len(body),'cookies_forwarded':False}),flush=True)
            conn.close()
        except (OSError,http.client.HTTPException): self.send_error(502)

server=http.server.ThreadingHTTPServer(('100.122.9.70',18735) if a.mode=='server' else ('127.0.0.1',18731),Handler)
if a.mode=='server':
    ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.minimum_version=ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(a.cert,a.key); server.socket=ctx.wrap_socket(server.socket,server_side=True)
timer=threading.Timer(a.duration,server.shutdown); timer.daemon=True; timer.start()
print('QA_RELAY_READY '+a.mode,flush=True)
try: server.serve_forever()
finally: server.server_close()
