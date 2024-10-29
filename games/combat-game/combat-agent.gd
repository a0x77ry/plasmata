extends KinematicBody2D

signal agent_removed(value)

export (float) var speed = 20.0 # waa 50.0
export (float) var rotation_speed = 1.0 # was 0.5
export (float) var speed_limit = 110.0
export (float) var rotation_speed_limit = 2.0

const NN = preload("res://scripts/neural_network.gd")

onready var ray_forward = get_node("ray_forward")
onready var ray_left = get_node("ray_left")
onready var ray_right = get_node("ray_right")
onready var ray_f_up_right = get_node("ray_f_up_right")
onready var ray_f_down_right = get_node("ray_f_down_right")

var nn_activated_inputs := [] # set by the level
var genome: Genome
var nn: NeuralNetwork
var battle_cage_width = 950
var battle_cage_height = 590
# var battle_cage

var population
var game
var side
var velocity = Vector2()
# var nn_rotation := 0.0
# var nn_speed := 0.0
var is_dead: bool = false
var current_fitness = 0


func _ready():
  assert(genome != null, "genome is not initialized in combat agent")
  nn = NN.new(genome)


func _physics_process(delta):
  if !is_dead:
    var nn_controls := get_nn_controls(nn, get_sensor_input())
    rotation += nn_controls["nn_rotation"] * rotation_speed * delta
    var real_speed = clamp(nn_controls["nn_speed"] * speed, 0.0, speed_limit)
    velocity = Vector2(real_speed, 0).rotated(rotation)
    velocity = move_and_slide(velocity)
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
  var input_rotation = nn_output["go_right"]
  var nn_rotation = clamp(input_rotation, -rotation_speed_limit, rotation_speed_limit)

  var nn_speed = nn_output["go_forward"]
  return {"nn_rotation": nn_rotation, "nn_speed": nn_speed}


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

  var go_forward_input: float
  var go_right_input: float

  if nn_activated_inputs.has("rotation"):
    var current_rot = get_rotation()
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

      if nn_activated_inputs.has("rl_col_normal_angle"):
        var col_normal = ray_left.get_collision_normal()
        rl_col_normal_angle = col_normal.angle() / PI

      ray_left_distance = (abs(ray_left.cast_to.y) - distance) / abs(ray_left.cast_to.y)

  if nn_activated_inputs.has("ray_right_distance") || nn_activated_inputs.has("rr_col_normal_angle"):
    ray_right_distance = 0.0 # is was 1.0
    rr_col_normal_angle = 0.0
    if ray_right.is_colliding():
      var distance = global_position.distance_to(ray_right.get_collision_point())

      if nn_activated_inputs.has("rr_col_normal_angle"):
        var col_normal = ray_right.get_collision_normal()
        rr_col_normal_angle = col_normal.angle() / PI

      ray_right_distance = (ray_right.cast_to.y - distance) / ray_right.cast_to.y

  if nn_activated_inputs.has("ray_f_up_right_distance") || nn_activated_inputs.has("rfu_col_normal_angle"):
    ray_f_up_right_distance = 0.0
    rfu_col_normal_angle = 0.0
    if ray_f_up_right.is_colliding():
      var distance = global_position.distance_to(ray_f_up_right.get_collision_point())
      var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_up_right.cast_to.x,
          ray_f_up_right.cast_to.y))

      if nn_activated_inputs.has("rfu_col_normal_angle"):
        var col_normal = ray_f_up_right.get_collision_normal()
        rfu_col_normal_angle = col_normal.angle() / PI

      ray_f_up_right_distance = (ray_length - distance) / ray_length

  if nn_activated_inputs.has("ray_f_down_right_distance") || nn_activated_inputs.has("rfd_col_normal_angle"):
    ray_f_down_right_distance = 0.0
    rfd_col_normal_angle = 0.0
    if ray_f_down_right.is_colliding():
      var distance = global_position.distance_to(ray_f_down_right.get_collision_point())
      var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_down_right.cast_to.x,
          ray_f_down_right.cast_to.y))

      if nn_activated_inputs.has("rfd_col_normal_angle"):
        var col_normal = ray_f_down_right.get_collision_normal()
        rfu_col_normal_angle = col_normal.angle() / PI

      ray_f_down_right_distance = (ray_length - distance) / ray_length

  if nn_activated_inputs.has("go_forward_input"):
    # go_forward_input = clamp(nn_speed, 0, speed_limit) / speed_limit
    go_forward_input = clamp(velocity.length(), 0, speed_limit) / speed_limit

  if nn_activated_inputs.has("go_right_input"):
    # go_right_input = nn_rotation
    go_right_input = rotation / PI


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

        "go_right_input": go_right_input,
        "go_forward_input": go_forward_input,
      }

  var activated_input_dict := {}
  for input in nn_activated_inputs:
    activated_input_dict[input] = inp_dict[input]

  return activated_input_dict


func get_fitness():
  return current_fitness


func kill_agent():
  if is_dead:
    return
  is_dead = true
  yield(get_tree(), "idle_frame")
  nn.disolve_nn()
  genome.disolve_genome()

  emit_signal("agent_removed", 1)
  queue_free()

