class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var weapon_key: String = "sword"     # sprite/anim prefix: sword | spear | axe
@export var combo: Array = []                # Array[AttackData]  (3 hits)
@export var specials: Array = []             # Array[SpecialData] (2 techniques)
@export var color: Color = Color(0.75, 0.95, 1, 1)
@export var move_speed_mult: float = 1.0
