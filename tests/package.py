#!/usr/bin/env python3
"""Exercise the packaged Run Script actions through their actual shell wrapper."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    unpacked = work / "workflow"
    with zipfile.ZipFile(root / "dist/Diff Anything.alfredworkflow") as archive:
        archive.extractall(unpacked)
        info = plistlib.loads(archive.read("info.plist"))
    app = work / "Diff Anything.app"
    (app / "Contents").mkdir(parents=True)
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleShortVersionString": "1.7.0"}))
    recorder = work / "open"
    recorder.write_text('#!/bin/zsh --no-rcs\nprint -rl -- "$@" > "$OPEN_LOG"\n')
    recorder.chmod(0o755)
    env = dict(os.environ, DIFF_ANYTHING_APP=str(app), DIFF_ANYTHING_OPEN=str(recorder),
               OPEN_LOG=str(work / "opened"), alfred_workflow_cache=str(work / "cache"))
    actions = [o["config"] for o in info["objects"] if o["type"] == "alfred.workflow.action.script"]
    assert len(actions) == 3
    assert all(a["type"] == 0 and a["scriptargtype"] == 1 for a in actions)
    paths = [work / 'Café original ; echo injected.txt', work / 'Före "updated".txt']
    for path in paths:
        path.write_text("Bread 3.50\n")
    files = next(a for a in actions if ' files ' in a["script"])
    subprocess.run(["/bin/bash", "-c", files["script"], "alfred-action", *map(str, paths)],
                   env=env, cwd=unpacked, check=True, capture_output=True)
    assert (work / "opened").read_text().splitlines() == ["-a", str(app), *map(str, paths)]
    text = next(a for a in actions if a["script"].endswith(" text"))
    earlier = 'Line one\n$(touch should-not-exist)\n"quoted" & `literal`\n'
    latest = 'Line 1\nSecond line\n'
    subprocess.run(["/bin/bash", "-c", text["script"]], env=dict(env, older_text=earlier, newer_text=latest),
                   cwd=unpacked, check=True, capture_output=True)
    opened = (work / "opened").read_text().splitlines()
    assert Path(opened[2]).read_text() == earlier
    assert Path(opened[3]).read_text() == latest
    assert Path(opened[2]).stat().st_mode & 0o777 == 0o600
    assert Path(opened[2]).parent.stat().st_mode & 0o777 == 0o700
    assert not (unpacked / "should-not-exist").exists()
    uids = {o["uid"] for o in info["objects"]}
    for origin, edges in info["connections"].items():
        assert origin in uids
        assert all(edge["destinationuid"] in uids for edge in edges)
    assert len([o for o in info["objects"] if o["type"] == "alfred.workflow.trigger.action"]) == 1
print("Packaged file/text actions preserve arguments and private text exactly; graph is connected.")
