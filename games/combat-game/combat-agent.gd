extends KinematicBody2D

signal agent_removed(value)
signal agent_killed(side, is_hit)

export (float) var speed = 20.0 # waa 50.0
export (float) var lateral_speed = 20.0
export (float) var rotation_speed = 1.0 # was 0.5
export (float) var speed_limit = 110.0
export (float) var lateral_speed_limit = 80.0
export (float) var rotation_speed_limit = 2.0
# export(PackedScene) var Agent

const NN = preload("res://scripts/neural_network.gd")
const Laser = preload("res://other/projectile/laser.tscn")

onready var ray_forward = get_node("ray_forward")
onready var ray_left = get_node("ray_left")
onready var ray_right = get_node("ray_right")
onready var ray_f_up_right = get_node("ray_f_up_right")
onready var ray_f_down_right = get_node("ray_f_down_right")
onready var projectile_pos = get_node("ProjectilePos")
onready var cooldown_timer = get_node("ShootingCooldownTimer")

var nn_activated_inputs := [] # set by the level
var genome: Genome
var nn: NeuralNetwork
var battle_cage_width = 950
var battle_cage_height = 590
var battle_cage

var population
var game
var side
var velocity = Vector2()
var is_dead: bool = false
# var current_fitness := 0.0
var can_shoot := true
var Agent
var nn_rotation := 0.0
var real_speed := 0.0
var real_lateral_speed := 0.0


func _ready():
  assert(genome != null, "genome is not initialized in combat agent")
  nn = NN.new(genome)
  Agent = game.Agent


func _physics_process(delta):
  if !is_dead:
    var nn_controls := get_nn_controls(nn, get_sensor_input())
    rotation += nn_controls["nn_rotation"] * rotation_speed * delta
    # rotation = nn_controls["nn_rotation_target"] * PI

    real_speed = clamp(nn_controls["nn_move_forward"] * speed, -speed_limit, speed_limit)
    real_lateral_speed = clamp(nn_controls["nn_move_right"] * lateral_speed ,
        -lateral_speed_limit, lateral_speed_limit)
    velocity = Vector2(real_speed, real_lateral_speed).rotated(rotation)
    velocity = move_and_slide(velocity)

    if nn_controls["nn_shooting"] > 0.0:
      shoot()
  else:
    if nn != null && nn.is_dissolved:
      nn = null
    rotation = 0.0
    velocity = 0.0


func get_nn_controls(_nn: NN, sensor_input: Dictionary) -> Dictionary:
  velocity = Vector2()
  _nn.set_input(sensor_input)
  var nn_output = _nn.get_output() # a dict

  # Apply a threshold in rotations
  var input_rotation = nn_output["turn_right"]
  nn_rotation = clamp(input_rotation, -rotation_speed_limit, rotation_speed_limit)

  # New: rotation target
  # var nn_rotation_target = nn_output["rotation_target"]

  var nn_move_forward = nn_output["move_forward"]
  var nn_move_right = nn_output["move_right"]
  var nn_shooting = nn_output["shooting"]
  return {
      "nn_rotation": nn_rotation,
      # "nn_rotation_target": nn_rotation_target,
      "nn_move_forward": nn_move_forward,
      "nn_move_right": nn_move_right,
      "nn_shooting": nn_shooting
  }


func get_opponent():
  var opponent
  assert(side != null, "Agent side is null")
  if side == Main.Side.LEFT:
    opponent = battle_cage.agent_right
  elif side == Main.Side.RIGHT:
    opponent = battle_cage.agent_left
  return opponent


# func get_opponent_pos():
#   var opponent_pos
#   assert(side != null, "Agent side is null")
#   if side == Main.Side.LEFT:
#     opponent_pos = battle_cage.agent_right_pos
#   elif side == Main.Side.RIGHT:
#     opponent_pos = battle_cage.agent_left_pos
#   return opponent_pos


