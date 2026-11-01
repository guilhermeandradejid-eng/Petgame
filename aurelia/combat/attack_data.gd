class_name AttackData
extends Resource
## One hit of a combo / one enemy attack. Timing comes from the animation contract
## (the contact frame), never from here.

@export var id: String = ""
@export var anim: String = ""
@export var damage: int = 10
@export var knockback: float = 5.0          # horizontal m/s
@export var launch_height_px: float = 0.0   # explicit apex in sprite px (juggle-safe)
@export var reach_px: float = 20.0          # hitbox centre in front of feet
@export var radius_px: float = 22.0
@export var lunge: float = 0.0              # forward m/s burst on contact start
@export var hitstop: int = 4                # ticks frozen on hit (both sides)
@export var shake: float = 0.25
@export var trail_color: Color = Color(1, 1, 1, 1)
@export var sfx: String = "swing"
@export var hit_sfx: String = "hit"
