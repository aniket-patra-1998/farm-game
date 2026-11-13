class_name SocialSystem
extends GameSystem
## Neighbours, single-player (FarmVille's core loop; our own touch: an inbox where FarmVille had the feed).
## Reached as `Game.social`, behind Balance `social.enabled`.
##
## The inbox holds what neighbours send: gifts, requests for help, shares, and answers to your own posts.
## Free things are claimed with a tap (a share mints you a copy; the sharer keeps theirs); helping a request or
## a shared seedling pays a reward and counts against the day's helps. `help_all` does every one of them.
## The outbox holds your own posts: a frame or an empty tank asks for materials or fuel, a young one is shared
## for neighbours to water, a gift goes out free once a day per neighbour. Neighbours answer after a while.
##
## Who the neighbours are and how they behave is a `NeighbourTransport` (single-player: SimulatedNeighbours),
## so real friends can replace them without touching the rules here. Time is caught up in `settle` (on load and
## on a slow timer), never per frame. Saves the inbox, the outbox and the day's limits; nothing else.

const SAVED_INBOX := "social_inbox"
const SAVED_OUTBOX := "social_outbox"

var inbox: Array[Dictionary] = []
var outbox: Array[Dictionary] = []
var next_id := 1
var gift_day := 0                # the day `gifts_today` counts for
var gifts_today := {}            # neighbour index -> gifts sent them on that day
var help_day := 0                # the day `helps_today` counts for
var helps_today := 0
var last_settled := 0            # unix seconds the neighbours were last caught up to
var transport: NeighbourTransport


func _init(owner: GameState) -> void:
	super(owner)
	transport = SimulatedNeighbours.new()


func reset() -> void:
	inbox = []
	outbox = []
	next_id = 1
	gift_day = 0
	gifts_today = {}
	help_day = 0
	helps_today = 0
	last_settled = game.now()


func save_to(data: Dictionary) -> void:
	data[SAVED_INBOX] = inbox
	data[SAVED_OUTBOX] = outbox
	data["social_next_id"] = next_id
	data["social_gift_day"] = gift_day
	data["social_gifts_today"] = gifts_today
	data["social_help_day"] = help_day
	data["social_helps_today"] = helps_today
	data["social_last_settled"] = last_settled


func load_from(data: Dictionary) -> void:
	inbox = _mended(data.get(SAVED_INBOX, []))
	outbox = _mended(data.get(SAVED_OUTBOX, []))
	next_id = maxi(int(data.get("social_next_id", 1)), _highest_id() + 1)
	gift_day = int(data.get("social_gift_day", 0))
	gifts_today = GameSystem.int_map(data.get("social_gifts_today", {}))
	help_day = int(data.get("social_help_day", 0))
	helps_today = int(data.get("social_helps_today", 0))
	last_settled = mini(int(data.get("social_last_settled", game.now())), game.now())


func enabled() -> bool:
	return Balance.i("social.enabled") == 1


## The neighbours' names, by index.
func roster() -> Array[String]:
	return transport.roster()


## How many of today's helps are left (the count restarts each day).
func helps_left() -> int:
	return Balance.i("social.helps_per_day") - (helps_today if help_day == game.day_number() else 0)


## Items waiting that a tap would claim for free.
func free_count() -> int:
	return inbox.filter(InboxItem.is_free).size()


# ---------------------------------------------------------------- the inbox

## Claims one inbox item: free things are given, a request or shared seedling is helped for its reward.
## Returns whether it was claimed (a help is refused when none are left today).
func claim(item_id: int) -> bool:
	var at := _index_of(inbox, item_id)
	if not enabled() or at < 0:
		return false
	var item := inbox[at]
	if InboxItem.is_help(item):
		if helps_left() <= 0:
			game.message.emit(tr("SOCIAL_NO_HELPS_LEFT"))
			return false
		_count_help()
		game.add_coins(Balance.i("social.help_coins"), true)
		game.add_xp(Balance.i("social.help_xp"))
		game.ribbons.bump("neighbours_helped", 1)
		game.message.emit(tr("SOCIAL_HELPED") % Balance.i("social.help_coins"))
	else:
		game.message.emit(tr("SOCIAL_CLAIMED") % grant(item["give"]))
	inbox.remove_at(at)
	_changed()
	return true


