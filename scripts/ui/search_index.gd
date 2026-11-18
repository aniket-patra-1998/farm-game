class_name SearchIndex
extends RefCounted
## Finding things by what is typed (docs/SEARCH.md; our own engineering, pure and tested): built once per list
## from its ids and the words each is found by ({name, more}, ItemSearch.words_of or a card's name), each made
## plain (lower case, letters and digits, a plural brought to its one: "eggs" is "egg") and kept as one string
## per id ("|chicken|coop|"), all of them end to end, so a query is a few `find`s over one string run by the
## engine, not a loop over every thing.
## Ranking: a word of the name typed whole, then a word of the name begun, then the other words the same way,
## then inside a word; every typed word must be found (more words, fewer things). With nothing found, a longer
## word may be one letter off ("strawbery").

const NAME_WHOLE := 100
const NAME_START := 60
const MORE_WHOLE := 40
const MORE_START := 25
const NAME_INSIDE := 15
const MORE_INSIDE := 5
const TYPO := 20
const BAR := 124   # "|", between words
const PLACE_BITS := 32   # a ranking key: the score above these bits, the place in the list below
const PLACE_MASK := (1 << PLACE_BITS) - 1
const INSIDE_FROM := 3   # a typed word this long may match inside a word, not only at its start

static var _plain: RegEx

var ids: Array[String] = []
var _names: PackedStringArray = []   # each id's name, plain ("|chicken|coop|")
var _more: PackedStringArray = []    # each id's other words, plain
var _shown_names: PackedStringArray = []   # each name as written (for "did you mean")
var _all_names := ""                 # every name, end to end (searched at once)
var _all_more := ""
var _name_at := PackedInt32Array()   # where each thing's name begins in _all_names
var _more_at := PackedInt32Array()


## An index of `list`, each found by `words_of(id)` ({name, more}).
func _init(list: Array[String], words_of: Callable) -> void:
	ids = list
	for id in list:
		var w: Dictionary = words_of.call(id)
		_names.append(_haystack(str(w.get("name", ""))))
		_more.append(_haystack(str(w.get("more", ""))))
		_shown_names.append(str(w.get("name", "")))
	var names := PackedStringArray()
	var more := PackedStringArray()
	var n_at := 0
	var m_at := 0
	for k in ids.size():
		var a := _names[k] if _names[k] != "" else "|"
		var b := _more[k] if _more[k] != "" else "|"
		_name_at.append(n_at)
		_more_at.append(m_at)
		names.append(a)
		more.append(b)
		n_at += a.length()
		m_at += b.length()
	_all_names = "".join(names)
	_all_more = "".join(more)


## The ids that match `query` (all of them for an empty one), best first, then in the list's own order; `keep`
## (id) -> bool narrows them further (the menu's filters).
func find(query: String, keep := Callable()) -> Array[String]:
	var words := words_in(query)
	var order := PackedInt32Array()
	if words.is_empty():
		order.resize(ids.size())
		for k in ids.size():
			order[k] = k
	else:
		var total := PackedInt32Array()   # each place's score so far (the first word's, then added to)
		var alive := PackedInt32Array()   # the places every word so far was found in
		for n in words.size():
			var best := PackedInt32Array()
			best.resize(ids.size())
			var touched := _found(words[n], best)
			if n == 0:
				alive = touched
				total = best   # (the first word's scores are the total so far: no loop to add them)
				continue
			var still := PackedInt32Array()
			for k in alive:
				if best[k] > 0:
					still.append(k)
					total[k] += best[k]
			alive = still
			if alive.is_empty():
				break
		if alive.is_empty():
			var typos := _typos(words)
			for k: int in typos:
				alive.append(k)
				total[k] = TYPO
		order = _ranked(alive, total)
	var out: Array[String] = []
	if not keep.is_valid():
		out.resize(order.size())
		for i in order.size():
			out[i] = ids[order[i]]
		return out
	for k in order:
		if keep.call(ids[k]):
			out.append(ids[k])
	return out


## The name nearest to `query` (one or two letters off), "" when none is near: what "did you mean" offers.
func nearest(query: String) -> String:
	var q := " ".join(words_in(query))
	if q.length() < ItemSearch.rule("typo_from"):
		return ""
	var best := ""
	var best_d := 3
	for k in ids.size():
		var name := _names[k].trim_prefix("|").trim_suffix("|").replace("|", " ")
		if absi(name.length() - q.length()) >= best_d:
			continue
		var d := distance(q, name, best_d)
		if d < best_d:
			best_d = d
			best = _shown_names[k]
	return best


