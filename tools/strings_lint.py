"""Keeps player-facing text out of the code: every sentence the player sees lives in locale/strings.csv
and the code asks for it by key, with tr("KEY") (TranslationServer.translate("KEY") in static functions).

CI runs `python3 tools/strings_lint.py`, which fails when:
  - a script under autoload/ or scripts/ has a player-facing string literal outside tr(),
  - code asks for a key that locale/strings.csv doesn't have,
  - locale/strings.csv has a key nothing uses, a duplicate key, or an empty English text.

What counts as player-facing: a literal with words in it that isn't an id or key ("cow", "grows_into"),
a path, a colour ("#ffd34d"), a format with no words ("%d|%s"), a dictionary key or subscript, or a
Godot type name passed to the theme API. Developer messages (push_error, print, the catalog's validation
errors in scripts/catalog/) are not player-facing. A line ending in `# not-ui` is skipped: use it for a
capitalised id, and say what it is.

Constants can't call tr(): a constant holds the key, and the code that shows it calls tr().
"""
import csv
import glob
import re
import sys

STRINGS_CSV = "locale/strings.csv"
FILES = sorted(set(glob.glob("autoload/**/*.gd", recursive=True) + glob.glob("scripts/**/*.gd", recursive=True))
               - set(glob.glob("scripts/catalog/*.gd")))

STR = re.compile(r'"((?:\\.|[^"\\])*)"')
SKIP_LINE = re.compile(r"push_error|push_warning|\bprint\(|\bprints\(|\bassert\(|# not-ui\b")
THEME_API = re.compile(r"\b(set_stylebox|set_color|set_constant|set_font|set_font_size|add_theme_\w+|get_theme_\w+|"
                       r"has_theme_\w+|is_class|set_type_variation)\(")
KEY_CALL = re.compile(r'\b(?:tr|translate)\(\s*"([A-Z0-9_]+)"\s*\)')
KEY_LIKE = re.compile(r"[A-Z][A-Z0-9_]*")


def csv_keys():
    try:
        with open(STRINGS_CSV, newline="") as f:
            rows = list(csv.reader(f))
    except FileNotFoundError:
        return {}, ["%s is missing" % STRINGS_CSV]
    errors = []
    if not rows or rows[0][:2] != ["keys", "en"]:
        errors.append("%s: the first row must be keys,en" % STRINGS_CSV)
    keys = {}
    for n, row in enumerate(rows[1:], 2):
        if len(row) < 2 or row[1] == "":
            errors.append("%s:%d: %s has no English text" % (STRINGS_CSV, n, row[0] if row else "?"))
            continue
        if row[0] in keys:
            errors.append("%s:%d: duplicate key %s" % (STRINGS_CSV, n, row[0]))
        if not KEY_LIKE.fullmatch(row[0]):
            errors.append("%s:%d: key %s should be UPPER_SNAKE_CASE" % (STRINGS_CSV, n, row[0]))
        keys[row[0]] = row[1]
    return keys, errors


def player_facing(s, keys=()):
    if s in keys:
        return False                                   # a key, held in a constant
    if not re.search(r"[A-Za-z]{2}", s):
        return False
    if re.fullmatch(r"#[0-9a-fA-F]{3,8}", s):          # a colour
        return False
    if re.fullmatch(r"[a-z0-9_:/.\-]+", s):           # ids, keys, paths, file names
        return False
    if "%" in s:
        # A format: player text if, without its placeholders, there are words separated by spaces.
        words = re.sub(r"%[-+0-9.]*[a-zA-Z%]", " ", s)
        if not (re.search(r"[A-Za-z]{2}", words) and re.search(r"[A-Za-z]\s+[A-Za-z]|[A-Za-z]{2}\s", words.strip())):
            return False
    return True


def literals(lines, keys=()):
    """Yields (line index, start, end, raw text, mode) for player-facing literals. mode is "const" inside a
    constant, "static" inside a static function, "default-arg" in a function's default value, else "code"."""
    static_func = False
    const_open = 0  # bracket depth still open from a constant's declaration
    for n, line in enumerate(lines):
        top_level = re.match(r"[^\s#]", line) is not None
        if top_level and const_open == 0:
            static_func = line.startswith("static func")
        in_const = const_open > 0 or (top_level and line.startswith("const "))
        if in_const:
            const_open = max(0, const_open + _depth(line))
        if SKIP_LINE.search(line) or line.lstrip().startswith("#"):
            continue
        for m in STR.finditer(line):
            before = line[:m.start()]
            if _in_comment(before):
                break
            s = m.group(1)
            if not player_facing(s, keys):
                continue
            after = line[m.end():]
            if re.match(r"\s*:(?!=)", after):           # a dictionary key or a match pattern
                continue
            if re.search(r"[\w\])]\[\s*$", before):    # a subscript: d["Summer"]
                continue
            if re.search(r"\b(?:tr|translate)\(\s*$", before):
                continue
            if THEME_API.search(line) and re.fullmatch(r"[A-Z][A-Za-z0-9]+", s):
                continue
            if in_const:
                mode = "const"
            elif re.match(r"(static\s+)?func\s", line.lstrip()) and ")" not in before.split("(", 1)[-1]:
                mode = "default-arg"
            elif static_func:
                mode = "static"
            else:
                mode = "code"
            yield n, m.start(), m.end(), s, mode


def _depth(line):
    d = 0
    for m in re.finditer(r'"(?:\\.|[^"\\])*"|#.*|[\[\]{}()]', line):
        t = m.group(0)
        if t in "[{(":
            d += 1
        elif t in "]})":
            d -= 1
    return d


def _in_comment(before):
    stripped = STR.sub('""', before)
    return "#" in stripped


def main():
    keys, errors = csv_keys()
    used = set()
    for path in FILES:
        lines = open(path).read().split("\n")
        for n, _, _, s, mode in literals(lines, keys):
            errors.append("%s:%d: player-facing text in code (move it to %s): \"%s\"" % (
                path, n + 1, STRINGS_CSV, s[:70]))
        text = "\n".join(lines)
        for k in KEY_CALL.findall(text):
            used.add(k)
            if k not in keys:
                errors.append("%s: key %s isn't in %s" % (path, k, STRINGS_CSV))
        for k in STR.findall(text):
            if k in keys:
                used.add(k)
    # Keys can also be built in code from a known prefix ("WEATHER_" + state): declared here.
    for k in keys:
        if k not in used and not any(k.startswith(p) for p in DYNAMIC_PREFIXES):
            errors.append("%s: key %s isn't used anywhere" % (STRINGS_CSV, k))
    for e in errors:
        print(e)
    print("strings: %d keys, %d problems" % (len(keys), len(errors)))
    return 1 if errors else 0


# Keys the code builds from a prefix, so they can't be found literally.
DYNAMIC_PREFIXES = ["SEASON_", "BOOST_", "FED_FX_", "FEED_GRAIN", "FEED_GREENS", "FEED_ROOTS", "FEED_FRUIT", "FEED_NECTAR",
                    "YOU_FOUND_A_QUEEN_BEE_PUT"]  # names in data/feeds.json; a find family's `message` in data/finds.json

if __name__ == "__main__":
    sys.exit(main())
