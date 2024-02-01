extends KinematicBody2D

# export (int) var speed = 200
# export (float) var rotation_speed = 3.0
export (float) var speed = 20.0 # waa 50.0
export (float) var rotation_speed = 0.5 # was 1.5
export (float) var speed_limit = 300.0
export (float) var rotation_speed_limit = 8.0
export (int) var number_of_hidden_nodes = 8
# export (int) var level_width = 1300
# export (int) var level_height = 350

const NN = preload("res://scripts/neural_network.gd")
# const TIME_TO_FITNESS_MULTIPLICATOR = 120

onready var ray_forward = get_node("ray_forward")
onready var ray_left = get_node("ray_left")
onready var ray_right = get_node("ray_right")
onready var ray_f_up_right = get_node("ray_f_up_right")
onready var ray_f_down_right = get_node("ray_f_down_right")
# onready var timer = get_parent().get_node("Timer")
# onready var timer = get_tree().get_root().get_node("Level1/Timer")
onready var level_width = get_tree().get_root().size.x
onready var level_height = get_tree().get_root().size.y
onready var curve = get_parent().get_parent().get_node("Path2D").curve

var nn_rotation := 0.0
var nn_speed := 0.0
var velocity = Vector2()
var rotation_dir = 0
var nn: NN
var nn_activated_inputs := [] # set by the level
var genome setget set_genome, get_genome
var reached_the_end := false
var time_left_when_finished := 0.0
var timer: Timer
var penalty := 0.0
var crashed := false
var finish_time_bonus: float
# var distance_penalty_multiplier: float
var current_pos: Vector2
# var distance_covered := 0.0


func _ready():
  randomize()
  var total_level_length = curve.get_baked_length()
  finish_time_bonus = total_level_length / 17
  # distance_penalty_multiplier = 0.05
  current_pos = position
  assert(genome != null)
  # var starting_link_id = nn_inputs.size() + nn_outputs.size()
  # modulate = genome.tint
  nn = NN.new(genome)


func _physics_process(delta):
  if !reached_the_end && !crashed:
    # get_player_input()
    get_nn_controls(nn, get_sensor_input())
    rotation += nn_rotation * rotation_speed * delta
    velocity = move_and_slide(velocity)
  else:
    rotation = 0.0
    velocity = 0.0


func set_genome(_genome):
   genome = _genome

func get_genome():
  return genome


func get_fitness():
  genome.fitness = curve.get_closest_offset(position) \
      + time_left_when_finished * finish_time_bonus
  # genome.fitness -= distance_penalty_multiplier * distance_covered
  # genome.fitness = max(0, genome.fitness)


func get_sensor_input():
  var newrot: float
  var invrot: float
  var time_since_birth: float
  var norm_pos_x: float
  var norm_pos_y: float
  var ray_f_distance: float
  var ray_left_distance: float
  var ray_right_distance: float
  var ray_f_up_right_distance: float
  var ray_f_down_right_distance: float
  var fitness: float
  var go_forward_input: float
  var go_right_input: float

  if nn_activated_inputs.has("rotation"):
    var current_rot = get_rotation()
    # Normalized rotation in positive radians
    newrot = (current_rot if current_rot > 0 else current_rot + TAU) / TAU
    # var newrot = current_rot / PI
    # var newrot = current_rot

  if nn_activated_inputs.has("inverse_rotation"):
    invrot = 1 - newrot
  if nn_activated_inputs.has("time_since_birth"):
    time_since_birth = (timer.wait_time - timer.time_left) / timer.wait_time
  if nn_activated_inputs.has("pos_x"):
    norm_pos_x = global_position.x / level_width
  if nn_activated_inputs.has("pos_y"):
    norm_pos_y = global_position.y / level_height

  if nn_activated_inputs.has("ray_f_distance"):
    ray_f_distance = 0.0 # is was 1.0
    if ray_forward.is_colliding():
      var distance = global_position.distance_to(ray_forward.get_collision_point())
      # ray_f_distance = distance / ray_forward.cast_to.x
      ray_f_distance = (ray_forward.cast_to.x - distance) / ray_forward.cast_to.x

  if nn_activated_inputs.has("ray_left_distance"):
    ray_left_distance = 0.0 # is was 1.0
    if ray_left.is_colliding():
      var distance = global_position.distance_to(ray_left.get_collision_point())
      ray_left_distance = (abs(ray_left.cast_to.y) - distance) / abs(ray_left.cast_to.y)

  if nn_activated_inputs.has("ray_right_distance"):
    ray_right_distance = 0.0 # is was 1.0
    if ray_right.is_colliding():
      var distance = global_position.distance_to(ray_right.get_collision_point())
      ray_right_distance = (ray_right.cast_to.y - distance) / ray_right.cast_to.y

  if nn_activated_inputs.has("ray_f_up_right_distance"):
    ray_f_up_right_distance = 0.0
    if ray_f_up_right.is_colliding():
      var distance = global_position.distance_to(ray_f_up_right.get_collision_point())
      var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_up_right.cast_to.x,
          ray_f_up_right.cast_to.y))
      # ray_f_up_distance = distance / ray_length
      ray_f_up_right_distance = (ray_length - distance) / ray_length

  if nn_activated_inputs.has("ray_f_down_right_distance"):
    ray_f_down_right_distance = 0.0
    if ray_f_down_right.is_colliding():
      var distance = global_position.distance_to(ray_f_down_right.get_collision_point())
      var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_down_right.cast_to.x,
          ray_f_down_right.cast_to.y))
      # ray_f_down_distance = distance / ray_length
      ray_f_down_right_distance = (ray_length - distance) / ray_length

  if nn_activated_inputs.has("fitness"):
    fitness = curve.get_closest_offset(position) / curve.get_baked_length()

  if nn_activated_inputs.has("go_forward_input"):
    go_forward_input = nn_speed
  if nn_activated_inputs.has("go_right_input"):
    go_right_input = nn_rotation

  var inp_dict = {"rotation": newrot,
        "inverse_rotation": invrot,
        "time_since_birth": time_since_birth,
        "pos_x": norm_pos_x,
        "pos_y": norm_pos_y,
        "ray_f_distance": ray_f_distance,
        "ray_f_up_right_distance": ray_f_up_right_distance,
        "ray_f_down_right_distance": ray_f_down_right_distance,
        "ray_left_distance": ray_left_distance,
        "ray_right_distance": ray_right_distance,
        "fitness": fitness,
        "go_right_input": go_right_input,
        "go_forward_input": go_forward_input
      }

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
  # Apply a threshold in rotations
  var input_rotation = nn_output["go_right"]
  # nn_rotation = clamp(nn_output["go_right"], -rotation_speed_limit, rotation_speed_limit)
  nn_rotation = clamp(input_rotation, -rotation_speed_limit, rotation_speed_limit)


  # nn_rotation = 4.0 if nn_output["go_right"] > 0 else -4.0
  # nn_speed = nn_output["go_forward"] - nn_output["go_backward"]
  nn_speed = nn_output["go_forward"]
  var real_speed = clamp(nn_speed * speed, 0.0, speed_limit)
  # var real_speed = 200.0 if nn_speed > 0 else 0.0
  velocity = Vector2(real_speed, 0).rotated(rotation)


func finish(time_left: float):
  reached_the_end = true
  time_left_when_finished = time_left


# func _on_DistanceTimer_timeout():
#   var curr_dist = position.distance_to(current_pos)
#   current_pos = position
#   distance_covered += curr_dist

