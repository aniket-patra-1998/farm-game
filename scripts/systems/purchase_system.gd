class_name PurchaseSystem
extends GameSystem
## In-app purchases (docs/PURCHASES.md): three gem packs and a one-time starter pack, bought through Google Play
## Billing (the official GodotGooglePlayBilling plugin, MIT; Android only). data/store.json says what each gives;
## Play Console holds the prices, and the game shows Play's own price text. A purchase is given the moment Play
## says it is paid, kept by its token so it is never given twice (a crash between being paid and being consumed
## gives it once, on the next start: Play hands back what was not consumed), then consumed (packs) or
## acknowledged (the starter pack, which Play then remembers as owned). Single-player, so no server checks it.
## Part of the game state: reached as `Game.purchases`.

const CONFIG := "res://data/store.json"
const PLUGIN := "GodotGooglePlayBilling"   # not-ui (the Android singleton's name)
const CLIENT := "res://addons/GodotGooglePlayBilling/BillingClient.gd"   # not-ui
const TOKENS_KEPT := 64   # tokens remembered as given (only the latest matter: Play hands back only unconsumed ones)
const PURCHASED := 1      # BillingClient.PurchaseState.PURCHASED
const PENDING := 2        # BillingClient.PurchaseState.PENDING
const OK := 0             # BillingClient.BillingResponseCode.OK
const INAPP := 0          # BillingClient.ProductType.INAPP
const PRIZES := {"gems": "gems", "coins": "coins", "farmhands": "farmhand", "unwithers": "unwither",
	"fertilize_alls": "fertilize_all"}   # not-ui (a pack's counts as Mystery Box prizes, for their words)

static var client: Node   # the BillingClient, on an Android build with the plugin; null elsewhere (no store shown)

var owned := {}          # one-time product id -> true (the starter pack, once bought)
var given: Array = []    # purchase tokens already given (newest last)
var prices := {}         # product id -> Play's price text ("₹89.00"), once Play answered
var amounts := {}        # product id -> [price in the currency's smallest unit, ISO currency] (for the statistics)
var _products := {}      # product id -> what it gives (data/store.json)
var _order: Array[String] = []


func _init(owner: GameState) -> void:
	super(owner)


## Made once by the game: the billing client, on Android with the plugin only.
static func begin_store(game: GameState) -> void:
	if client != null or not Engine.has_singleton(PLUGIN):
		return
	client = (load(CLIENT) as GDScript).new()
	client.name = "Billing"   # not-ui (a node name)
	game.add_child(client)
	var me := game.purchases
	client.connect("connected", me._on_connected)
	client.connect("query_product_details_response", me._on_details)
	client.connect("query_purchases_response", me._on_purchases)
	client.connect("on_purchase_updated", me._on_purchases)
	client.call("start_connection")


func load_data() -> void:
	_products.clear()
	_order.clear()
	for p: Dictionary in game.read_json(CONFIG).get("products", []):
		_products[str(p["id"])] = p
		_order.append(str(p["id"]))


func reset() -> void:
	owned = {}
	given = []


func save_to(data: Dictionary) -> void:
	data["purchases"] = {"owned": owned.keys(), "given": given.duplicate()}


func load_from(data: Dictionary) -> void:
	var d: Dictionary = data.get("purchases", {}) if data.get("purchases") is Dictionary else {}
	owned = {}
	for id: Variant in d.get("owned", []):
		owned[str(id)] = true
	given = []
	for t: Variant in d.get("given", []):
		given.append(str(t))


## Whether the store can sell now (Play answered with its prices).
func open() -> bool:
	return client != null and not prices.is_empty()


## The products on sale now, in data/store.json's order (the starter pack until it is bought).
func on_sale() -> Array[String]:
	var out: Array[String] = []
	for id in _order:
		if not (bool(_products[id].get("one_time", false)) and owned.has(id)):
			out.append(id)
	return out


## What `id` gives, in words ("240 gems", "60 gems, 10,000 coins, 2 Farmhands...").
func words(id: String) -> String:
	var parts := PackedStringArray()
	for k: String in PRIZES:
		if _products.get(id, {}).has(k):
			parts.append(MysterySystem.prize_words([PRIZES[k], int(_products[id][k])]))
	return ", ".join(parts)


## Opens Play's purchase sheet for `id`.
func buy(id: String) -> void:
	if not open() or not prices.has(id):
		game.message.emit(tr("STORE_UNAVAILABLE"))
		return
	var r: Dictionary = client.call("purchase", id)
	if int(r.get("response_code", -1)) != OK:
		game.message.emit(tr("STORE_UNAVAILABLE"))


## A purchase Play reports (bought now, or left from before): given once, then consumed or acknowledged.
func take(p: Dictionary) -> void:
	var token := str(p.get("purchase_token", ""))
	var ids: Array = Array(p.get("product_ids", []))
	if token == "" or ids.is_empty():
		return
	if int(p.get("purchase_state", 0)) == PENDING:
		game.message.emit(tr("STORE_PENDING"))
		return
	if int(p.get("purchase_state", 0)) != PURCHASED:
		return
	var id := str(ids[0])
	if not given.has(token) and _products.has(id):
		_give(id)
		given.append(token)
		while given.size() > TOKENS_KEPT:
			given.pop_front()
		game.queue_save()
	if client == null:
		return
	if bool(_products.get(id, {}).get("one_time", false)):
		if not bool(p.get("is_acknowledged", false)):
			client.call("acknowledge_purchase", token)
	else:
		client.call("consume_purchase", token)


func _give(id: String) -> void:
	var p: Dictionary = _products[id]
	game.add_gems(int(p.get("gems", 0)))
	game.add_coins(int(p.get("coins", 0)), false)
	game.farmhands += int(p.get("farmhands", 0))
	game.add_unwithers(int(p.get("unwithers", 0)))
	game.fertilize_alls += int(p.get("fertilize_alls", 0))
	if bool(p.get("one_time", false)):
		owned[id] = true
	if Analytics.shared != null and amounts.has(id):   # (a business event: real revenue in the statistics)
		Analytics.shared.business("pack" if bool(p.get("one_time", false)) else "gems", id,
			int(amounts[id][0]), str(amounts[id][1]))
	game.message.emit(tr("STORE_THANKS") % words(id))
	game.inventory_changed.emit()


func _on_connected() -> void:
	client.call("query_product_details", PackedStringArray(_order), INAPP)
	client.call("query_purchases", INAPP)   # (anything paid for but not given: a crash mid-purchase)


func _on_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK:
		return
	for d: Dictionary in r.get("product_details", []):
		var offers: Variant = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not (offers as Array).is_empty():
			var offer: Dictionary = (offers as Array)[0]
			prices[str(d["product_id"])] = str(offer.get("formatted_price", ""))
			amounts[str(d["product_id"])] = [roundi(int(offer.get("price_amount_micros", 0)) / 10000.0),
				str(offer.get("price_currency_code", ""))]   # (micros to paise or cents)
	game.inventory_changed.emit()   # (the Gems page shows the prices once they come)


func _on_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != OK:
		return
	for p: Dictionary in r.get("purchases", []):
		take(p)
