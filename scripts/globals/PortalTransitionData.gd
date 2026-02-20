extends Node

# Global singleton to store portal transition data across scene changes
# This persists when scenes are changed (unlike metadata on scene nodes)

var is_correct_portal: bool = false
var return_position: Vector2 = Vector2.ZERO
var source_scene_path: String = ""
var has_data: bool = false
var is_returning: bool = false
var has_charge: bool = false  # Track if player picked up charge
var boss_phase: int = 0  # Save boss encounter phase
var boss_hp: int = 0  # Save boss health
var player_hp: int = 100  # Save player health
var player_max_hp: int = 100
var player_cooldowns: Dictionary = {}  # Save ability cooldowns
var player_dodge_charges: int = 0  # Save dodge charges
var player_dodge_recharge_accum: float = 0.0  # Save dodge recharge progress

func set_portal_data(is_correct: bool, return_pos: Vector2, source_path: String, encounter_phase: int = 1, boss_health: int = 2000, p_hp: int = 100, p_max_hp: int = 100, p_cooldowns: Dictionary = {}, p_dodge_charges: int = 0, p_dodge_accum: float = 0.0) -> void:
	is_correct_portal = is_correct
	return_position = return_pos
	source_scene_path = source_path
	has_data = true
	is_returning = false
	boss_phase = encounter_phase
	boss_hp = boss_health
	player_hp = p_hp
	player_max_hp = p_max_hp
	player_cooldowns = p_cooldowns.duplicate()
	player_dodge_charges = p_dodge_charges
	player_dodge_recharge_accum = p_dodge_accum
	
	pass

func set_return_data(return_pos: Vector2, source_path: String, player_has_charge: bool = false, encounter_phase: int = 0, boss_health: int = 0, p_hp: int = 100, p_max_hp: int = 100, p_cooldowns: Dictionary = {}, p_dodge_charges: int = 0, p_dodge_accum: float = 0.0) -> void:
	return_position = return_pos
	source_scene_path = source_path
	is_returning = true
	has_charge = player_has_charge
	boss_phase = encounter_phase
	boss_hp = boss_health
	player_hp = p_hp
	player_max_hp = p_max_hp
	player_cooldowns = p_cooldowns.duplicate()
	player_dodge_charges = p_dodge_charges
	player_dodge_recharge_accum = p_dodge_accum
	
	pass

func clear_data() -> void:
	is_correct_portal = false
	return_position = Vector2.ZERO
	source_scene_path = ""
	has_data = false
	is_returning = false
	has_charge = false
	boss_phase = 0
	boss_hp = 0
	player_hp = 100
	player_max_hp = 100
	player_cooldowns = {}
	player_dodge_charges = 0
	player_dodge_recharge_accum = 0.0
	
	pass
