#!/usr/bin/env python3
"""Lines of game script the start compiles before the first screen (docs/PERF_RUN.md, the start).

Walks the autoloads and the main scene over what makes Godot compile a script at load: class names used in code
(outside strings and comments), preload()s and a scene's resources. A script loaded by path at run time (load())
is not counted: that is how the start compiles less.

  python3 tools/start_lines.py               # the total
  python3 tools/start_lines.py -v            # and the 60 biggest scripts, each with what pulls it in
  python3 tools/start_lines.py --drop=A,B    # the total if nothing named the classes A and B
"""
import os
import re
import sys

SKIP = ("./.godot", "./tests", "./tools", "./addons")


def _strip(src):
    out = []
    for line in src.split("\n"):
        line = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
        line = re.sub(r"'(?:\\.|[^'\\])*'", "''", line)
        out.append(line.split("#")[0])
    return "\n".join(out)


def code_lines(path):
    return sum(1 for l in open(path).read().split("\n") if l.strip() and not l.strip().startswith("#"))


def main(args):
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    classes = {}
    for d, _, fs in os.walk("."):
        if d.startswith(SKIP):
            continue
        for f in fs:
            if f.endswith(".gd"):
                p = os.path.join(d, f)[2:]
                m = re.search(r"^class_name\s+(\w+)", open(p).read(), re.M)
                if m:
                    classes[m.group(1)] = p
    for a in args:
        if a.startswith("--drop="):
            for c in a[len("--drop="):].split(","):
                classes.pop(c, None)

    def deps(p):
        src = open(p).read()
        found = {m.group(1)[6:] for m in re.finditer(r'preload\(\s*"(res://[^"]+)"', src)}
        if p.endswith((".tscn", ".tres")):
            return found | {m.group(1)[6:] for m in re.finditer(r'path="(res://[^"]+)"', src)}
        for w in set(re.findall(r"\b([A-Z]\w+)\b", _strip(src))):
            if w in classes and classes[w] != p:
                found.add(classes[w])
        return found

    proj = open("project.godot").read()
    start = [m.group(1)[6:] for m in re.finditer(r'^\w+="\*?(res://[^"]+)"', proj.split("[autoload]")[1].split("\n[")[0], re.M)]
    start.append(re.search(r'run/main_scene="res://([^"]+)"', proj).group(1))
    seen, parent, stack = set(), {}, list(start)
    while stack:
        p = stack.pop()
        if p in seen or not os.path.exists(p):
            continue
        seen.add(p)
        if p.endswith((".gd", ".tscn", ".tres")):
            for q in deps(p):
                if q not in seen:
                    parent.setdefault(q, p)
                    stack.append(q)
    scripts = [p for p in seen if p.endswith(".gd")]
    print("scripts %d, code lines %d" % (len(scripts), sum(code_lines(p) for p in scripts)))
    if "-v" in args:
        for p in sorted(scripts, key=lambda p: -code_lines(p))[:60]:
            print(code_lines(p), p, "<-", parent.get(p))


if __name__ == "__main__":
    main(sys.argv[1:])
