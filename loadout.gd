class_name Loadout
extends RefCounted

const PATH := "user://loadout.cfg"
const SUITS := [
	{"name": "OLIVA", "suit": Color(0.36, 0.42, 0.28), "armor": Color(0.17, 0.2, 0.22)},
	{"name": "ACERO", "suit": Color(0.2, 0.25, 0.33), "armor": Color(0.13, 0.14, 0.16)},
	{"name": "URBANO", "suit": Color(0.33, 0.34, 0.36), "armor": Color(0.12, 0.12, 0.14)},
	{"name": "GRANATE", "suit": Color(0.4, 0.2, 0.2), "armor": Color(0.15, 0.12, 0.12)},
	{"name": "ARENA", "suit": Color(0.58, 0.5, 0.36), "armor": Color(0.3, 0.24, 0.17)},
]
const CHARACTERS := [
	{"name": "SOLDADO"},
	{"name": "OPERADOR"},
	{"name": "CIBER"},
]

static var primary := 1
static var secondary := 0
static var suit := 0
static var character := 0
static var melee := 0
static var throwable := 0
static var player_name := ""
const NAME_MAX := 14
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		primary = int(cf.get_value("loadout", "primary", primary))
		secondary = int(cf.get_value("loadout", "secondary", secondary))
		suit = int(cf.get_value("loadout", "suit", suit))
		character = int(cf.get_value("loadout", "character", character))
		melee = int(cf.get_value("loadout", "melee", melee))
		throwable = int(cf.get_value("loadout", "throwable", throwable))
		player_name = clean_name(String(cf.get_value("loadout", "name", player_name)))
	var n := Weapons.LIST.size()
	primary = clampi(primary, 0, n - 1)
	secondary = clampi(secondary, 0, n - 1)
	if secondary == primary:
		secondary = (primary + 1) % n
	suit = clampi(suit, 0, SUITS.size() - 1)
	character = clampi(character, 0, CHARACTERS.size() - 1)
	melee = clampi(melee, 0, Weapons.MELEE.size() - 1)
	throwable = clampi(throwable, 0, Weapons.THROW.size() - 1)


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("loadout", "primary", primary)
	cf.set_value("loadout", "secondary", secondary)
	cf.set_value("loadout", "suit", suit)
	cf.set_value("loadout", "character", character)
	cf.set_value("loadout", "melee", melee)
	cf.set_value("loadout", "throwable", throwable)
	cf.set_value("loadout", "name", clean_name(player_name))
	cf.save(PATH)


static func clean_name(n: String) -> String:
	return n.strip_edges().left(NAME_MAX)


static func display_name() -> String:
	ensure_loaded()
	var pn := clean_name(player_name)
	if pn != "":
		return pn
	var n := OS.get_model_name()
	if n == "" or n == "GenericDevice":
		return "Jugador"
	return clean_name(n)


static func slots() -> Array:
	ensure_loaded()
	return [primary, secondary]


static func melee_def() -> Dictionary:
	ensure_loaded()
	return Weapons.MELEE[melee]


static func throw_def() -> Dictionary:
	ensure_loaded()
	return Weapons.THROW[throwable]


static func suit_def() -> Dictionary:
	ensure_loaded()
	return SUITS[suit]
