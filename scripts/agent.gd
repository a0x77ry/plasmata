extends KinematicBody2D

# export (int) var speed = 200
# export (float) var rotation_speed = 3.0
export (int) var speed = 50
export (float) var rotation_speed = 1.0 
export (int) var number_of_hidden_nodes = 8
export (int) var level_width = 1300
export (int) var level_height = 350

const NN = preload("res://scripts/neural_network.gd")

var timer: Timer
var nn_rotation := 0.0
var nn_speed := 0.0
var velocity = Vector2()
var rotation_dir = 0
var rot
var nn: NN
var nn_inputs = [
  {"name": "rotation"},
  {"name": "inverse_rotation"},
  {"name": "time_since_birth"},
  {"name": "pos_x"},
  {"name": "pos_y"},
]
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

  if genome.empty():
    var i = 0
    for dict in nn_inputs:
      dict["id"] = i
      Main.used_node_ids.append(i)
      i += 1
    for _i_hidden in range(number_of_hidden_nodes):
      nn_h1.append({"id": i})
      i += 1
    for dict in nn_outputs:
      dict["id"] = i
      Main.used_node_ids.append(i)
      i += 1
    genome = {"input_nodes": nn_inputs, "hidden_nodes_1": nn_h1,
        "output_nodes": nn_outputs}

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
  var invrot = 1 - newrot
  var time_since_birth = (timer.wait_time - timer.time_left) / timer.wait_time
  var norm_pos_x = global_position.x / level_width
  var norm_pos_y = global_position.y / level_height
  # var newrot = current_rot / PI
  # var newrot = current_rot
  return {"rotation": newrot, "inverse_rotation": invrot,
      "time_since_birth": time_since_birth, "pos_x": norm_pos_x,
      "pos_y": norm_pos_y}


func get_nn_controls(_nn: NN, sensor_input: Dictionary):
  rotation_dir = 0
  velocity = Vector2()
  _nn.set_input(sensor_input)
  var nn_output = _nn.get_output() # a dict

  # nn_rotation = clamp(nn_output["go_right"] - nn_output["go_left"], -4.0, 4.0)
  nn_rotation = clamp(nn_output["go_right"], -8.0, 8.0)
  # nn_rotation = nn_output["go_right"] - nn_output["go_left"]
  # nn_speed = nn_output["go_forward"] - nn_output["go_backward"]
  nn_speed = nn_output["go_forward"]
  var real_speed = clamp(nn_speed * speed, 0.0, 200.0)
  # var real_speed = 200.0 if nn_speed > 0 else 0.0
  velocity = Vector2(real_speed, 0).rotated(rotation)



func _on_Timer_timeout():
  pass
  # var nn_output = nn.get_output()
  #
  # print("Thresholds: right : %s, left : %s, forward : %s, backward : %s"
  #     % [nn_output["go_right_threshold"], nn_output["go_left_threshold"],
  #     nn_output["go_forward_threshold"], nn_output["go_backward_threshold"]])

