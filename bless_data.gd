class_name BlessCardData
extends RefCounted

var card_name: String = ""
var side: int = 1
var display_text: String = ""
var effect: Dictionary = {}

static func _make(name: String, side: int, text: String, eff: Dictionary) -> BlessCardData:
	var b := BlessCardData.new()
	b.card_name = name
	b.side = side
	b.display_text = text
	b.effect = eff
	return b

# Returns one Side I card for each of the 9 Bless cards.
static func create_deck() -> Array:
	return [
		_make("Blessing of Protection", 1, "Block 4", {"type": "bless_block", "value": 4}),
		_make("Blessing of Healing",    1, "Cleanse + Heal 3", {"type": "bless_heal", "value": 3, "cleanse": true}),
		_make("Blessing of Power",      1, "+3 dmg next attack", {"type": "bless_damage_bonus", "value": 3}),
		_make("Blessing of Judgement",  1, "Ignore Block (next atk)", {"type": "bless_ignore_block", "all": false}),
		_make("Blessing of Vigor",      1, "+2 Stamina this turn", {"type": "bless_stamina", "value": 2}),
		_make("Blessing of Conversion", 1, "Remove condition → Blk 2", {"type": "bless_convert_condition", "heal": 0}),
		_make("Blessing of Retribution",1, "Reflect damage this turn", {"type": "bless_reflect", "multiplier": 1}),
		_make("Blessing of Passage",    1, "+1 Move this turn", {"type": "bless_move", "value": 1}),
		_make("Blessing of Luck",       1, "No effect (no Modifier Deck)", {"type": "bless_luck"}),
	]

# Returns the Side II version of a given card (by name).
static func flipped(card: BlessCardData) -> BlessCardData:
	match card.card_name:
		"Blessing of Protection":
			return _make("Blessing of Protection", 2, "Block 6", {"type": "bless_block", "value": 6})
		"Blessing of Healing":
			return _make("Blessing of Healing", 2, "Cleanse + Heal 5", {"type": "bless_heal", "value": 5, "cleanse": true})
		"Blessing of Power":
			return _make("Blessing of Power", 2, "+5 dmg next attack", {"type": "bless_damage_bonus", "value": 5})
		"Blessing of Judgement":
			return _make("Blessing of Judgement", 2, "Ignore Block (all atks)", {"type": "bless_ignore_block", "all": true})
		"Blessing of Vigor":
			return _make("Blessing of Vigor", 2, "+4 Stamina this turn", {"type": "bless_stamina", "value": 4})
		"Blessing of Conversion":
			return _make("Blessing of Conversion", 2, "Remove condition → Blk 2 or Heal 2", {"type": "bless_convert_condition", "heal": 2})
		"Blessing of Retribution":
			return _make("Blessing of Retribution", 2, "Reflect 2× damage", {"type": "bless_reflect", "multiplier": 2})
		"Blessing of Passage":
			return _make("Blessing of Passage", 2, "+3 Move this turn", {"type": "bless_move", "value": 3})
		"Blessing of Luck":
			return _make("Blessing of Luck", 2, "No effect (no Modifier Deck)", {"type": "bless_luck"})
	return null

static func from_name_side(name: String, side: int) -> BlessCardData:
	for card in create_deck():
		var b: BlessCardData = card as BlessCardData
		if b.card_name == name:
			return b if side == 1 else flipped(b)
	return null

func to_dict() -> Dictionary:
	return {"card_name": card_name, "side": side}

static func from_dict(data: Dictionary) -> BlessCardData:
	return from_name_side(String(data.get("card_name", "")), int(data.get("side", 1)))