## Words of `text`, plain: lower case, only letters and digits, plurals as one ("berries" -> "berry").
static func words_in(text: String) -> PackedStringArray:
	if _plain == null:
		_plain = RegEx.create_from_string("[^\\p{L}\\p{N}]+")
	var out := PackedStringArray()
	for w in _plain.sub(text.to_lower(), " ", true).split(" ", false):
		out.append(one_of(w))
	return out


## A word's one ("eggs" -> "egg", "berries" -> "berry", "boxes" -> "box"; "grass" stays).
static func one_of(w: String) -> String:
	if w.length() > 4 and w.ends_with("ies"):
		return w.left(-3) + "y"
	if w.length() > 3 and (w.ends_with("ses") or w.ends_with("xes") or w.ends_with("zes") or w.ends_with("ches")
			or w.ends_with("shes")):
		return w.left(-2)
	if w.length() > 3 and w.ends_with("s") and not w.ends_with("ss"):
		return w.left(-1)
	return w


## How many letters apart `a` and `b` are (inserted, removed or changed), counting no higher than `most`.
static func distance(a: String, b: String, most := 3) -> int:
	if absi(a.length() - b.length()) >= most:
		return most
	var before := PackedInt32Array()
	for j in b.length() + 1:
		before.append(j)
	for i in a.length():
		var row := PackedInt32Array([i + 1])
		var low := i + 1
		for j in b.length():
			var v := mini(mini(before[j + 1] + 1, row[j] + 1), before[j] + (0 if a[i] == b[j] else 1))
			row.append(v)
			low = mini(low, v)
		if low >= most:
			return most
		before = row
	return mini(before[b.length()], most)


func _haystack(text: String) -> String:
	var words := words_in(text)
	return "|" + "|".join(words) + "|" if not words.is_empty() else ""


## Where word `w` is found: each place's best score into `best` (the names first, then the other words); the
## places it was found in, in order.
func _found(w: String, best: PackedInt32Array) -> PackedInt32Array:
	var touched := PackedInt32Array()
	_mark(best, touched, _all_names, _name_at, w, [NAME_WHOLE, NAME_START, NAME_INSIDE])
	_mark(best, touched, _all_more, _more_at, w, [MORE_WHOLE, MORE_START, MORE_INSIDE])
	return touched


## Marks every place word `w` turns up in `all` (one string of every thing's words; `at` where each thing's
## begin): whole word, word begun or (a longer word) inside one, `scores` in that order.
func _mark(best: PackedInt32Array, touched: PackedInt32Array, all: String, at: PackedInt32Array, w: String,
		scores: Array) -> void:
	var anywhere := w.length() >= maxi(INSIDE_FROM, ItemSearch.rule("least_letters"))
	var needle := w if anywhere else "|" + w
	var whole: int = scores[0]
	var begun: int = scores[1]
	var inside: int = scores[2]
	var last := at.size() - 1
	var k := 0   # the thing the hit is in: hits come in order, so it only moves forward (no search per hit)
	var pos := all.find(needle)
	while pos >= 0:
		var from := pos if anywhere else pos + 1   # (where the typed word itself begins)
		var score := inside
		if all.unicode_at(from - 1) == BAR:   # (a code, not a one-letter String made per hit)
			score = whole if all.unicode_at(from + w.length()) == BAR else begun
		while k < last and at[k + 1] <= from:
			k += 1
		if best[k] == 0:
			touched.append(k)
		if score > best[k]:
			best[k] = score
		pos = all.find(needle, pos + 1)


## `places` best first by `score`, then in the list's order: one sort run by the engine over keys that hold both
## (the score above, the place below), not a loop that groups them.
static func _ranked(places: PackedInt32Array, score: PackedInt32Array) -> PackedInt32Array:
	var keys := PackedInt64Array()
	keys.resize(places.size())
	var n := 0
	for k in places:
		keys[n] = (int(-score[k]) << PLACE_BITS) | k
		n += 1
	keys.sort()
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		out[i] = keys[i] & PLACE_MASK
	return out


## With nothing found: things whose name has a word one letter off each longer typed word.
func _typos(words: PackedStringArray) -> Dictionary:
	var from := ItemSearch.rule("typo_from")
	var out := {}
	for k in ids.size():
		var name_words := _names[k].split("|", false)
		var ok := true
		for w in words:
			if w.length() < from:
				ok = _names[k].contains("|" + w) or _more[k].contains("|" + w)
			else:
				ok = false
				for n in name_words:
					if distance(w, n, 2) <= 1 or (n.length() > w.length() and distance(w, n.left(w.length()), 2) <= 1):
						ok = true
						break
			if not ok:
				break
		if ok:
			out[k] = TYPO
	return out
