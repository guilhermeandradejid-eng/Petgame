class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var sprite_id: String = ""
@export var style: String = "walker"        # walker | hopper
@export var max_hp: int = 60
@export var exp: int = 12
@export var speed: float = 2.6
@export var aggro_m: float = 7.0
@export var attack_range_m: float = 1.7
@export var windup_ticks: int = 22
@export var recover_ticks: int = 34
@export var radius_m: float = 0.5
@export var dummy: bool = false
@export var attack: Resource                # AttackData
@export var attack_anim: String = "headbutt"
@export var lunge_tick: int = -1            # -1 = at the contact frame
@export var lunge_vy: float = 0.0
@export var hop_speed: float = 3.4
@export var blood_color: Color = Color(1, 0.7, 0.4, 1)
