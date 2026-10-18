#!/usr/bin/env python3
"""Synthetic metadata-only WordPress runtime probe for exact PR #238.

Does NOT edit post body/status (LearnPress synthetic fixture denies edit_lp_lesson).
Every write is to an ephemeral DB clone, destroyed in the runner EXIT trap.
"""
import json, re, subprocess, sys, urllib.request, urllib.error
BASE, WPCLI, SITE = sys.argv[1:4]
passes = fails = 0
def ck(name, ok):
    global passes, fails
    print(("PASS " if ok else "FAIL ") + name, flush=True)
    passes += bool(ok); fails += not bool(ok)
def request(path, etag=None):
    hdrs={"If-None-Match":etag} if etag else {}
    req=urllib.request.Request(BASE+path,headers=hdrs,method="GET")
    try:
        with urllib.request.urlopen(req,timeout=10) as r: status=r.status; header=dict(r.headers); raw=r.read(512001)
    except urllib.error.HTTPError as e: status=e.code; header=dict(e.headers); raw=e.read(512001)
    try: obj=json.loads(raw.decode()) if raw else None
    except Exception: obj=None
    return status,header,obj
def gettag(headers):
    return headers.get("ETag",headers.get("Etag",headers.get("etag")))
def wp(*args):
    r=subprocess.run(["php",WPCLI,"--allow-root","--path="+SITE,"--user=1",*args],capture_output=True,text=True,timeout=15)
    if r.returncode: raise RuntimeError("synthetic WP meta operation failed")
course="/wp-json/tds-learning/v1/courses/11/curriculum"
lesson="/wp-json/tds-learning/v1/courses/11/lessons/12"
status,h,c=request(course)
start_tag=gettag(h)
ck("M01 real WP published course",status==200 and c.get("authority")=="learnpress")
ck("M02 real WP cache validator",bool(start_tag) and re.fullmatch(r'"[a-f0-9]{64}"',start_tag)!=None)
status,_,_=request(lesson)
ck("M03 private lesson denied before opt-in",status==404)
wp("post","meta","update","12","_tds_mobile_public","1")
wp("post","meta","update","12","_tds_mobile_rights_approved","0")
wp("post","meta","update","12","_tds_mobile_youtube_id","AAAAAAAAAAA")
status,hl,obj=request(lesson)
ck("M04 explicit public opt-in returns lesson",status==200 and isinstance(obj,dict) and obj.get("lesson_id")==12)
ck("M05 video hidden without rights flag",isinstance(obj,dict) and obj.get("media") is None)
ck("M06 content has no answers/certificates",isinstance(obj,dict) and all(k not in obj for k in ("answers","grade","questions","certificate")))
lesson_tag=gettag(hl)
status,_,_=request(lesson,lesson_tag)
ck("M07 ETag 304 after same lesson revision",status==304)
status,hc,cur=request(course,start_tag)
ck("M08 curriculum revised after opt-in",status==200 and gettag(hc)!=start_tag)
items=[i for s in cur.get("sections",[]) for i in s.get("items",[])]
item=next((i for i in items if i.get("id")==12),None)
ck("M09 curriculum mobile flag becomes true",isinstance(item,dict) and item.get("mobile_content") is True)
wp("post","meta","update","12","_tds_mobile_rights_approved","1")
status,h2,obj=request(lesson,lesson_tag)
media=obj.get("media") if isinstance(obj,dict) else None
ck("M10 synthetic video flag projects media metadata",status==200 and isinstance(media,dict) and media.get("provider")=="youtube" and media.get("video_id")=="AAAAAAAAAAA")
ck("M11 rights toggle invalidates lesson ETag",gettag(h2)!=lesson_tag)
wp("post","meta","update","12","_tds_mobile_poster_url","https://evil.invalid/wp-content/uploads/test.png")
status,_,obj=request(lesson)
media=obj.get("media") if isinstance(obj,dict) else None
ck("M12 external poster rejected",isinstance(media,dict) and "poster_url" not in media)
wp("post","meta","update","12","_tds_mobile_youtube_id","INVALID")
status,_,obj=request(lesson)
ck("M13 invalid Youtube id suppresses media",status==200 and isinstance(obj,dict) and obj.get("media") is None)
wp("post","meta","update","12","_tds_mobile_youtube_id","AAAAAAAAAAA")
wp("post","meta","update","12","_tds_mobile_rights_approved","0")
status,_,obj=request(lesson)
ck("M14 revoked rights suppress media",status==200 and isinstance(obj,dict) and obj.get("media") is None)
wp("post","meta","update","12","_tds_mobile_public","0")
status,_,_=request(lesson)
ck("M15 revoked public opt-in returns 404",status==404)
status,_,c=request(course)
items=[i for s in c.get("sections",[]) for i in s.get("items",[])]
it=next((i for i in items if i.get("id")==12),None)
ck("M16 revoked item hidden from mobile",isinstance(it,dict) and it.get("mobile_content") is False and it.get("media") is None)
ck("M17 draft lesson omitted",not any(i.get("id")==13 for i in items))
status,_,_=request("/wp-json/wp/v2/users/me")
ck("M18 WP core private profile inaccessible",status in (401,403))
print("RESULT PR238_WP_RUNTIME_META_ONLY PASS=%d FAIL=%d" % (passes,fails),flush=True)
sys.exit(0 if fails==0 else 1)
