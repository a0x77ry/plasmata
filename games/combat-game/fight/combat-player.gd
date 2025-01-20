extends KinematicBody2D

signal player_dead

export (float) var speed = 10000.0 # waa 50.0
export (float) var lateral_speed = 10000.0
export (float) var rotation_speed = 10.0 # was 0.5
export (float) var speed_limit = 110.0
export (float) var lateral_speed_limit = 80.0
export (float) var rotation_speed_limit = 2.0
export (float) var laser_cooldown = 1.3

const Laser = preload("res://other/projectile/laser.tscn")
const combat_blue = Color(0.57, 0.58, 0.96, 1.0)

onready var projectile_pos = get_node("ProjectilePos")
onready var cooldown_timer = get_node("ShootingCooldownTimer")
onready var battle_cage = get_parent().get_node("BattleCage")

var velocity = Vector2.ZERO
var can_shoot := true
var player_side = Main.Side.LEFT
var side = player_side
var normalized_vel = Vector2.ZERO
var temp_vel = Vector2.ZERO
var game

# to be used as inputs to the opponent
var forward_movement
var right_movement


func _ready():
  var err = connect("player_dead", game, "_on_player_dead")
  if err != OK:
    print("Could not connect player_dead signal to fight game")

  get_node("Sprite").modulate = combat_blue
  cooldown_timer.wait_time = laser_cooldown


func _physics_process(delta):
  var forward: float = Input.get_action_strength("forward") \
      - Input.get_action_strength("back")
  var lateral_right_movement: float = Input.get_action_strength("lateral_right")\
      - Input.get_action_strength("lateral_left")

  # var right_rotation_rate: float = Input.get_action_strength("right") \
  #     - Input.get_action_strength("left")
  # rotate(right_rotation_rate * rotation_speed * delta)

  look_at(get_global_mouse_position())

  normalized_vel = Vector2(forward, lateral_right_movement)

  # Set the inputs for the opponent
  forward_movement = forward
  right_movement = lateral_right_movement

  # var vel = Vector2(forward * speed * delta,
  #     lateral_right_movement * lateral_speed * delta).rotated(rotation)
  temp_vel = Vector2(normalized_vel.x * speed, normalized_vel.y * lateral_speed).rotated(rotation) * delta
  velocity = move_and_slide(temp_vel)
  if Input.get_action_strength("shoot"):
    shoot()


func shoot():
  if can_shoot:
    var laser = Laser.instance()
    laser.global_position = projectile_pos.global_position
    laser.global_rotation = projectile_pos.global_rotation
    laser.side = player_side
    laser.agent = self
    laser.opponent_agent = get_opponent()
    battle_cage.all_active_lasers.append(laser)
    get_tree().get_root().add_child(laser)
    can_shoot = false
    cooldown_timer.start()


func get_opponent():
  var opponent
  assert(side != null, "Agent side is null")
  if side == Main.Side.LEFT:
    opponent = battle_cage.agent_right
  elif side == Main.Side.RIGHT:
    opponent = battle_cage.agent_left
  return opponent


func dissolve_agent():
  queue_free()


func kill_agent():
  emit_signal("player_dead")
  queue_free()


func _on_agent_hit():
  kill_agent()


# func _on_laser_hit():
#   can_shoot = true

func _on_ShootingCooldownTimer_timeout():
  can_shoot = true