## One tap: claims every free item, then helps every request and seedling the day allows, oldest first.
## Returns {"claimed", "helped", "left": helps still waiting that the day's limit held back}.
func help_all() -> Dictionary:
	var tally := {"claimed": 0, "helped": 0, "left": 0}
	if not enabled():
		return tally
	for item in inbox.duplicate():
		if InboxItem.is_free(item) and claim(int(item["id"])):
			tally["claimed"] += 1
	for item in inbox.duplicate():
		if not InboxItem.is_help(item):
			continue
		if helps_left() <= 0:
			tally["left"] += 1
		elif claim(int(item["id"])):
			tally["helped"] += 1
	game.message.emit(tr("SOCIAL_HELP_ALL") % [tally["claimed"], tally["helped"]])
	return tally


# ---------------------------------------------------------------- your own posts

## Has this neighbour had a gift from you today?
func gifted_today(neighbour: int) -> bool:
	var limit := Balance.i("social.gifts_per_neighbour_per_day")
	return gift_day == game.day_number() and int(gifts_today.get(str(neighbour), 0)) >= limit


## Sends a neighbour a free gift (once a day each). `give` is one of the data's gifts.
func send_gift(neighbour: int, give: Dictionary) -> bool:
	var g := InboxItem.clean_give(give)
	if not enabled() or g.is_empty() or neighbour < 0 or neighbour >= roster().size():
		return false
	if gifted_today(neighbour):
		game.message.emit(tr("SOCIAL_NO_GIFTS_LEFT"))
		return false
	if not _room_to_post():
		return false
	if gift_day != game.day_number():
		gift_day = game.day_number()
		gifts_today = {}
	gifts_today[str(neighbour)] = int(gifts_today.get(str(neighbour), 0)) + 1
	_post(InboxItem.GIFT, g, {"need": 1})
	game.ribbons.bump("gifts_sent", 1)
	return true


## Asks neighbours for `give` (n of a part, or fuel), once per thing per `ref` (a frame's uid, or 0).
func post_request(give: Dictionary, ref := 0) -> bool:
	var g := InboxItem.clean_give(give)
	if not enabled() or g.is_empty() or has_open(InboxItem.REQUEST, g["id"], ref) or not _room_to_post():
		return false
	_post(InboxItem.REQUEST, g, {"ref": ref, "need": g["n"]})
	game.message.emit(tr("SOCIAL_ASKED"))
	return true


## A frame asks for the materials it still lacks (up to `frame_ask_most` of each). Returns how many asks went out.
func post_frame_request(uid: int) -> int:
	var sent := 0
	var needs := game.land.construction_needs(game.object_by_uid(uid))
	for m: String in needs:
		var n := mini(int(needs[m]), Balance.i("social.frame_ask_most"))
		if post_request({"what": InboxItem.PART, "id": m, "n": n}, uid):
			sent += 1
	return sent


## An empty tank asks for fuel. (Only once a vehicle has been bought.)
func post_fuel_request() -> bool:
	if not game.vehicles.fuel_unlocked:
		return false
	return post_request({"what": InboxItem.FUEL, "id": "", "n": Balance.i("social.fuel_per_answer")})


## Shares a young one on the farm: neighbours water it (each feeding it once) and it is still yours alone.
func post_seedling_share(uid: int) -> bool:
	var o := game.object_by_uid(uid)
	if not enabled() or not game.nurture.is_young(o) or not _room_to_post():
		return false
	if has_open(InboxItem.SHARE, str(o["id"]), uid):
		return false
	_post(InboxItem.SHARE, {"what": InboxItem.YOUNG, "id": str(o["id"]), "n": 1}, {"collab": true, "ref": uid})
	game.ribbons.bump("shared_with_neighbours", 1)
	game.message.emit(tr("SOCIAL_SHARED"))
	return true


## Shares a find to be taken as a copy (coins to say thanks come back); you keep your own.
func post_share(give: Dictionary) -> bool:
	var g := InboxItem.clean_give(give)
	if not enabled() or g.is_empty() or not _room_to_post():
		return false
	_post(InboxItem.SHARE, g, {"collab": false})
	game.ribbons.bump("shared_with_neighbours", 1)
	game.message.emit(tr("SOCIAL_SHARED"))
	return true


## Is a post of this kind for this thing (and frame) still open?
func has_open(kind: String, thing: String, ref := 0) -> bool:
	for p in outbox:
		if p["kind"] == kind and str(p["give"]["id"]) == thing and int(p["ref"]) == ref:
			return true
	return false


# ---------------------------------------------------------------- time

