class_name SpellData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var noun: String = ""           # must be a drawable object ("ice lance"), not an effect
@export var element: String = "ice"
@export var kind: String = "lance"      # lance | ring | comet
@export var mp_cost: int = 20
@export var cast_anim: String = "cast"
@export var speed: float = 15.0         # m/s (lance)
@export var life_ticks: int = 54
@export var damage: int = 22
@export var radius_px: float = 14.0     # lance: hit radius, ring: final radius is radius_m, comet: blast
@export var radius_m: float = 3.0
@export var knockback: float = 6.0
@export var launch_height_px: float = 10.0
@export var hitstop: int = 6
@export var shake: float = 0.4
@export var color: Color = Color(0.55, 0.9, 1.0, 1.0)
