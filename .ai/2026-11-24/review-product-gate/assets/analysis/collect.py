#!/usr/bin/env python3
"""Collect rawf review rounds + issues from consumer repos into JSONL (read-only)."""
import json, os, re, sys, glob

ROOT = __import__("os").environ.get("RAWF_PROJECTS_ROOT", "..")
REPOS = sys.argv[2:] or ["cscheap-frontend", "cscheap-api", "steammarket-spider"]
OUT = sys.argv[1]

MD_ISSUE = re.compile(r"^- \[(plan-blocker|blocker|major|minor)\] (\S+) (.*)$")

def parse_md(path):
    issues, cur = [], None
    verdict = None
    scope = []
    section = None
    for line in open(path, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("## "):
            section = line[3:].strip(); cur = None; continue
        m = MD_ISSUE.match(line)
        if m and section and section.startswith("问题清单"):
            cur = {"severity": m.group(1), "id": m.group(2), "summary": m.group(3), "detail": ""}
            issues.append(cur); continue
        if cur is not None and line.startswith("  - 详情:"):
            cur["detail"] = line[len("  - 详情:"):]; continue
        if cur is not None and line.startswith("  ") and section.startswith("问题清单"):
            cur["detail"] += "\n" + line.strip(); continue
        if section and section.startswith("范围核对") and line.startswith("- "):
            scope.append(line[2:])
        if line.startswith("VERDICT:"):
            verdict = line.split(":", 1)[1].strip()
    return {"verdict": verdict, "issues": issues, "scope_findings": scope}

def events_stats(path):
    st = {"cmds": 0, "in": 0, "cached": 0, "out": 0, "reason": 0, "commands": []}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try: e = json.loads(line)
                except Exception: continue
                t = e.get("type")
                if t == "turn.completed":
                    u = e.get("usage", {})
                    st["in"] += u.get("input_tokens", 0); st["cached"] += u.get("cached_input_tokens", 0)
                    st["out"] += u.get("output_tokens", 0); st["reason"] += u.get("reasoning_output_tokens", 0)
                elif t == "item.completed" and e.get("item", {}).get("type") == "command_execution":
                    it = e["item"]; st["cmds"] += 1
                    st["commands"].append([it.get("command", ""), len(it.get("aggregated_output") or ""), it.get("exit_code")])
        s = os.stat(path)
        birth = getattr(s, "st_birthtime", None)
        if birth is None:
            import subprocess
            w = subprocess.run(["stat", "-c", "%W", path], capture_output=True, text=True).stdout.strip()
            birth = float(w) if w and w != "0" else None
        st["secs"] = round(s.st_mtime - birth) if birth else None
        st["mtime"] = s.st_mtime
    except FileNotFoundError:
        return None
    return st

with open(OUT, "w", encoding="utf-8") as out:
    for repo in REPOS:
        for td in sorted(glob.glob(f"{ROOT}/{repo}/.ai/*/*/")):
            parts = td.rstrip("/").split("/")
            date, slug = parts[-2], parts[-1]
            if not re.match(r"\d{4}-\d{2}-\d{2}$", date): continue
            for kind, mdpat, rawpat in (("plan", "plan-review-round-*-*.md", ".plan-review-raw-{nn}"),
                                        ("impl", "review-round-*-*.md", ".review-raw-{nn}")):
                for md in sorted(glob.glob(td + mdpat)):
                    base = os.path.basename(md)
                    m = re.match(r"(?:plan-)?review-round-(\d+)-(pass|fail)\.md$", base)
                    if not m: continue
                    if kind == "impl" and base.startswith("plan-"): continue
                    nn, v = m.group(1), m.group(2)
                    rec = {"repo": repo, "date": date, "task": slug, "kind": kind, "round": int(nn), "verdict": v}
                    rawbase = td + rawpat.format(nn=nn)
                    data = None
                    if os.path.exists(rawbase + ".json"):
                        try:
                            data = json.load(open(rawbase + ".json", encoding="utf-8"))
                            if data.get("verdict") != v: data = None  # stale raw
                        except Exception: data = None
                    if data is None:
                        data = parse_md(md); rec["src"] = "md"
                    else: rec["src"] = "raw"
                    rec["issues"] = data.get("issues", [])
                    rec["scope_findings"] = data.get("scope_findings", [])
                    rec["overall"] = data.get("overall", "")
                    rec["ev"] = events_stats(rawbase + ".events.jsonl")
                    rec["md_mtime"] = os.stat(md).st_mtime
                    out.write(json.dumps(rec, ensure_ascii=False) + "\n")
            # task-level facts
            plan = td + "plan.md"
            fm = {}
            if os.path.exists(plan):
                txt = open(plan, encoding="utf-8", errors="replace").read()
                m = re.match(r"---\n(.*?)\n---", txt, re.S)
                if m:
                    for l in m.group(1).splitlines():
                        if ":" in l:
                            k, val = l.split(":", 1); fm[k.strip()] = val.strip()
                ntc = len(set(re.findall(r"^\|\s*(TC-\d+)", txt, re.M)))
                out.write(json.dumps({"repo": repo, "date": date, "task": slug, "kind": "task", "fm": fm,
                                      "plan_bytes": len(txt.encode()), "n_tc": ntc,
                                      "n_impl": len(glob.glob(td + "implementation-round-*.md")),
                                      "has_summary": os.path.exists(td + "summary.md"),
                                      "n_evidence": len(glob.glob(td + "evidence/*"))}, ensure_ascii=False) + "\n")
