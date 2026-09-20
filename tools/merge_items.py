#!/usr/bin/env python3
import json, os, shutil, sys, uuid
from pathlib import Path

LIB = Path.home() / "Library/Application Support/Hold/library.json"

def main(add_path: str) -> int:
    add = json.loads(Path(add_path).read_text(encoding="utf-8"))
    lib = json.loads(LIB.read_text(encoding="utf-8"))
    if isinstance(lib, list):
        lib = {"tabs": sorted({i["cat"] for i in lib}), "items": lib}
    items = lib.get("items", [])
    tabs = lib.get("tabs", [])
    seen = {(i["cat"], i["label"]) for i in items}
    added = 0
    for e in add:
        key = (e["cat"], e["label"])
        if key in seen:
            continue
        items.append({
            "id": str(uuid.uuid4()).upper(),
            "cat": e["cat"],
            "group": e["group"],
            "label": e["label"],
            "desc": e["desc"],
        })
        seen.add(key)
        if e["cat"] not in tabs:
            tabs.append(e["cat"])
        added += 1
    lib["tabs"], lib["items"] = tabs, items
    shutil.copy2(LIB, str(LIB) + ".bak")
    tmp = str(LIB) + ".tmp"
    Path(tmp).write_text(json.dumps(lib, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, LIB)
    print(f"{added} hinzugefügt, {len(items)} gesamt")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))