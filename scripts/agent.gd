extends KinematicBody2D


export (float) var speed = 20.0 # waa 50.0
export (float) var rotation_speed = 0.5 # was 1.5
# export (float) var speed_limit = 300.0
export (float) var speed_limit = 100.0
# export (float) var rotation_speed_limit = 8.0
export (float) var rotation_speed_limit = 2.0
export (int) var penalty_for_hidden_nodes = 0 # was 5
export(PackedScene) var Agent = load("res://agent.tscn")

# const Genome = preload("res://scripts/genome.gd")
const NN = preload("res://scripts/neural_network.gd")
const FITNESS_IMPROVEMENT_THRESHOLD = 1.0
const FITNESS_MULTIPLIER = 1.0
const FIT_GEN_HORIZON = 2
const EXTRA_SPAWNS = 6 
const MATE_DISTRIBUTION_SPREAD = 0.5
const REDUCTION_WHEN_FULL = 10
const SPAWN_CHILDREN_TIME = 2.0

onready var ray_forward = get_node("ray_forward")
onready var ray_left = get_node("ray_left")
onready var ray_right = get_node("ray_right")
onready var ray_f_up_right = get_node("ray_f_up_right")
onready var ray_f_down_right = get_node("ray_f_down_right")
onready var level_width = get_tree().get_root().size.x
onready var level_height = get_tree().get_root().size.y
onready var path = get_parent().get_parent().get_node("Path2D")
# onready var curve = get_parent().get_parent().get_node("Path2D").curve
onready var curve = path.curve
onready var spawn_timer = get_node("SpawnTimer")
# onready var spawning_area = get_node("SpawningArea")

var random = RandomNumberGenerator.new()
var nn_rotation := 0.0
var nn_speed := 0.0
var velocity = Vector2()
var rotation_dir = 0
var nn: NN
var nn_activated_inputs := [] # set by the level
# var genome setget set_genome, get_genome
var genome
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
var is_original := true
var spawning_area
var total_level_length
var times_finished: int
var spawn_timer_to_set: float = 0.0
var current_fitness: float = 0.1
var simple_fitness: float = 0.1


func _ready():
  random.randomize()
  assert(Agent != null, "Agent need to be set in Agent Scene")
  total_level_length = curve.get_baked_length()
  spawning_area = game.get_node("SpawningArea")

  if spawn_timer_to_set != 0.0:
    spawn_timer.wait_time = spawn_timer_to_set
  finish_time_bonus = total_level_length / 17
  current_pos = position
  assert(genome != null)
  # modulate = genome.tint
  if fitness_timeline.size() == 0:
    for i in FIT_GEN_HORIZON:
      fitness_timeline.append(get_fitness())

  nn = NN.new(genome)
  # agent_loop()


func _physics_process(delta):
  if !reached_the_end && !crashed:
    # get_player_input()
    # get_nn_controls(nn, get_sensor_input())
    rotation += nn_rotation * rotation_speed * delta
    velocity = move_and_slide(velocity)
  else:
    rotation = 0.0
    velocity = 0.0


# func _exit_tree():
  # ray_left.queue_free()
  # ray_right.queue_free()
  # ray_forward.queue_free()
  # ray_f_up_right.queue_free()
  # ray_f_down_right.queue_free()
#   nn.init_ref()
#   nn.unreference()
#   genome.init_ref()
#   genome.unreference()

# func agent_loop():
#   while true:
#     yield(get_tree().create_timer(0.3), "timeout")
#     if !reached_the_end && !crashed:
#       # get_player_input()
#       get_nn_controls(nn, get_sensor_input())
#       rotation += nn_rotation * rotation_speed * 0.16
#       velocity = move_and_slide(velocity)
#     else:
#       rotation = 0.0
#       velocity = 0.0


# func set_genome(_genome):
#    genome = _genome
#
# func get_genome():
#   return genome


func get_relative_fitness(agent, agents):
  var total_fitness := 0.0
  for ag in agents:
    total_fitness += ag.get_fitness()
  var avg_fitness = total_fitness / agents.size()
  var relative_fitness = agent.get_fitness() / avg_fitness
  return relative_fitness


func reduce_population(num: int) -> void:
  var agents = game.get_active_agents()
  agents.sort_custom(AgentSorter, "sort_by_fitness_ascenting")
  for i in num:
    # agents[i].queue_free()
    agents[i].kill_agent()
  game.decrement_agent_population(num)


func find_nearest_genome():
  var agents = game.get_active_agents()
  var nearest_genome
  var nearest_agents = []

  for agent in agents:
    var dist = abs(agent.get_fitness() - get_fitness())
    nearest_agents.append([agent, dist])

  # nearest_agents.sort_custom(AgentSorter, "sort_by_dist_ascenting")
  agents.sort_custom(AgentSorter, "sort_by_fitness_ascenting")
  var rnd = clamp(random.randfn(1.0, MATE_DISTRIBUTION_SPREAD), 0.0, 2.0)
  if rnd > 1.0:
    var rnd_fraction = floor(rnd) - rnd
    rnd = clamp(1.0 - rnd_fraction, 0.0, 1.0)
  # var agent_index = round(rnd * agents.size())
  var agent_index = round(range_lerp(rnd, 0.0, 1.0, 0.0, float(agents.size() -  1)))
  # nearest_genome = agents[random.randi_range(0, agents.size() - 1)].genome
  # nearest_genome = nearest_agents[agent_index][0].genome
  nearest_genome = agents[agent_index].genome
  return nearest_genome

