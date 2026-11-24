#!/usr/bin/env python3
import json, re, collections, random, sys
rows=[json.loads(l) for l in open(__import__('os').environ.get('RAWF_ROUNDS','rounds.jsonl'))]
KW_TEST=re.compile(r"TC-\d+|测试|用例|断言|证据|留证|档位|覆盖|验收|夹具|fixture|mock|桩|evidence|A 档|B 档|C 档|脚本", re.I)
def pcat(i):
    s=i.get('summary','')
    return 'test-table/evidence' if KW_TEST.search(s) else 'design/other'
print("=== PLAN review: blocking issues (plan-blocker/major) by summary keyword")
for scope,flt in (('ALL',lambda r:True),('>=2026-11-01',lambda r:r['date']>='2026-11-01')):
    for repo in ['cscheap-frontend','cscheap-api','steammarket-spider','ALL3']:
        c=collections.Counter(); sev=collections.Counter(); nr=0; nfail=0; only=0
        for r in rows:
            if r['kind']!='plan' or not flt(r) or r['repo']=='steammarket-refinery': continue
            if repo!='ALL3' and r['repo']!=repo: continue
            nr+=1
            blk=[i for i in r['issues'] if i['severity'] in('plan-blocker','major','blocker')]
            for i in r['issues']: sev[i['severity']]+=1
            if r['verdict']=='fail':
                nfail+=1
                if blk and all(pcat(i)=='test-table/evidence' for i in blk): only+=1
            for i in blk: c[pcat(i)]+=1
        tot=sum(c.values()) or 1
        print(f"{scope:13s} {repo:18s} rounds={nr} fail={nfail} fail-only-test-table={only} ({100*only/(nfail or 1):.0f}%) | blocking={sum(c.values())} "+', '.join(f"{k}={v}({100*v/tot:.0f}%)" for k,v in c.most_common())+f" | sev {dict(sev)} avg blocking/fail-round={sum(c.values())/(nfail or 1):.1f}")
# by round index: do later rounds keep finding new stuff?
print("\n=== PLAN review Nov: blocking issues per round index & share test-table")
byr=collections.defaultdict(lambda:[0,0,0])
for r in rows:
    if r['kind']!='plan' or r['date']<'2026-11-01' or r['repo']=='steammarket-refinery': continue
    blk=[i for i in r['issues'] if i['severity'] in('plan-blocker','major','blocker')]
    b=byr[min(r['round'],6)]; b[0]+=1; b[1]+=len(blk); b[2]+=sum(pcat(i)=='test-table/evidence' for i in blk)
for k in sorted(byr): n,b,t=byr[k]; print(f"round {k}{'+' if k==6 else ''}: rounds={n} blocking/round={b/n:.1f} test-table share={100*t/(b or 1):.0f}%")
print("\n=== IMPL review Nov: blocking issues per round index")
byr=collections.defaultdict(lambda:[0,0,0])
for r in rows:
    if r['kind']!='impl' or r['date']<'2026-11-01' or r['repo']=='steammarket-refinery': continue
    blk=[i for i in r['issues'] if i['severity'] in('major','blocker')]
    b=byr[min(r['round'],5)]; b[0]+=1; b[1]+=len(blk); b[2]+=(r['verdict']=='pass')
for k in sorted(byr): n,b,p=byr[k]; print(f"round {k}{'+' if k==5 else ''}: rounds={n} blocking/round={b/n:.1f} pass={100*p/n:.0f}%")
random.seed(7)
def sample(kind,n,sevs):
    pool=[(r,i) for r in rows if r['kind']==kind and r['date']>='2026-11-05' and r['repo']!='steammarket-refinery' for i in r['issues'] if i['severity'] in sevs]
    for r,i in random.sample(pool,min(n,len(pool))):
        print(f"[{r['repo'].split('-')[-1][:8]} {r['date'][5:]} {r['task'][:28]} r{r['round']} {i['severity']}] {i['summary']}")
print("\n=== sample IMPL blocking issue summaries (Nov)"); sample('impl',70,('major','blocker'))
print("\n=== sample PLAN blocking issue summaries (Nov)"); sample('plan',70,('major','plan-blocker'))
