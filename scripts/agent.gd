extends KinematicBody2D


export (float) var speed = 20.0 # waa 50.0
export (float) var rotation_speed = 0.5 # was 1.5
export (float) var speed_limit = 300.0
export (float) var rotation_speed_limit = 8.0
export (int) var penalty_for_hidden_nodes = 0 # was 5
export(PackedScene) var Agent = load("res://agent.tscn")

# const Genome = preload("res://scripts/genome.gd")
const NN = preload("res://scripts/neural_network.gd")
const FITNESS_IMPROVEMENT_THRESHOLD = 0.0
const FITNESS_MULTIPLIER = 1.0
const FIT_GEN_HORIZON = 8
const EXTRA_SPAWNS = 8
const MATE_DISTRIBUTION_SPREAD = 0.2

onready var ray_forward = get_node("ray_forward")
onready var ray_left = get_node("ray_left")
onready var ray_right = get_node("ray_right")
onready var ray_f_up_right = get_node("ray_f_up_right")
onready var ray_f_down_right = get_node("ray_f_down_right")
onready var level_width = get_tree().get_root().size.x
onready var level_height = get_tree().get_root().size.y
onready var curve = get_parent().get_parent().get_node("Path2D").curve
onready var spawn_timer = get_node("SpawnTimer")

var random = RandomNumberGenerator.new()
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
var current_pos: Vector2
var population
var game
var generation := 0
var fitness_timeline := []


func _ready():
  random.randomize()
  assert(Agent != null, "Agent need to be set in Agent Scene")
  var total_level_length = curve.get_baked_length()
  finish_time_bonus = total_level_length / 17
  current_pos = position
  assert(genome != null)
  # modulate = genome.tint
  # var cur_fit = get_fitness()
  # for i in (FIT_GEN_HORIZON - 2):
  #   fitness_timeline.append(cur_fit - 0.01)
  # for i in 2:
  #   fitness_timeline.append(get_fitness())
  for i in FIT_GEN_HORIZON:
    fitness_timeline.append(get_fitness())

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


func find_nearest_genome():
  var agents = get_tree().get_nodes_in_group("agents")
  var nearest_genome
  # var min_fit_dist := INF
  # for agent in agents:
  #   if agent.genome.genome_id != genome.genome_id:
  #     # var dist = abs(agent.genome.fitness - genome.fitness)
  #     var dist = abs(agent.get_fitness() - get_fitness())
  #     if dist < min_fit_dist:
  #       min_fit_dist = dist
  #       nearest_genome = agent.genome
  agents.sort_custom(AgentSorter, "sort_ascenting")
  var rnd = clamp(random.randfn(1.0, MATE_DISTRIBUTION_SPREAD), 0.0, 2.0)
  if rnd > 1.0:
    var rnd_fraction = floor(rnd) - rnd
    rnd = clamp(1.0 - rnd_fraction, 0.0, 1.0)
  var agent_index = round(rnd * agents.size())
  # agent_index = round(range_lerp(rnd, 0.0, 1.0, 0.0, float(agents.size())))
  # print(agent_index)
  # nearest_genome = agents[random.randi_range(0, agents.size() - 1)].genome
  nearest_genome = agents[agent_index - 1].genome
  return nearest_genome

func get_alter_genome():
  var crossed_genomes = population.couple_crossover([genome, find_nearest_genome()], 1)
  # breakpoint
  crossed_genomes[0].mutate()
  return crossed_genomes[0]

func spawn_new_agent(pos: Vector2, rot: float, inputs: Array, geno: Genome):
  var new_agent = Agent.instance()
  new_agent.position = pos
  new_agent.rotation = rot
  new_agent.nn_activated_inputs = inputs
  new_agent.genome = geno
  new_agent.game = game
  new_agent.population = population
  new_agent.generation = generation + 1
  new_agent.fitness_timeline = fitness_timeline

  new_agent.add_to_group("agents")
  var agents_node = game.get_node("Agents")
  agents_node.add_child(new_agent)
  population.genomes.append(new_agent.genome)

func spawn_children():
  var new_genome = Genome.new(population)
  new_genome.duplicate(genome)
  assert(new_genome != null)
  spawn_new_agent(position, rotation, nn_activated_inputs, new_genome)
  for i in EXTRA_SPAWNS:
    spawn_new_agent(position, rotation, nn_activated_inputs, get_alter_genome())


func get_fitness():
  return curve.get_closest_offset(position) \
      + time_left_when_finished * finish_time_bonus


func assign_fitness():
  genome.fitness = get_fitness()
  genome.fitness *= FITNESS_MULTIPLIER
  var hidden_nodes_size = genome.hidden_nodes.size()
  genome.fitness -= hidden_nodes_size * penalty_for_hidden_nodes
  # genome.fitness = pow(genome.fitness, 2.0) / 3.0


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
  var mwall_1_pos: float
  var mwall_2_pos: float

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
    go_forward_input = clamp(nn_speed, 0, speed_limit) / speed_limit
  if nn_activated_inputs.has("go_right_input"):
    go_right_input = nn_rotation

  if nn_activated_inputs.has("mwall_1_pos"):
    var mwall_1 = get_parent().get_parent().get_node("Walls/MovingWall")
    var w_starting_y = 216
    var w_ending_y = 316
    var w_distance = abs(w_starting_y - w_ending_y)
    mwall_1_pos = abs(w_starting_y - mwall_1.position.y) / w_distance

  if nn_activated_inputs.has("mwall_2_pos"):
    var mwall_2 = get_parent().get_parent().get_node("Walls/MovingWall2")
    var w_starting_y = 320
    var w_ending_y = 216
    var w_distance = abs(w_starting_y - w_ending_y)
    mwall_2_pos = abs(w_starting_y - mwall_2.position.y) / w_distance

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
        "go_forward_input": go_forward_input,
        "mwall_1_pos": mwall_1_pos,
        "mwall_2_pos": mwall_2_pos 
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


func _on_SpawnTimer_timeout():
  # var old_fitness = fitness_timeline[-1]
  var total_fitness := 0.0
  for i in range(1, FIT_GEN_HORIZON + 1):
    total_fitness += fitness_timeline[-i]
  var avg_fitness = total_fitness / FIT_GEN_HORIZON
  assign_fitness()
  # print("Old fitness: %s, New fitness: %s" % [old_fitness, get_fitness()])
  # if old_fitness + (FITNESS_IMPROVEMENT_THRESHOLD * pow(generation, 0.8)) < get_fitness():
  # if old_fitness + FITNESS_IMPROVEMENT_THRESHOLD < get_fitness():
  if avg_fitness + FITNESS_IMPROVEMENT_THRESHOLD < get_fitness():
    spawn_children()
  else:
    queue_free()


func _on_DeathTimer_timeout():
  queue_free()


class AgentSorter:
  static func sort_ascenting(a, b):
    if a.get_fitness() < b.get_fitness():
      return true
    return false
