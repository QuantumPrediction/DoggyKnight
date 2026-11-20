#!/usr/bin/env python3
"""First-chapter functional audit of six routes; retain every failure."""
import concurrent.futures
import hashlib
import itertools
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get("DOGGY_ROUTE_AUDIT_OUT", ROOT / "docs/validation/0.9.0/route_audit")).resolve()

def run(case):
    hero, route, seed = case
    name = f"{hero}_route{route}_s{seed}"
    report = OUT / (name + ".json")
    if report.exists():
        raise RuntimeError(f"Refusing to overwrite prior audit {report}")
    command = ["godot", "--headless", "--path", str(ROOT), "--fixed-fps", "60", "--max-fps", "0", "--disable-render-loop",
        "res://tests/integration/playthrough_bot.tscn", "--", "--speed=1", "--chapter=1", f"--class={hero}",
        f"--route={route}", "--build=route", f"--seed={seed}", "--gear=common1", "--element=earth",
        "--policy=cautious", "--guard=reactive", "--max-downs=3", "--max-sim-seconds=1200", f"--report={report}"]
    with tempfile.TemporaryDirectory(prefix="doggy-route-") as save, (OUT / (name + ".log")).open("w") as log:
        try:
            code = subprocess.run(command, cwd=ROOT, env=dict(os.environ, XDG_DATA_HOME=save), stdout=log, stderr=subprocess.STDOUT, timeout=600).returncode
        except subprocess.TimeoutExpired:
            code = 124
    row = {"case": name, "exit_code": code}
    if report.exists():
        r = json.loads(report.read_text())
        row.update(route=r["route"], finished=r["finished"], downs=r["downs"], outcome=r["outcome"],
            damage=sum(x["damage_taken"] for x in r["attempts"]), cleared=sum(x["victory"] for x in r["attempts"]))
    text = (OUT / (name + ".log")).read_text()
    row["script_error"] = any(s in text for s in ["SCRIPT ERROR", "Parse Error", "Failed to load script"])
    print(json.dumps(row), flush=True)
    return row

if __name__ == "__main__":
    if OUT.exists() and any(OUT.iterdir()):
        raise SystemExit("Choose a fresh DOGGY_ROUTE_AUDIT_OUT; prior successes and failures must be retained.")
    OUT.mkdir(parents=True, exist_ok=True)
    engine = subprocess.check_output(["godot", "--version"], text=True).strip()
    assert engine == "4.7.2.stable.official.ed1daf0bf"
    cases = list(itertools.product(["knight", "mage", "archer"], [0, 1], [7, 19]))
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
        for folder in ["core", "game", "data", "ui", "tests/integration"] for p in sorted((ROOT/folder).rglob("*")) if p.suffix in [".gd", ".tscn", ".tres"]}
    (OUT/"manifest.json").write_text(json.dumps({"engine": engine, "cases": cases, "source_sha256": hashes,
        "rules": "Fixed 60Hz/speed1. Common1 earth purchased for 240 of 250 coins, no training/upgrades. Cautious movement/reactive guard; route-aware choices prefer evolution, then ordered route skills, then first. Other events choose index0. Isolated saves. No tuning or rejected-seed replacement. This is functional coverage, not a paired balance claim."}, indent=2)+"\n")
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        rows = list(pool.map(run, cases))
    (OUT/"summary.json").write_text(json.dumps(rows, indent=2)+"\n")
    raise SystemExit(int(any(r["exit_code"] not in [0,1] or r["script_error"] or "finished" not in r for r in rows)))
