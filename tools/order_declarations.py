"""Puts a GDScript file's top-level declarations in the standard order (the one gdlint checks):
signals, enums, constants, static variables, exported, public and private variables, @onready variables,
then everything else (functions, inner classes, section comments) in its original order.

Comments directly above a declaration move with it. Usage: python3 tools/order_declarations.py FILE...
"""
import re
import sys

ORDER = ["signal", "enum", "const", "static var", "export", "var", "_var", "onready"]


def category(line):
    s = line.strip()
    if s.startswith("signal "):
        return "signal"
    if s.startswith("enum "):
        return "enum"
    if s.startswith("const "):
        return "const"
    if s.startswith("static var "):
        return "static var"
    if s.startswith("@export"):
        return "export"
    if s.startswith("@onready"):
        return "onready"
    if s.startswith("var "):
        return "_var" if re.match(r"var _", s) else "var"
    return None


def chunks(lines):
    """Splits a file into (kind, lines) chunks: 'header', 'blank', or a top-level statement with its comments."""
    out = []
    i = 0
    n = len(lines)
    pending = []
    while i < n:
        line = lines[i]
        if line.strip() == "":
            if pending:  # a comment block followed by a blank line stands alone
                out.append(("comment", pending))
                pending = []
            out.append(("blank", [line]))
            i += 1
            continue
        if line.startswith("#"):
            pending.append(line)
            i += 1
            continue
        body = pending + [line]
        pending = []
        i += 1
        # Absorb the statement's indented lines (and blank lines inside it).
        while i < n:
            nxt = lines[i]
            if nxt.startswith("\t") or nxt.startswith(" ") or nxt[:1] in ")]}":
                body.append(nxt)  # the statement's body, or the bracket that closes it
                i += 1
                continue
            if nxt.strip() == "":
                j = i
                while j < n and lines[j].strip() == "":
                    j += 1
                if j < n and (lines[j].startswith("\t") or lines[j].startswith(" ")):
                    body.extend(lines[i:j])
                    i = j
                    continue
            break
        code = [l for l in body if not l.startswith("#")][0]
        if re.match(r"(class_name|extends|@tool)\b", code):
            out.append(("header", body))
        else:
            out.append((category(code) or "other", body))
    if pending:
        out.append(("comment", pending))
    return out


def reorder(text):
    lines = text.split("\n")
    parts = chunks(lines)
    # The header: class_name/extends, then the class doc comment if it stands on its own.
    k = 0
    while k < len(parts) and parts[k][0] in ("header", "blank"):
        k += 1
    if k < len(parts) and parts[k][0] == "comment":
        k += 1
    header = parts[:k]
    rest = parts[k:]
    groups = {c: [] for c in ORDER}
    others = []
    for kind, body in rest:
        if kind in groups:
            groups[kind].append(body)
        elif kind == "blank":
            continue
        else:
            others.append(body)
    out = []
    for kind, body in header:
        out.extend(body)
    while out and out[-1].strip() == "":
        out.pop()
    for c in ORDER:
        if not groups[c]:
            continue
        out.append("")
        for idx, body in enumerate(groups[c]):
            if idx > 0 and (len(body) > 1 or body[0].startswith("#")):
                out.append("")
            out.extend(body)
    for body in others:
        out.extend(["", ""])
        out.extend(body)
    return "\n".join(out).rstrip("\n") + "\n"


if __name__ == "__main__":
    for path in sys.argv[1:]:
        src = open(path).read()
        new = reorder(src)
        if new != src:
            open(path, "w").write(new)
            print("reordered", path)
