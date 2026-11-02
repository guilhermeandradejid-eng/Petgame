class_name SpecialData
extends Resource
## A weapon technique (Legend-of-Mana style): costs the SP gauge, has its own animation, and a
## drawable 3D noun for its effect ("cyclone", "javelin", "fissure", "meteor").

@export var id: String = ""
@export var display_name: String = ""
@export var anim: String = ""
@export var kind: String = "spin"        # spin | dive | thrusts | javelin | fissure
@export var sp_cost: int = 40
@export var damage: int = 10             # per hit (multi-hit specials hit once per contact frame)
@export var reach_px: float = 10.0
@export var radius_px: float = 38.0
@export var knockback: float = 3.0
@export var launch_height_px: float = 0.0
@export var hitstop: int = 3
@export var shake: float = 0.25
@export var lunge: float = 0.0
@export var color: Color = Color(1, 1, 1, 1)
@export var sfx: String = "swing_heavy"
