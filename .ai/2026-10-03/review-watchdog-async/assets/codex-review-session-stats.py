import os, re, datetime, glob, json
root = os.path.expanduser('~/.codex/sessions')
rows = []
for f in glob.glob(root + '/**/rollout-*.jsonl', recursive=True):
    data = open(f, encoding='utf-8', errors='replace').read()
    kind = None
    for line in data.splitlines()[:40]:
        if '"role":"user"' not in line and '"role": "user"' not in line: continue
        try: txt = json.dumps(json.loads(line), ensure_ascii=False)
        except Exception: continue
        if '评审当前工作区的未提交改动' in txt: kind = 'impl'; break
        if '评审一份**开发方案**' in txt: kind = 'plan'; break
    if not kind: continue
    lines = data.splitlines()
    ev = []; types = []
    for i, line in enumerate(lines):
        m = re.search(r'"timestamp":"([^"]+)"', line)
        if not m: continue
        try: o = json.loads(line)
        except Exception: continue
        p = o.get('payload') or {}
        pt = p.get('type') if isinstance(p, dict) else None
        ev.append((datetime.datetime.fromisoformat(m.group(1).replace('Z','+00:00')), o.get('type'), pt, line))
    if len(ev) < 2: continue
    tot = (ev[-1][0]-ev[0][0]).total_seconds()/60
    gi = max(range(len(ev)-1), key=lambda k: (ev[k+1][0]-ev[k][0]).total_seconds())
    gap = (ev[gi+1][0]-ev[gi][0]).total_seconds()/60
    finished = any(e[2] == 'task_complete' for e in ev[-5:])
    rows.append(dict(kind=kind, tot=tot, gap=gap, start=ev[0][0], finished=finished, ev=ev, gi=gi, f=os.path.basename(f)))
rows.sort(key=lambda r: r['start'])
n = len(rows); fin = [r for r in rows if r['finished']]; unf = [r for r in rows if not r['finished']]
print(f'exec review sessions: {n}  finished: {len(fin)}  unfinished: {len(unf)}')
tots = sorted(r['tot'] for r in fin); gaps = sorted(r['gap'] for r in fin)
for p in (50, 80, 90, 95, 99, 100):
    i = min(len(fin)-1, int(len(fin)*p/100)); print(f'  finished p{p}: total={tots[i]:.1f}m  max_idle_gap={gaps[i]:.1f}m')
print('\n-- finished sessions with max_idle_gap > 5m: start kind total gap | events around the gap')
for r in fin:
    if r['gap'] > 5:
        print(f"{r['start'].strftime('%m-%d %H:%M')} {r['kind']} {r['tot']:6.1f}m gap={r['gap']:5.1f}m")
        for e in r['ev'][max(0, r['gi']-1): r['gi']+3]:
            print(f"     {e[0].strftime('%H:%M:%S')} {e[1]}/{e[2]}")
print('\n-- UNFINISHED (hang/killed) sessions: start kind total gap | last 4 events')
for r in unf:
    print(f"{r['start'].strftime('%m-%d %H:%M')} {r['kind']} {r['tot']:6.1f}m gap={r['gap']:5.1f}m  {r['f'][:40]}")
    for e in r['ev'][-4:]:
        print(f"     {e[0].strftime('%H:%M:%S')} {e[1]}/{e[2]}: {e[3][:160]}")
