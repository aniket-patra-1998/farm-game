"""Wraps GDScript lines longer than a limit, using GDScript's implicit line continuation inside brackets.

A long call or literal is split at its top-level commas, one argument per line; an argument that is still
too long and is a plain string is split into joined pieces. Lines it can't wrap safely are left alone and
reported. Usage: python3 tools/wrap_long_lines.py LIMIT FILE...
"""
import sys


def scan(line):
    """Yields (index, char, depth_before, in_string) for each character, aware of strings and comments."""
    depth = 0
    quote = None
    i = 0
    while i < len(line):
        c = line[i]
        if quote:
            yield i, c, depth, True
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        else:
            if c == "#":
                return
            if c in "\"'":
                quote = c
                yield i, c, depth, True
            else:
                yield i, c, depth, False
                if c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
        i += 1


def split_string(arg, indent, limit):
    """'"long text"' -> pieces joined with + on separate lines, or None if it isn't a plain string."""
    s = arg.strip()
    if len(s) < 2 or s[0] != '"' or s[-1] != '"' or '"' in s[1:-1].replace('\\"', ""):
        return None
    body = s[1:-1]
    room = max(40, limit - len(indent.expandtabs(4)) - 6)
    pieces = []
    while len(body) > room:
        cut = body.rfind(" ", 0, room)
        if cut <= 0:
            break
        pieces.append(body[: cut + 1])
        body = body[cut + 1 :]
    pieces.append(body)
    if len(pieces) == 1:
        return None
    return [indent + '"' + p + '"' + (" +" if k < len(pieces) - 1 else "") for k, p in enumerate(pieces)]


def wrap(line, limit):
    if len(line.expandtabs(4)) <= limit:
        return [line]
    indent = line[: len(line) - len(line.lstrip("\t"))]
    # The first bracket whose contents reach (nearly) the end of the line.
    opens = {}
    best = None
    for i, c, d, in_str in scan(line):
        if in_str:
            continue
        if c in "([{":
            opens[d] = i
        elif c in ")]}":
            start = opens.get(d - 1)
            if start is not None and (best is None or start < best[0]) and i - start > 40:
                best = (start, i)
    if best is None:
        return None
    start, end = best
    inner = line[start + 1 : end]
    args = []
    cur = ""
    for _, c, d, in_str in scan(inner):
        if c == "," and d == 0 and not in_str:
            args.append(cur.strip())
            cur = ""
        else:
            cur += c
    if cur.strip():
        args.append(cur.strip())
    sub = indent + "\t"
    out = [line[: start + 1]]
    for k, a in enumerate(args):
        piece = sub + a + ("," if k < len(args) - 1 else "")
        if len(piece.expandtabs(4)) > limit:
            pieces = split_string(a, sub, limit)
            if pieces is None:
                nested = wrap(sub + a, limit)
                if nested is None:
                    return None
                pieces = nested
            if k < len(args) - 1:
                pieces[-1] += ","
            out.extend(pieces)
        else:
            out.append(piece)
    out.append(indent + line[end:].lstrip() if line[end:].strip() else indent + line[end])
    return out


if __name__ == "__main__":
    limit = int(sys.argv[1])
    for path in sys.argv[2:]:
        lines = open(path).read().split("\n")
        out = []
        changed = False
        for n, line in enumerate(lines, 1):
            w = wrap(line, limit)
            if w is None:
                print(f"{path}:{n}: couldn't wrap")
                out.append(line)
            else:
                changed |= w != [line]
                out.extend(w)
        if changed:
            open(path, "w").write("\n".join(out))
            print("wrapped", path)