func get_sensor_input():
  var newrot: float
  var norm_pos_x: float
  var norm_pos_y: float

  var ray_f_distance: float
  var ray_left_distance: float
  var ray_right_distance: float
  var ray_f_up_right_distance: float
  var ray_f_down_right_distance: float

  var rf_col_normal_angle: float
  var rl_col_normal_angle: float
  var rr_col_normal_angle: float
  var rfu_col_normal_angle: float
  var rfd_col_normal_angle: float

  var move_forward_input: float
  var move_right_input: float
  var turn_right_input: float
  var shooting_input: float

  var opponent_angle: float
  var opponent_distance: float
  var traced_laser_1_angle: float
  var traced_laser_1_distance: float

  if nn_activated_inputs.has("rotation"):
    var current_rot = rotation
    newrot = current_rot / PI

  if nn_activated_inputs.has("pos_x"):
    norm_pos_x = global_position.x / battle_cage_width
  if nn_activated_inputs.has("pos_y"):
    norm_pos_y = global_position.y / battle_cage_height

  if nn_activated_inputs.has("ray_f_distance") || nn_activated_inputs.has("rf_col_normal_angle"):
    ray_f_distance = 0.0
    rf_col_normal_angle = 0.0
    if ray_forward.is_colliding():
      var distance = global_position.distance_to(ray_forward.get_collision_point())
      var col = ray_forward.get_collider()

      if nn_activated_inputs.has("rf_col_normal_angle"):
        var col_normal = ray_forward.get_collision_normal()
        rf_col_normal_angle = col_normal.angle() / PI

      if col.is_in_group("normal_walls"):
        # ray_f_distance = distance / ray_forward.cast_to.x
        ray_f_distance = (ray_forward.cast_to.x - distance) / ray_forward.cast_to.x

  if nn_activated_inputs.has("ray_left_distance") || nn_activated_inputs.has("rl_col_normal_angle"):
    ray_left_distance = 0.0 # is was 1.0
    rl_col_normal_angle = 0.0
    if ray_left.is_colliding():
      var distance = global_position.distance_to(ray_left.get_collision_point())
      var col = ray_left.get_collider()

      if nn_activated_inputs.has("rl_col_normal_angle"):
        var col_normal = ray_left.get_collision_normal()
        rl_col_normal_angle = col_normal.angle() / PI

      if col.is_in_group("normal_walls"):
        ray_left_distance = (abs(ray_left.cast_to.y) - distance) / abs(ray_left.cast_to.y)

  if nn_activated_inputs.has("ray_right_distance") || nn_activated_inputs.has("rr_col_normal_angle"):
    ray_right_distance = 0.0 # is was 1.0
    rr_col_normal_angle = 0.0
    if ray_right.is_colliding():
      var distance = global_position.distance_to(ray_right.get_collision_point())
      var col = ray_right.get_collider()

      if nn_activated_inputs.has("rr_col_normal_angle"):
        var col_normal = ray_right.get_collision_normal()
        rr_col_normal_angle = col_normal.angle() / PI

      if col.is_in_group("normal_walls"):
        ray_right_distance = (ray_right.cast_to.y - distance) / ray_right.cast_to.y

  if nn_activated_inputs.has("ray_f_up_right_distance") || nn_activated_inputs.has("rfu_col_normal_angle"):
    ray_f_up_right_distance = 0.0
    rfu_col_normal_angle = 0.0
    if ray_f_up_right.is_colliding():
      var distance = global_position.distance_to(ray_f_up_right.get_collision_point())
      var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_up_right.cast_to.x,
          ray_f_up_right.cast_to.y))
      var col = ray_f_up_right.get_collider()

      if nn_activated_inputs.has("rfu_col_normal_angle"):
        var col_normal = ray_f_up_right.get_collision_normal()
        rfu_col_normal_angle = col_normal.angle() / PI

      if col.is_in_group("normal_walls"):
        ray_f_up_right_distance = (ray_length - distance) / ray_length

  if nn_activated_inputs.has("ray_f_down_right_distance") || nn_activated_inputs.has("rfd_col_normal_angle"):
    ray_f_down_right_distance = 0.0
    rfd_col_normal_angle = 0.0
    if ray_f_down_right.is_colliding():
      var distance = global_position.distance_to(ray_f_down_right.get_collision_point())
      var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_down_right.cast_to.x,
          ray_f_down_right.cast_to.y))
      var col = ray_f_down_right.get_collider()

      if nn_activated_inputs.has("rfd_col_normal_angle"):
        var col_normal = ray_f_down_right.get_collision_normal()
        rfu_col_normal_angle = col_normal.angle() / PI

      if col.is_in_group("normal_walls"):
        ray_f_down_right_distance = (ray_length - distance) / ray_length

  if nn_activated_inputs.has("move_forward_input"):
    # move_forward_input = clamp(velocity.x, 0, speed_limit) / speed_limit
    move_forward_input = clamp(real_speed, 0, speed_limit) / speed_limit

  if nn_activated_inputs.has("move_right_input"):
    # move_right_input = clamp(velocity.y, -lateral_speed_limit, lateral_speed_limit) / lateral_speed_limit
    move_right_input = clamp(real_lateral_speed, -lateral_speed_limit, lateral_speed_limit) / lateral_speed_limit

  if nn_activated_inputs.has("turn_right_input"):
    turn_right_input = (nn_rotation / rotation_speed_limit) * (get_physics_process_delta_time() * rotation_speed)

  if nn_activated_inputs.has("shooting_input"):
    shooting_input = cooldown_timer.time_left / cooldown_timer.wait_time

  if nn_activated_inputs.has("opponent_angle") \
      || nn_activated_inputs.has("opponent_distance"):
    var opponent = get_opponent()
    # if opponent == null:
    if !is_instance_valid(opponent) || !opponent.is_inside_tree():
      opponent_distance = 0.0
      opponent_angle = 0.0
    else:
      var opponent_pos = opponent.global_position
      # opponent_angle = global_position.angle_to_point(opponent_pos) / PI

      # var vector_to_enemy = opponent_pos - global_position
      var vector_to_enemy = global_position.direction_to(opponent_pos)
      var agent_facing_vector = Vector2.RIGHT.rotated(rotation)
      opponent_angle = agent_facing_vector.angle_to(vector_to_enemy) / PI

      opponent_distance = (global_position.distance_to(opponent_pos) \
          / sqrt(pow(battle_cage_width, 2.0) * pow(battle_cage_height, 2.0)))

  if nn_activated_inputs.has("traced_laser_1_angle") || \
      nn_activated_inputs.has("trase_laser_1_distance"):
    var traced_laser_1
    if side == Main.Side.LEFT:
      if !battle_cage.left_traced_lasers.empty():
        traced_laser_1 = battle_cage.left_traced_lasers[0]
    elif side == Main.Side.RIGHT:
      if !battle_cage.right_traced_lasers.empty():
        traced_laser_1 = battle_cage.right_traced_lasers[0]
    if !is_instance_valid(traced_laser_1) || !traced_laser_1.is_inside_tree():
      traced_laser_1_distance = 0.0
      traced_laser_1_angle = 0.0
    else:
      var traced_laser_pos = traced_laser_1.global_position
      traced_laser_1_angle = global_position.angle_to_point(traced_laser_pos) / PI
      traced_laser_1_distance = 1.0 - (global_position.distance_to(traced_laser_pos) \
          / sqrt(pow(battle_cage_width, 2.0) * pow(battle_cage_height, 2.0)))

  var inp_dict = {
        "rotation": newrot,
        "pos_x": norm_pos_x,
        "pos_y": norm_pos_y,

        "ray_f_distance": ray_f_distance,
        "ray_f_up_right_distance": ray_f_up_right_distance,
        "ray_f_down_right_distance": ray_f_down_right_distance,
        "ray_left_distance": ray_left_distance,
        "ray_right_distance": ray_right_distance,

        "rf_col_normal_angle": rf_col_normal_angle,
        "rl_col_normal_angle": rl_col_normal_angle,
        "rr_col_normal_angle": rr_col_normal_angle,
        "rfu_col_normal_angle": rfu_col_normal_angle,
        "rfd_col_normal_angle": rfd_col_normal_angle,

        "turn_right_input": turn_right_input,
        "move_forward_input": move_forward_input,
        "move_right_input": move_right_input,
        "shooting_input": shooting_input,

        "opponent_angle": opponent_angle,
        "opponent_distance": opponent_distance,
        "traced_laser_1_angle": traced_laser_1_angle,
        "traced_laser_1_distance": traced_laser_1_distance,
      }

  var activated_input_dict := {}
  for input in nn_activated_inputs:
    activated_input_dict[input] = inp_dict[input]

  return activated_input_dict


