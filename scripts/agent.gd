extends KinematicBody2D

# export (int) var speed = 200
# export (float) var rotation_speed = 3.0
export (float) var speed = 70.0
export (float) var rotation_speed = 1.5
export (float) var speed_limit = 400.0
export (float) var rotation_speed_limit = 8.0
export (int) var number_of_hidden_nodes = 8
# export (int) var level_width = 1300
# export (int) var level_height = 350

const NN = preload("res://scripts/neural_network.gd")

onready var ray_forward = get_node("ray_forward")
onready var ray_f_up = get_node("ray_f_up")
onready var ray_f_down = get_node("ray_f_down")
onready var timer = get_parent().get_node("Timer")
onready var level_width = get_tree().get_root().size.x
onready var level_height = get_tree().get_root().size.y

var nn_rotation := 0.0
var nn_speed := 0.0
var velocity = Vector2()
var rotation_dir = 0
var rot
var nn: NN
var nn_activated_inputs = [
  "rotation",
  # "inverse_rotation",
  "time_since_birth",
  "pos_x",
  "pos_y",
  "ray_f_distance",
  "ray_f_up_distance",
  "ray_f_down_distance",
]
var nn_inputs = []
var nn_outputs = [
  {"name": "go_right"},
  # {"name": "go_left"},
  {"name": "go_forward"},
  # {"name": "go_backward"},
]
var nn_h1 = []
var genome: Dictionary = {} setget set_genome, get_genome

func _ready():
  randomize()
  rot = 0
  # var number_of_hidden_nodes = ceil((float(nn_inputs.size()) * 2.0) / 3.0) + nn_outputs.size()
  # var number_of_hidden_nodes = 8
  for input in nn_activated_inputs:
    nn_inputs.append({"name": input})

  if genome.empty():
    var i = 0
    for dict in nn_inputs:
      dict["id"] = i
      Main.used_node_ids.append(i)
      i += 1
    for _i_hidden in range(number_of_hidden_nodes):
      Main.used_node_ids.append(i)
      nn_h1.append({"id": i})
      i += 1
    for dict in nn_outputs:
      dict["id"] = i
      Main.used_node_ids.append(i)
      i += 1
    genome = {"input_nodes": nn_inputs, "hidden_nodes_1": nn_h1,
        "output_nodes": nn_outputs, "fitness": 0}

  nn = NN.new(genome)


func _physics_process(delta):
  # get_player_input()
  get_nn_controls(nn, get_sensor_input())
  # rotation += rotation_dir * rotation_speed * delta
  rotation += nn_rotation * rotation_speed * delta
  velocity = move_and_slide(velocity)


func set_genome(_genome):
   genome = _genome

func get_genome():
  return genome


func get_sensor_input():
  var current_rot = get_rotation()
  # Normalized rotation in positive radians
  var newrot = (current_rot if current_rot > 0 else current_rot + TAU) / TAU
  # var newrot = current_rot / PI
  # var newrot = current_rot
  var invrot = 1 - newrot
  var time_since_birth = (timer.wait_time - timer.time_left) / timer.wait_time
  var norm_pos_x = global_position.x / level_width
  var norm_pos_y = global_position.y / level_height

  var ray_f_distance = 0.0 # is was 1.0
  if ray_forward.is_colliding():
    var distance = global_position.distance_to(ray_forward.get_collision_point())
    # ray_f_distance = distance / ray_forward.cast_to.x
    ray_f_distance = (ray_forward.cast_to.x - distance) / ray_forward.cast_to.x

  var ray_f_up_distance = 0.0
  if ray_f_up.is_colliding():
    var distance = global_position.distance_to(ray_f_up.get_collision_point())
    var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_up.cast_to.x, ray_f_up.cast_to.y))
    # ray_f_up_distance = distance / ray_length
    ray_f_up_distance = (ray_length - distance) / ray_length

  var ray_f_down_distance = 0.0
  if ray_f_down.is_colliding():
    var distance = global_position.distance_to(ray_f_down.get_collision_point())
    var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_down.cast_to.x, ray_f_up.cast_to.y))
    # ray_f_down_distance = distance / ray_length
    ray_f_down_distance = (ray_length - distance) / ray_length

  var inp_dict = {"rotation": newrot,
      "inverse_rotation": invrot,
      "time_since_birth": time_since_birth, "pos_x": norm_pos_x,
      "pos_y": norm_pos_y, "ray_f_distance": ray_f_distance,
      "ray_f_up_distance": ray_f_up_distance, "ray_f_down_distance": ray_f_down_distance}

  var activated_input_dict := {}
  for input in nn_activated_inputs:
    activated_input_dict[input] = inp_dict[input]

  return activated_input_dict


func get_nn_controls(_nn: NN, sensor_input: Dictionary):
  rotation_dir = 0
  velocity = Vector2()
  _nn.set_input(sensor_input)
  var nn_output = _nn.get_output() # a dict

  # nn_rotation = clamp(nn_output["go_right"] - nn_output["go_left"], -4.0, 4.0)
  nn_rotation = clamp(nn_output["go_right"], -rotation_speed_limit, rotation_speed_limit)
  # nn_rotation = 4.0 if nn_output["go_right"] > 0 else -4.0
  # nn_speed = nn_output["go_forward"] - nn_output["go_backward"]
  nn_speed = nn_output["go_forward"]
  var real_speed = clamp(nn_speed * speed, 0.0, speed_limit)
  # var real_speed = 200.0 if nn_speed > 0 else 0.0
  velocity = Vector2(real_speed, 0).rotated(rotation)



func _on_Timer_timeout():
  pass
  # var nn_output = nn.get_output()
  #
  # print("Thresholds: right : %s, left : %s, forward : %s, backward : %s"
  #     % [nn_output["go_right_threshold"], nn_output["go_left_threshold"],
  #     nn_output["go_forward_threshold"], nn_output["go_backward_threshold"]])

