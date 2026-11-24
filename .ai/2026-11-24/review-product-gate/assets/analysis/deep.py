#!/usr/bin/env python3
import json, re, collections, os, glob, statistics as S
ROOT=__import__("os").environ.get("RAWF_PROJECTS_ROOT","..")
rows=[json.loads(l) for l in open(__import__('os').environ.get('RAWF_ROUNDS','rounds.jsonl'))]
rows=[r for r in rows if r['repo']!='steammarket-refinery']
PATH=re.compile(r"(?<![\w/.\-])((?:\.{0,2}/)?(?:[\w@\-\[\]().]+/)*[\w@\-\[\]().]+\.(?:py|tsx?|jsx?|mjs|cjs|json|jsonc|md|mdx|sql|toml|ya?ml|cfg|sh|log|ini|css|html|txt|lock))(?::\d+)?")
def pclass(p):
    pl=p.lower()
    if '.ai/' in pl and '/assets/' in pl: return 'task-script(.ai/assets)'
    if 'evidence/' in pl or pl.endswith('.log'): return 'evidence-log'
    if pl.startswith('.ai/') or '/.ai/' in pl or 'implementation-round' in pl or pl.endswith('plan.md') or 'review-round' in pl: return 'record(.ai md)'
    if re.search(r"(^|/)(tests?|__tests__|e2e|fixtures|specs?)/",pl) or re.search(r"(^|/)test_|\.test\.|\.spec\.|conftest|_test\.",pl): return 'repo-test'
    if pl.startswith('scripts/') or '/scripts/' in pl: return 'repo-script'
    if pl.startswith('docs/') or '/docs/' in pl or pl.endswith(('.md','.mdx')): return 'docs'
    if pl.startswith('.ai-workflow/') or pl.startswith('.claude/'): return 'workflow'
    return 'source'
KW=re.compile(r"TC-\d+|测试|用例|断言|证据|留证|补跑|覆盖|夹具|fixture|mock|桩", re.I)
print("=== IMPL Nov blocking issues: primary file class")
for flt,name in ((lambda r:r['date']>='2026-11-01','Nov'),(lambda r:True,'ALL')):
    c=collections.Counter()
    for r in rows:
        if r['kind']!='impl' or not flt(r): continue
        for i in r['issues']:
            if i['severity'] not in('blocker','major'): continue
            ps=[pclass(m.group(1)) for m in PATH.finditer(i.get('detail',''))]
            prim=ps[0] if ps else ('nopath+testkw' if KW.search(i['summary']) else 'nopath')
            if prim=='source' and KW.search(i['summary']): prim='source(+test kw)'
            c[prim]+=1
    t=sum(c.values()); print(name,t,', '.join(f"{k}={v}({100*v/t:.0f}%)" for k,v in c.most_common()))
# subtype of test-ish issues
SUB=[('contradiction/虚报',re.compile(r"矛盾|不一致|虚报|不符|与证据|与实现记录")),
     ('assertion-strength/coverage',re.compile(r"未覆盖|未验证|未核验|未核对|未逐|未检查|未断言|未执行|未证明|无法区分|无法验证|无法独立|仍可通过|仍会|漏掉|漏查|漏检|跳过|只调用|只匹配|只验证|未实际|不能证明|不能验证|未落实|未完整")),
     ]
c=collections.Counter(); sevc=collections.Counter()
for r in rows:
    if r['kind']!='impl': continue
    for i in r['issues']:
        if i['severity'] not in('blocker','major'): continue
        ps=[pclass(m.group(1)) for m in PATH.finditer(i.get('detail',''))]
        prim=ps[0] if ps else None
        testish = prim in('task-script(.ai/assets)','evidence-log','record(.ai md)','repo-test') or (prim is None and KW.search(i['summary']))
        if not testish: continue
        for n,rx in SUB:
            if rx.search(i['summary']): c[n]+=1; sevc[(n,i['severity'])]+=1; break
        else: c['other']+=1; sevc[('other',i['severity'])]+=1
print("\n=== IMPL ALL test-ish blocking issues subtypes:",dict(c)); print(dict(sevc))
# fix rounds: did the next implementation round touch product source?
print("\n=== fix rounds: files listed in implementation-round-(N+1) '本轮改动' after a FAIL round N")
def impl_files(path):
    try: txt=open(path,encoding='utf-8',errors='replace').read()
    except FileNotFoundError: return None
    m=re.search(r"##\s*本轮改动(.*?)(?=\n## )",txt,re.S)
    if not m: return None
    files=[]
    for line in m.group(1).splitlines():
        if line.startswith('|') and not re.match(r"\|\s*(文件|-+)",line):
            cell=line.split('|')[1]
            for p in re.findall(r"`([^`]+)`",cell) or [cell.strip()]:
                files.append(p.strip())
    return files
for flt,name in ((lambda r:r['date']>='2026-11-01','Nov'),(lambda r:True,'ALL')):
    tot=0; nosrc=0; unknown=0; comp=collections.Counter()
    for r in rows:
        if r['kind']!='impl' or r['verdict']!='fail' or not flt(r): continue
        nxt=f"{ROOT}/{r['repo']}/.ai/{r['date']}/{r['task']}/implementation-round-{r['round']+1:02d}.md"
        fs=impl_files(nxt)
        if fs is None or not fs: unknown+=1; continue
        tot+=1
        cl=set()
        for f in fs:
            k=pclass(f if re.search(r"\.\w+$",f.split(':')[0]) else f+'/x.py')
            cl.add(k)
        has_src=bool(cl & {'source'})
        nosrc+= (not has_src)
        comp['source-touched' if has_src else 'no-source: '+'+'.join(sorted(cl))]+=1
    print(name,f"fix rounds parsed={tot} (unparsed/no-next={unknown}); no product source touched={nosrc} ({100*nosrc/(tot or 1):.0f}%)")
    for k,v in comp.most_common(8): print('   ',v,k)
# reviewer attention: bytes of command output attributed by file class
print("\n=== reviewer attention (impl rounds w/ events): output chars read, by path class of command")
def cmd_classes(cmd):
    ps=[m.group(1) for m in PATH.finditer(cmd)]
    return [pclass(p) for p in ps]
for flt,name in ((lambda r:r['date']>='2026-11-01','Nov'),):
    att=collections.Counter(); n=0
    for r in rows:
        if r['kind']!='impl' or not r.get('ev') or not flt(r): continue
        n+=1
        for cmd,outlen,rc in r['ev']['commands']:
            cl=cmd_classes(cmd)
            if 'git diff' in cmd and not cl: att['git diff (whole)']+=outlen; continue
            if not cl: att['other/unknown']+=outlen; continue
            for k in cl: att[k]+=outlen/len(cl)
    t=sum(att.values()); print(name,'rounds',n,'total chars',int(t)); 
    for k,v in att.most_common(): print(f"   {k:28s} {100*v/t:5.1f}%")
