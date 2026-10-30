#!/usr/bin/env python3
"""Builds the Diff Anything Alfred workflow from workflow/ into dist/Diff Anything.alfredworkflow.

The workflow has three entry points, each running workflow/diffanything.sh and showing its
message, if it prints one, as a notification:
  - the file action "Compare in Diff Anything", for two files or two folders chosen in Alfred;
  - the keyword "diff" (configurable), for the two items selected in Finder;
  - the keyword "diffclip" (configurable), for the last two texts in Alfred's Clipboard History.
Usage: python3 build.py   (writes dist/ and prints the package's path)
"""
import plistlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "workflow"
VERSION = "1.0.0"
README = (ROOT / "README.md").read_text(encoding="utf-8")


def uid(n: int) -> str:
    """Stable object ids, so rebuilding gives the same file."""
    return f"D1FFA000-0000-4000-8000-{n:012d}"


def script(n: int, command: str) -> dict:
    return {
        "uid": uid(n),
        "type": "alfred.workflow.action.script",
        "version": 2,
        "config": {
            "concurrently": False,
            "escaping": 102,
            "script": f'/bin/zsh --no-rcs ./diffanything.sh {command}',
            "scriptargtype": 1,
            "scriptfile": "",
            # Alfred's built-in Run Script template uses type 0 (/bin/bash).
            # Invoke zsh explicitly above so the generated action uses that documented template.
            "type": 0,
        },
    }


def keyword(n: int, variable: str, text: str, subtext: str) -> dict:
    return {
        "uid": uid(n),
        "type": "alfred.workflow.input.keyword",
        "version": 1,
        "config": {
            "argumenttype": 2,
            "keyword": f"{{var:{variable}}}",
            "subtext": subtext,
            "text": text,
            "withspace": False,
        },
    }


NOTIFICATION = 9
objects = [
    {
        "uid": uid(1),
        "type": "alfred.workflow.trigger.action",
        "version": 1,
        "config": {"acceptsmulti": True, "filetypes": [], "name": "Compare in Diff Anything"},
    },
    script(2, 'files "$@"'),
    keyword(3, "files_keyword", "Compare the two items selected in Finder",
            "Opens two files or two folders side by side in Diff Anything"),
    script(4, "finder"),
    keyword(5, "clipboard_keyword", "Compare the last two copied texts",
            "Earlier copy on the left, latest on the right, in Diff Anything"),
    {
        "uid": uid(6),
        "type": "alfred.workflow.utility.argument",
        "version": 1,
        "config": {
            "argument": "",
            "passthroughargument": False,
            "variables": {"older_text": "{clipboard:1}", "newer_text": "{clipboard}"},
        },
    },
    script(7, "text"),
    {
        "uid": uid(NOTIFICATION),
        "type": "alfred.workflow.output.notification",
        "version": 1,
        "config": {
            "lastpathcomponent": False,
            "onlyshowifquerypopulated": True,
            "removeextension": False,
            "text": "{query}",
            "title": "Diff Anything",
        },
    },
]


def link(destination: int) -> list:
    return [{"destinationuid": uid(destination), "modifiers": 0, "modifiersubtext": "", "vitoclose": False}]


connections = {
    uid(1): link(2), uid(2): link(NOTIFICATION),
    uid(3): link(4), uid(4): link(NOTIFICATION),
    uid(5): link(6), uid(6): link(7), uid(7): link(NOTIFICATION),
}
uidata = {
    uid(1): {"xpos": 30.0, "ypos": 30.0}, uid(2): {"xpos": 230.0, "ypos": 30.0},
    uid(3): {"xpos": 30.0, "ypos": 170.0}, uid(4): {"xpos": 230.0, "ypos": 170.0},
    uid(5): {"xpos": 30.0, "ypos": 310.0}, uid(6): {"xpos": 200.0, "ypos": 340.0},
    uid(7): {"xpos": 290.0, "ypos": 310.0}, uid(NOTIFICATION): {"xpos": 480.0, "ypos": 170.0},
}


def text_setting(variable: str, label: str, default: str) -> dict:
    return {
        "type": "textfield",
        "variable": variable,
        "label": label,
        "description": "",
        "config": {"default": default, "placeholder": "", "required": True, "trim": True},
    }


info = {
    "bundleid": "com.martingruner.alfred.diffanything",
    "category": "Productivity",
    "connections": connections,
    "createdby": "Martin Grüner",
    "description": "Compare two files, two folders, or two copied texts in the Diff Anything app",
    "disabled": False,
    "name": "Diff Anything",
    "objects": objects,
    "readme": README,
    "uidata": uidata,
    "userconfigurationconfig": [
        text_setting("files_keyword", "Finder selection keyword", "diff"),
        text_setting("clipboard_keyword", "Copied texts keyword", "diffclip"),
    ],
    "version": VERSION,
    "webaddress": "https://martingruner.com/projects/diffanything",
}

dist = ROOT / "dist"
dist.mkdir(exist_ok=True)
(dist / "info.plist").write_bytes(plistlib.dumps(info, sort_keys=True))
package = dist / "Diff Anything.alfredworkflow"
with zipfile.ZipFile(package, "w", zipfile.ZIP_DEFLATED) as archive:
    def add(name: str, data: bytes, mode: int) -> None:
        entry = zipfile.ZipInfo(name, date_time=(2026, 10, 29, 0, 0, 0))
        entry.external_attr = (0o100000 | mode) << 16
        entry.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(entry, data)
    add("info.plist", (dist / "info.plist").read_bytes(), 0o644)
    add("icon.png", (SOURCE / "icon.png").read_bytes(), 0o644)
    add("diffanything.sh", (SOURCE / "diffanything.sh").read_bytes(), 0o755)
print(package)