func get_alter_genome():
  var crossed_genomes = population.couple_crossover([genome, find_nearest_genome()], 1)
  # breakpoint
  crossed_genomes[0].mutate()
  return crossed_genomes[0]

# func get_active_agents():
#   # if !is_inside_tree():
#   #   free()
#   var agents =  get_tree().get_nodes_in_group("agents")
#   var active_agents := []
#   for agent in agents:
#     if !agent.is_queued_for_deletion():
#       active_agents.append(agent)
#   return active_agents

func spawn_new_agent(pos: Vector2, rot: float, inputs: Array, geno: Genome, is_orig: bool, t_finished: int):
  if game.get_active_agents().size() >= Main.AGENT_LIMIT:
    reduce_population(2)
  if game.get_active_agents().size() < Main.AGENT_LIMIT:
    var new_agent = Agent.instance()

    var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
    if !is_orig:
      new_agent.position = pos
      new_agent.rotation = rot
    else:
      var pos_x = rand_range(spawning_area.position.x - area_extents.x,
          spawning_area.position.x + area_extents.x)
      var pos_y = rand_range(spawning_area.position.y - area_extents.y,
          spawning_area.position.y + area_extents.y)
      new_agent.position.x = pos_x
      new_agent.position.y = pos_y
      # new_agent.rotation = rand_range(-PI, PI)
      new_agent.rotation = rot

    new_agent.nn_activated_inputs = inputs.duplicate()
    # new_agent.genome = geno
    new_agent.genome = Genome.new(population)
    new_agent.genome.duplicate(geno)
    new_agent.game = game
    new_agent.population = population
    new_agent.generation = generation + 1
    new_agent.fitness_timeline = fitness_timeline.duplicate()
    new_agent.is_original = is_orig
    new_agent.times_finished = t_finished
    var inverse_fraction = 1.0 / get_relative_fitness(self, game.get_active_agents())
    new_agent.spawn_timer_to_set = clamp(SPAWN_CHILDREN_TIME * inverse_fraction, 1.0, 8.0)

    new_agent.add_to_group("agents")
    var agents_node = game.get_node("Agents")
    # agents_node.add_child(new_agent)
    game.increment_agent_population()
    if is_orig:
      agents_node.call_deferred("add_child", new_agent)
    else:
      agents_node.add_child(new_agent)
    # population.genomes.append(new_agent.genome)

func spawn_children(is_orig: bool = false, add_finished: bool = false):
  # var new_genome = Genome.new(population)
  # new_genome.duplicate(genome)
  # assert(new_genome != null)
  if game.get_active_agents().size() >= Main.AGENT_LIMIT || is_queued_for_deletion():
    return

  if add_finished:
    spawn_new_agent(position, rotation, nn_activated_inputs, genome, is_orig, times_finished + 1)
  else:
    spawn_new_agent(position, rotation, nn_activated_inputs, genome, is_orig, times_finished)

  var extra_spawns: int = EXTRA_SPAWNS
  extra_spawns *= get_relative_fitness(self, game.get_active_agents()) 
  for i in extra_spawns:
    if add_finished:
      spawn_new_agent(position, rotation, nn_activated_inputs, get_alter_genome(), is_orig, times_finished + 1)
    else:
      spawn_new_agent(position, rotation, nn_activated_inputs, get_alter_genome(), is_orig, times_finished)


func get_fitness() -> float:
  # return curve.get_closest_offset(position) + (times_finished * total_level_length)
  return current_fitness


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
    # fitness = curve.get_closest_offset(position) / total_level_length
    fitness = simple_fitness / total_level_length

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
  if is_original:
    reached_the_end = true
  else:
    spawn_children(true, true)
  time_left_when_finished = time_left


func _on_SpawnTimer_timeout():
  # if !is_inside_tree():
  #   return
  var total_fitness := 0.0
  for i in range(1, FIT_GEN_HORIZON + 1):
    total_fitness += fitness_timeline[-i]
  var avg_fitness = total_fitness / FIT_GEN_HORIZON
  assign_fitness()
  fitness_timeline.append(get_fitness())
  if avg_fitness + FITNESS_IMPROVEMENT_THRESHOLD < get_fitness():
    spawn_children()


func _on_DeathTimer_timeout():
  kill_agent()

func kill_agent():
  # nn.unreference()
  # genome.unreference()
  # nn = null
  # genome = null
  nn.disolve_nn()
  game.decrement_agent_population()
  remove_from_group("agents")
  game.get_node("Agents").remove_child(self)
  queue_free()


func _on_FitnessUpdateTimer_timeout():
  var curve_local_pos = path.to_local(global_position)
  var current_offset = curve.get_closest_offset(curve_local_pos)

  var int_baked = curve.interpolate_baked(current_offset)
  var dist_to_curve = int_baked.distance_to(curve_local_pos)

  simple_fitness = current_offset - dist_to_curve
  current_fitness = simple_fitness + (times_finished * total_level_length)

  if current_fitness == 0:
    # current_fitness = 0.1
    breakpoint


func _on_NNControlsUpdateTimer_timeout():
  get_nn_controls(nn, get_sensor_input())


class AgentSorter:
  static func sort_by_dist_ascenting(a, b):
    if a[1] < b[1]:
      return true
    return false

  static func sort_by_fitness_ascenting(a, b):
    if a.get_fitness() < b.get_fitness():
      return true
    return false

