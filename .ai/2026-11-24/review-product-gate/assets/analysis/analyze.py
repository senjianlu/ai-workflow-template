#!/usr/bin/env python3
import json, re, collections, sys, statistics as S
rows=[json.loads(l) for l in open(__import__('os').environ.get('RAWF_ROUNDS','rounds.jsonl'))]
PATH=re.compile(r"(?<![\w/.\-])((?:\.{0,2}/)?(?:[\w@\-\[\]().]+/)*[\w@\-\[\]().]+\.(?:py|tsx?|jsx?|mjs|cjs|json|jsonc|md|mdx|sql|toml|ya?ml|cfg|sh|log|ini|css|html|txt|lock))(?::\d+)?")
def pclass(p):
    pl=p.lower()
    if 'evidence/' in pl or pl.endswith('.log'): return 'evidence'
    if pl.startswith('.ai/') or '/.ai/' in pl or 'implementation-round' in pl or pl.endswith('plan.md') or 'review-round' in pl: return 'record'
    if re.search(r"(^|/)(tests?|__tests__|e2e|fixtures|specs?)/",pl) or re.search(r"(^|/)test_|\.test\.|\.spec\.|conftest|_test\.",pl): return 'test'
    if pl.startswith('docs/') or '/docs/' in pl or pl.endswith(('.md','.mdx')): return 'docs'
    if pl.startswith('.ai-workflow/') or pl.startswith('.claude/'): return 'workflow'
    return 'source'
KW=re.compile(r"TC-\d+|测试|用例|断言|证据|留证|补跑|覆盖|夹具|fixture|mock|桩", re.I)
def icat(i):
    text=(i.get('summary','')+' '+i.get('detail',''))
    paths=[m.group(1) for m in PATH.finditer(i.get('detail',''))]
    cls=[pclass(p) for p in paths]
    prim=cls[0] if cls else 'nopath'
    kw=bool(KW.search(i.get('summary','')))
    # final category
    if prim in('test','evidence','record'): cat='test/evidence'
    elif prim=='source': cat='source+testgap' if kw else 'source'
    elif prim=='docs': cat='docs'
    elif prim=='workflow': cat='workflow'
    else: cat='test/evidence' if kw else 'other'
    return cat,prim,kw
def month(r): return r['date'][:7]
sel=sys.argv[1] if len(sys.argv)>1 else 'all'
print("=== IMPL review issues by category (severity blocking = blocker/major)")
for scope,flt in (('ALL',lambda r:True),('>=2026-11-01',lambda r:r['date']>='2026-11-01'),('>=2026-11-16',lambda r:r['date']>='2026-11-16')):
    print('--',scope)
    for repo in ['cscheap-frontend','cscheap-api','steammarket-spider','steammarket-refinery','TOTAL']:
        c=collections.Counter(); cm=collections.Counter(); nr=0; nfail=0; onlytest=0
        for r in rows:
            if r['kind']!='impl' or not flt(r): continue
            if repo!='TOTAL' and r['repo']!=repo: continue
            nr+=1
            blk=[i for i in r['issues'] if i['severity'] in('blocker','major')]
            if r['verdict']=='fail':
                nfail+=1
                cats=[icat(i)[0] for i in blk]
                if cats and all(x=='test/evidence' for x in cats): onlytest+=1
            for i in r['issues']:
                cat=icat(i)[0]
                if i['severity'] in('blocker','major'): c[cat]+=1
                else: cm[cat]+=1
        tot=sum(c.values()) or 1
        print(f"{repo:22s} rounds={nr:4d} fail={nfail:4d} fail-only-test/evidence={onlytest:4d} ({100*onlytest/(nfail or 1):.0f}%) | blocking issues={sum(c.values())}: "+', '.join(f"{k}={v}({100*v/tot:.0f}%)" for k,v in c.most_common()))
