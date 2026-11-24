#!/usr/bin/env python3
import json, collections, statistics as S
rows=[json.loads(l) for l in open(__import__('os').environ.get('RAWF_ROUNDS','rounds.jsonl'))]
tasks=collections.defaultdict(lambda:{'plan':[], 'impl':[], 'meta':None})
for r in rows:
    k=(r['repo'],r['date'],r['task'])
    if r['kind']=='task': tasks[k]['meta']=r
    else: tasks[k][r['kind']].append(r)
def q(xs,p):
    xs=sorted(xs); 
    return xs[min(len(xs)-1,int(p*len(xs)))] if xs else 0
print("=== rounds per task (tasks that had >=1 round of that kind)")
for period,flt in (('2026-07..09',lambda d:d<'2026-10-01'),('2026-10',lambda d:'2026-10-01'<=d<'2026-11-01'),('2026-11',lambda d:d>='2026-11-01')):
    for repo in ['cscheap-frontend','cscheap-api','steammarket-spider','ALL3']:
        P=[];I=[];firstpass_p=0;firstpass_i=0
        for (rp,d,t),v in tasks.items():
            if not flt(d): continue
            if repo=='ALL3':
                if rp=='steammarket-refinery': continue
            elif rp!=repo: continue
            if v['plan']:
                P.append(len(v['plan'])); firstpass_p+= (min(v['plan'],key=lambda r:r['round'])['verdict']=='pass')
            if v['impl']:
                I.append(len(v['impl'])); firstpass_i+= (min(v['impl'],key=lambda r:r['round'])['verdict']=='pass')
        if not P and not I: continue
        print(f"{period:12s} {repo:18s} plan: tasks={len(P):3d} mean={S.mean(P) if P else 0:.1f} p50={q(P,.5)} p90={q(P,.9)} max={max(P or [0])} 1st-pass={100*firstpass_p/(len(P) or 1):.0f}% | impl: tasks={len(I):3d} mean={S.mean(I) if I else 0:.1f} p50={q(I,.5)} p90={q(I,.9)} max={max(I or [0])} 1st-pass={100*firstpass_i/(len(I) or 1):.0f}%")
print()
print("=== token & time per round (rounds with events)")
for kind in ('plan','impl'):
    for repo in ['cscheap-frontend','cscheap-api','steammarket-spider','ALL3']:
        ev=[r for r in rows if r['kind']==kind and r.get('ev') and (repo=='ALL3' and r['repo']!='steammarket-refinery' or r['repo']==repo)]
        if not ev: continue
        ins=[r['ev']['in'] for r in ev]; outs=[r['ev']['out'] for r in ev]; cached=[r['ev']['cached'] for r in ev]
        secs=[r['ev']['secs'] for r in ev if r['ev'].get('secs')]; cmds=[r['ev']['cmds'] for r in ev]
        print(f"{kind} {repo:18s} n={len(ev):4d} input mean={S.mean(ins)/1e6:.2f}M p90={q(ins,.9)/1e6:.2f}M sum={sum(ins)/1e6:.0f}M (cached {100*sum(cached)/sum(ins):.0f}%) | output mean={S.mean(outs)/1e3:.1f}k sum={sum(outs)/1e6:.2f}M | secs mean={S.mean(secs):.0f} p90={q(secs,.9)} sum={sum(secs)/3600:.1f}h | cmds mean={S.mean(cmds):.0f}")
print()
print("=== November per-task totals (tasks with events), top 25 by total review wall time")
tot=[]
for (rp,d,t),v in tasks.items():
    if d<'2026-11-01' or rp=='steammarket-refinery': continue
    rs=[r for r in v['plan']+v['impl'] if r.get('ev')]
    if not rs: continue
    tin=sum(r['ev']['in'] for r in rs); tsec=sum(r['ev'].get('secs') or 0 for r in rs)
    allr=sorted(v['plan']+v['impl'],key=lambda r:r['md_mtime'])
    span=(allr[-1]['md_mtime']-allr[0]['md_mtime'])/3600
    tot.append((tsec,rp,d,t,len(v['plan']),len(v['impl']),tin,span,v['meta']['n_tc'] if v['meta'] else None, v['meta']['plan_bytes'] if v['meta'] else None))
tot.sort(reverse=True)
print(f"tasks={len(tot)} total review time={sum(x[0] for x in tot)/3600:.1f}h input tokens={sum(x[6] for x in tot)/1e6:.0f}M")
for x in tot[:25]:
    print(f"{x[1]:18s} {x[2]} {x[3][:40]:40s} plan_rounds={x[4]} impl_rounds={x[5]} review_min={x[0]/60:.0f} input={x[6]/1e6:.1f}M first→last={x[7]:.1f}h TCs={x[8]} plan={x[9]/1024 if x[9] else 0:.0f}KB")
print()
import statistics
ntc=[v['meta']['n_tc'] for (rp,d,t),v in tasks.items() if v['meta'] and d>='2026-11-01' and rp!='steammarket-refinery' and v['meta']['n_tc']]
pb=[v['meta']['plan_bytes'] for (rp,d,t),v in tasks.items() if v['meta'] and d>='2026-11-01' and rp!='steammarket-refinery']
print("Nov plans: n=",len(pb),"TC count mean/p50/p90/max:",round(S.mean(ntc),1),q(ntc,.5),q(ntc,.9),max(ntc),"| plan KB mean/p50/p90/max:",round(S.mean(pb)/1024,1),round(q(pb,.5)/1024,1),round(q(pb,.9)/1024,1),round(max(pb)/1024,1))
for period,flt in (('07-09',lambda d:d<'2026-10-01'),('10',lambda d:'2026-10-01'<=d<'2026-11-01'),('11',lambda d:d>='2026-11-01')):
    ntc=[v['meta']['n_tc'] for (rp,d,t),v in tasks.items() if v['meta'] and flt(d) and rp!='steammarket-refinery' and v['meta']['n_tc']]
    pb=[v['meta']['plan_bytes'] for (rp,d,t),v in tasks.items() if v['meta'] and flt(d) and rp!='steammarket-refinery']
    print(period,"tasks",len(pb),"TC mean",round(S.mean(ntc),1),"p90",q(ntc,.9),"| plan KB mean",round(S.mean(pb)/1024,1),"p90",round(q(pb,.9)/1024,1))