## Catches the neighbours up to now: delivers answers that have come due and the mail that arrived while
## nobody looked (for at most `catchup_hours`). Returns a note about it, or "".
func settle() -> String:
	if not enabled():
		return ""
	var now := game.now()
	var answered := _deliver_answers(now)
	var from := maxi(last_settled, now - Balance.i("social.catchup_hours") * 3600)
	var arrived := 0
	if now > from:
		for item in transport.incoming(from, now):
			if inbox.size() >= Balance.i("social.inbox_limit"):
				break
			if _usable(item):
				_add_to_inbox(item)
				arrived += 1
	last_settled = now
	if answered + arrived > 0:
		_changed()
		return tr("SOCIAL_AWAY") % [arrived, answered]
	return ""


## Moves answers that have come due from the outbox into the inbox; lapsed posts go. Returns how many arrived.
func _deliver_answers(now: int) -> int:
	var arrived := 0
	var lapse := Balance.i("social.post_hours") * 3600
	for post in outbox.duplicate():
		for a: Dictionary in (post["answers"] as Array).duplicate():
			if int(a["due"]) > now or inbox.size() >= Balance.i("social.inbox_limit"):
				continue
			(post["answers"] as Array).erase(a)
			if _usable({"give": a["give"]}):
				_add_to_inbox(InboxItem.make(0, InboxItem.ANSWER, int(a["by"]), int(a["due"]), a["give"]))
				arrived += 1
		if (post["answers"] as Array).is_empty() or now - int(post["t"]) > lapse:
			outbox.erase(post)
	return arrived


## Fuel is only useful once there is a tank, and a watering only while the young one is still growing.
func _usable(item: Dictionary) -> bool:
	var give: Dictionary = item.get("give", {})
	match str(give.get("what", "")):
		InboxItem.FUEL:
			return game.vehicles.fuel_unlocked
		InboxItem.WATER:
			var o := game.object_by_uid(int(give.get("uid", 0)))
			return game.nurture.is_young(o) and game.nurture.fed(o) < game.nurture.needs(o)
	return true


# ---------------------------------------------------------------- giving what was claimed

## Hands over a `give` to the farm. Returns the words for it ("2 Bricks").
func grant(give: Dictionary) -> String:
	var n := int(give.get("n", 1))
	var id := str(give.get("id", ""))
	match str(give.get("what", "")):
		InboxItem.PART:
			game.daily.add_part(id, n)
			return "%d %s" % [n, GameState.part_names.get(id, id)]
		InboxItem.SUPPLY:
			game.nurture.add_supply(id, n)
			return "%d %s" % [n, game.nurture.supply_name(id)]
		InboxItem.COINS:
			game.add_coins(n, false)
			return tr("SOCIAL_COINS") % n
		InboxItem.FUEL:
			game.vehicles.add_fuel(n)
			return tr("SOCIAL_FUEL") % n
		InboxItem.YOUNG:
			for i in n:
				game.nurture.give_young(id)
			return "%d %s" % [n, game.item_data(id)["name"]]
		InboxItem.WATER:
			game.nurture.help_young(int(give.get("uid", 0)))
			return tr("SOCIAL_WATERED")
	return ""


# ---------------------------------------------------------------- inside

func _post(kind: String, give: Dictionary, extra: Dictionary) -> void:
	var post := InboxItem.make(next_id, kind, InboxItem.ME, game.now(), give, extra)
	next_id += 1
	post["answers"] = transport.answers_for(post, game.now())
	outbox.append(post)
	game.queue_save()


func _room_to_post() -> bool:
	return outbox.size() < Balance.i("social.outbox_limit")


func _add_to_inbox(item: Dictionary) -> void:
	item["id"] = next_id
	next_id += 1
	inbox.append(item)


func _count_help() -> void:
	if help_day != game.day_number():
		help_day = game.day_number()
		helps_today = 0
	helps_today += 1


func _changed() -> void:
	game.inbox_changed.emit()
	game.queue_save()


func _index_of(items: Array[Dictionary], item_id: int) -> int:
	for i in items.size():
		if int(items[i]["id"]) == item_id:
			return i
	return -1


func _highest_id() -> int:
	var top := 0
	for item in inbox + outbox:
		top = maxi(top, int(item["id"]))
	return top


func _mended(saved: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if saved is Array:
		for raw: Variant in saved:
			var item := InboxItem.clean(raw)
			if not item.is_empty():
				out.append(item)
	return out