func shoot():
  if can_shoot:
    var laser = Laser.instance()
    laser.global_position = projectile_pos.global_position
    laser.global_rotation = projectile_pos.global_rotation
    laser.side = side
    get_tree().get_root().add_child(laser)
    can_shoot = false
    cooldown_timer.start()


func get_fitness():
  # return current_fitness
  return genome.fitness


func kill_agent(is_hit := false):
  dissolve_agent()
  emit_signal("agent_removed", 1)
  emit_signal("agent_killed", side, is_hit)
  queue_free()


func dissolve_agent():
  if is_dead:
    return
  is_dead = true
  # yield(get_tree(), "idle_frame")
  if nn != null: # Needed in the case of a copy
    nn.dissolve_nn()
    nn = null
  genome.dissolve_genome()
  genome = null


func copy():
  var agent: Node2D
  agent = Agent.instance()
  agent.population = population
  # agent.current_fitness = current_fitness
  agent.nn_activated_inputs = game.input_names.duplicate()
  agent.game = game

  var new_genome = Genome.new(population)
  new_genome.copy(genome)
  agent.genome = new_genome

  return agent


func _on_agent_hit(agent_id):
  if agent_id == get_instance_id():
    kill_agent(true)


func _on_ShootingCooldownTimer_timeout():
  can_shoot = true

