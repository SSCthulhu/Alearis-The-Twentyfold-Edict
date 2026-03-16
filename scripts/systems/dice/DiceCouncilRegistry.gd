extends RefCounted
class_name DiceCouncilRegistry

const CATASTROPHE_EVENT_PATH: String = "res://data/dice_meter/events_v2/Roll01_TotalCouncilControl_Catastrophe.tres"
const MIRACLE_EVENT_PATH: String = "res://data/dice_meter/events_v2/Roll20_DiceGodIntervention_Miracle.tres"

const _COUNCIL_EVENT_PATHS: Dictionary = {
	2: "res://data/dice_meter/events_v2/Roll02_Shadows_Council.tres",
	3: "res://data/dice_meter/events_v2/Roll03_Fire_Council.tres",
	4: "res://data/dice_meter/events_v2/Roll04_Gravity_Council.tres",
	5: "res://data/dice_meter/events_v2/Roll05_Chains_Council.tres",
	6: "res://data/dice_meter/events_v2/Roll06_Frost_Council.tres",
	7: "res://data/dice_meter/events_v2/Roll07_Poison_Council.tres",
	8: "res://data/dice_meter/events_v2/Roll08_Lightning_Council.tres",
	9: "res://data/dice_meter/events_v2/Roll09_Time_Council.tres",
	10: "res://data/dice_meter/events_v2/Roll10_Blood_Council.tres",
	11: "res://data/dice_meter/events_v2/Roll11_Illusions_Council.tres",
	12: "res://data/dice_meter/events_v2/Roll12_Chaos_Council.tres",
	13: "res://data/dice_meter/events_v2/Roll13_Storm_Council.tres",
	14: "res://data/dice_meter/events_v2/Roll14_Stone_Council.tres",
	15: "res://data/dice_meter/events_v2/Roll15_Void_Council.tres",
	16: "res://data/dice_meter/events_v2/Roll16_Corruption_Council.tres",
	17: "res://data/dice_meter/events_v2/Roll17_War_Council.tres",
	18: "res://data/dice_meter/events_v2/Roll18_Doom_Council.tres",
	19: "res://data/dice_meter/events_v2/Roll19_Judgment_Council.tres"
}

const _DIVINE_EVENT_PATHS: Dictionary = {
	2: "res://data/dice_meter/events_v2/Roll02_Shadows_Divine.tres",
	3: "res://data/dice_meter/events_v2/Roll03_Fire_Divine.tres",
	4: "res://data/dice_meter/events_v2/Roll04_Gravity_Divine.tres",
	5: "res://data/dice_meter/events_v2/Roll05_Chains_Divine.tres",
	6: "res://data/dice_meter/events_v2/Roll06_Frost_Divine.tres",
	7: "res://data/dice_meter/events_v2/Roll07_Poison_Divine.tres",
	8: "res://data/dice_meter/events_v2/Roll08_Lightning_Divine.tres",
	9: "res://data/dice_meter/events_v2/Roll09_Time_Divine.tres",
	10: "res://data/dice_meter/events_v2/Roll10_Blood_Divine.tres",
	11: "res://data/dice_meter/events_v2/Roll11_Illusions_Divine.tres",
	12: "res://data/dice_meter/events_v2/Roll12_Chaos_Divine.tres",
	13: "res://data/dice_meter/events_v2/Roll13_Storm_Divine.tres",
	14: "res://data/dice_meter/events_v2/Roll14_Stone_Divine.tres",
	15: "res://data/dice_meter/events_v2/Roll15_Void_Divine.tres",
	16: "res://data/dice_meter/events_v2/Roll16_Corruption_Divine.tres",
	17: "res://data/dice_meter/events_v2/Roll17_War_Divine.tres",
	18: "res://data/dice_meter/events_v2/Roll18_Doom_Divine.tres",
	19: "res://data/dice_meter/events_v2/Roll19_Judgment_Divine.tres"
}

const _MEMBER_NAMES: Dictionary = {
	2: "Umbrix", 3: "Pyraxis", 4: "Gravemind", 5: "Chainwarden",
	6: "Rimecaller", 7: "Venomseer", 8: "Voltarch", 9: "Chronarch",
	10: "Hemalord", 11: "Mirrormask", 12: "Pandemon", 13: "Tempest Vicar",
	14: "Stone Regent", 15: "Null Apostle", 16: "Blight Herald",
	17: "War Marshal", 18: "Doom Bell", 19: "Final Arbiter"
}

const _MEMBER_THEMES: Dictionary = {
	2: "Shadows", 3: "Fire", 4: "Gravity", 5: "Chains",
	6: "Frost", 7: "Poison", 8: "Lightning", 9: "Time",
	10: "Blood", 11: "Illusions", 12: "Chaos", 13: "Storm",
	14: "Stone", 15: "Void", 16: "Corruption", 17: "War",
	18: "Doom", 19: "Judgment"
}

static func build_members() -> Dictionary:
	var members: Dictionary = {}
	for number: int in range(2, 20):
		var name: String = String(_MEMBER_NAMES.get(number, "Council Member %d" % number))
		var theme: String = String(_MEMBER_THEMES.get(number, "Unknown"))
		var council_path: String = String(_COUNCIL_EVENT_PATHS.get(number, ""))
		var divine_path: String = String(_DIVINE_EVENT_PATHS.get(number, ""))
		var council_event: Resource = load(council_path) as Resource if council_path != "" else null
		var divine_event: Resource = load(divine_path) as Resource if divine_path != "" else null
		members[number] = DiceCouncilMember.new(number, name, theme, council_event, divine_event)
	return members

static func load_council_catastrophe_event() -> Resource:
	return load(CATASTROPHE_EVENT_PATH) as Resource

static func load_divine_miracle_event() -> Resource:
	return load(MIRACLE_EVENT_PATH) as Resource
