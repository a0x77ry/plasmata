extends KinematicBody2D


export (float) var speed = 20.0 # waa 50.0
export (float) var rotation_speed = 1.0 # was 0.5
export (float) var speed_limit = 110.0
# export (float) var speed_limit = 100.0
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
const SPAWNING_TIME_UPPER_LIMIT = 14.0

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
onready var death_timer = get_node("DeathTimer")
# onready var spawning_area = get_node("SpawningArea")
# onready var solved_text = get_node("UI/Soved/SolvedText")


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
# var is_original := true
var spawning_area
var total_level_length
# lineage_times_finished refers to the lineage and not a single agent
var lineage_times_finished: int
# This refers to how many times a single agent has completed the level
var agent_completion_counter: int = 0
var spawn_timer_to_set: float = 0.0
var current_fitness: float = 0.1
var simple_fitness: float = 0.1
var is_dead := false
var area_extents
var spawning_area_position
var mw1_starting_y: float
var mw2_starting_y: float
var mw_distance: float = 104.0
var mwall_1
var mwall_2
var start_time: int


func _ready():
  start_time = OS.get_ticks_msec()
  random.randomize()
  assert(Agent != null, "Agent need to be set in Agent Scene")
  total_level_length = curve.get_baked_length()
  spawning_area = game.get_node("SpawningArea")
  spawning_area_position = spawning_area.position
  area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  if nn_activated_inputs.has("mwall_1_pos"):
    mwall_1 = get_parent().get_parent().get_node("Walls/MovingWall")
    mw1_starting_y = mwall_1.position.y
  if nn_activated_inputs.has("mwall_2_pos"):
    mwall_2 = get_parent().get_parent().get_node("Walls/MovingWall2")
    mw2_starting_y = mwall_2.position.y

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


func _physics_process(delta):
  if !reached_the_end && !crashed && !is_dead:
    update_current_fitness()
    # get_player_input()
    get_nn_controls(nn, get_sensor_input())
    rotation += nn_rotation * rotation_speed * delta
    velocity = move_and_slide(velocity)
  else:
    if nn != null && nn.is_dissolved:
      nn = null
      # genome = null
    rotation = 0.0
    velocity = 0.0


func get_relative_fitness(agent, agents):
  var total_rel_fitness := 0.0
  var min_fitness = INF
  # var max_fitness = -INF
  for ag in agents:
    var ag_fit = ag.get_fitness()

    if ag_fit < min_fitness:
      min_fitness = ag_fit
    # if ag_fit > max_fitness:
    #   max_fitness = ag_fit

  for ag in agents:
    var rel_ag_fit = ag.get_fitness() - min_fitness
    total_rel_fitness += rel_ag_fit

  var avg_fitness = total_rel_fitness / agents.size()
  var relative_fitness = (agent.get_fitness() - min_fitness + 0.01) / avg_fitness
  return relative_fitness


func reduce_population(num: int) -> void:
  # var agents = game.get_active_agents()
  # agents.sort_custom(AgentSorter, "sort_by_fitness_ascenting")
  var agents_dead := 0
  for i in num:
    var agent = game.sorted_agents[i]
    if !is_instance_valid(agent):
      agents_dead += 1
  for i in num + agents_dead:
    var agent = game.sorted_agents[i]
    if !is_instance_valid(agent):
      continue
    agent.kill_agent()
  game.decrement_agent_population(num)


func find_nearest_genome():
  # var agents = game.get_active_agents()
  var nearest_genome
  var nearest_agents = []

  for agent in game.sorted_agents:
    if is_instance_valid(agent):
      var dist = abs(agent.get_fitness() - get_fitness())
      nearest_agents.append([agent, dist])

  # agents.sort_custom(AgentSorter, "sort_by_fitness_ascenting")
  var rnd = clamp(random.randfn(1.0, MATE_DISTRIBUTION_SPREAD), 0.0, 2.0)
  if rnd > 1.0:
    var rnd_fraction = floor(rnd) - rnd
    rnd = clamp(1.0 - rnd_fraction, 0.0, 1.0)
  # var agent_index = round(rnd * agents.size())
  var agent_index = round(range_lerp(rnd, 0.0, 1.0, 0.0, float(game.sorted_agents.size() -  1)))
  while !is_instance_valid(game.sorted_agents[agent_index]):
    rnd = clamp(random.randfn(1.0, MATE_DISTRIBUTION_SPREAD), 0.0, 2.0)
    if rnd > 1.0:
      var rnd_fraction = floor(rnd) - rnd
      rnd = clamp(1.0 - rnd_fraction, 0.0, 1.0)
    agent_index = round(range_lerp(rnd, 0.0, 1.0, 0.0, float(game.sorted_agents.size() -  1)))
  # nearest_genome = agents[random.randi_range(0, agents.size() - 1)].genome
  # nearest_genome = nearest_agents[agent_index][0].genome
  nearest_genome = Genome.new(population)
  nearest_genome.copy(game.sorted_agents[agent_index].genome)
  # nearest_genome = game.sorted_agents[agent_index].genome
  return nearest_genome

func get_alter_genome():
  var new_genome = Genome.new(population)
  new_genome.copy(genome)
  var crossed_genomes = population.couple_crossover([new_genome, find_nearest_genome()], 1)
  crossed_genomes[0].mutate()
  return crossed_genomes[0]


# func spawn_new_agent(pos: Vector2, rot: float, inputs: Array, geno: Genome, t_finished: int):
func spawn_new_agent(pos: Vector2, inputs: Array, geno: Genome, t_finished: int):
  if game.get_active_agents().size() >= Main.AGENT_LIMIT:
    reduce_population(1)

  var new_agent = Agent.instance()
  new_agent.position = pos
  # new_agent.rotation = rot
  new_agent.rotation = 0.0

  new_agent.nn_activated_inputs = inputs.duplicate()
  new_agent.genome = geno
  new_agent.game = game
  new_agent.population = population
  new_agent.generation = generation + 1
  new_agent.fitness_timeline = fitness_timeline.duplicate()
  new_agent.lineage_times_finished = t_finished
  var inverse_fraction = 1.0 / get_relative_fitness(self, game.get_active_agents())
  inverse_fraction = pow(inverse_fraction, 2.0)
  new_agent.spawn_timer_to_set = clamp(SPAWN_CHILDREN_TIME * inverse_fraction, 1.0, SPAWNING_TIME_UPPER_LIMIT)

  new_agent.add_to_group("agents")
  var agents_node = game.get_node("Agents")

  agents_node.add_child(new_agent)

  game.increment_agent_population()


func spawn_children():
  var new_genome = Genome.new(population)
  new_genome.copy(genome)
  if game.get_active_agents().size() >= Main.AGENT_LIMIT:
    reduce_population(2)
  # if game.get_active_agents().size() >= Main.AGENT_LIMIT + 2 || ((is_queued_for_deletion() || is_dead) && add_finished == false):
  if game.get_active_agents().size() >= Main.AGENT_LIMIT + 2 || is_queued_for_deletion() || is_dead:
    return

  spawn_new_agent(position,  nn_activated_inputs, new_genome, lineage_times_finished)

  var extra_spawns: int = EXTRA_SPAWNS
  extra_spawns *= get_relative_fitness(self, game.get_active_agents()) 
  for i in extra_spawns:
    spawn_new_agent(position, nn_activated_inputs, get_alter_genome(), lineage_times_finished)


func get_fitness() -> float:
  # return curve.get_closest_offset(position) + (lineage_times_finished * total_level_length)
  return current_fitness


func update_current_fitness():
  var curve_local_pos = path.to_local(global_position)
  var current_offset = curve.get_closest_offset(curve_local_pos)

  var int_baked = curve.interpolate_baked(current_offset)
  var dist_to_curve = int_baked.distance_to(curve_local_pos)

  simple_fitness = current_offset - dist_to_curve
  current_fitness = simple_fitness \
      + (lineage_times_finished * total_level_length) \
      + (agent_completion_counter * (total_level_length * 0.3))

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

  var ray_f_distance_mw: float
  var ray_left_distance_mw: float
  var ray_right_distance_mw: float
  var ray_f_up_right_distance_mw: float
  var ray_f_down_right_distance_mw: float

  var rf_col_normal_angle: float
  var rl_col_normal_angle: float
  var rr_col_normal_angle: float
  var rfu_col_normal_angle: float
  var rfd_col_normal_angle: float

  var finish_distance: float
  var finish_angle: float

  var fitness: float
  var go_forward_input: float
  var go_right_input: float
  var mwall_1_pos: float
  var mwall_2_pos: float

  if nn_activated_inputs.has("rotation"):
    var current_rot = get_rotation()
    # Normalized rotation in positive radians
    # newrot = (current_rot if current_rot > 0 else current_rot + TAU) / TAU
    newrot = current_rot / PI

  if nn_activated_inputs.has("inverse_rotation"):
    invrot = 1 - newrot

  if nn_activated_inputs.has("time_since_birth"):
    time_since_birth = (timer.wait_time - timer.time_left) / timer.wait_time
  if nn_activated_inputs.has("pos_x"):
    norm_pos_x = global_position.x / level_width
  if nn_activated_inputs.has("pos_y"):
    norm_pos_y = global_position.y / level_height

  if nn_activated_inputs.has("finish_distance") || nn_activated_inputs.has("finish_angle"):
    var fa_pos = game.fa_col_result["collider"].global_position
    finish_distance = 0.0
    finish_distance = global_position.distance_to(fa_pos) / game.start_finish_distance
    finish_angle = 0.0
    finish_angle = global_position.angle_to(fa_pos) / PI

  if nn_activated_inputs.has("ray_f_distance") || nn_activated_inputs.has("rf_col_normal_angle"):
    ray_f_distance = 0.0
    ray_f_distance_mw = 0.0
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
      elif col.is_in_group("moving_walls"):
        ray_f_distance_mw = (ray_forward.cast_to.x - distance) / ray_forward.cast_to.x

  if nn_activated_inputs.has("ray_left_distance") || nn_activated_inputs.has("rl_col_normal_angle"):
    ray_left_distance = 0.0 # is was 1.0
    ray_left_distance_mw = 0.0 # is was 1.0
    rl_col_normal_angle = 0.0
    if ray_left.is_colliding():
      var distance = global_position.distance_to(ray_left.get_collision_point())
      var col = ray_left.get_collider()

      if nn_activated_inputs.has("rl_col_normal_angle"):
        var col_normal = ray_left.get_collision_normal()
        rl_col_normal_angle = col_normal.angle() / PI

      # if col.is_in_group("normal_walls"):
      #   ray_left_distance = (abs(ray_left.cast_to.y) - distance) / abs(ray_left.cast_to.y)
      # elif col.is_in_group("moving_walls"):
      #   ray_left_distance_mw = (abs(ray_left.cast_to.y) - distance) / abs(ray_left.cast_to.y)
      ray_left_distance = (abs(ray_left.cast_to.y) - distance) / abs(ray_left.cast_to.y)
      if col.is_in_group("moving_walls"):
        ray_left_distance_mw = (abs(ray_left.cast_to.y) - distance) / abs(ray_left.cast_to.y)

  if nn_activated_inputs.has("ray_right_distance") || nn_activated_inputs.has("rr_col_normal_angle"):
    ray_right_distance = 0.0 # is was 1.0
    ray_right_distance_mw = 0.0 # is was 1.0
    rr_col_normal_angle = 0.0
    if ray_right.is_colliding():
      var distance = global_position.distance_to(ray_right.get_collision_point())
      var col = ray_right.get_collider()

      if nn_activated_inputs.has("rr_col_normal_angle"):
        var col_normal = ray_right.get_collision_normal()
        rr_col_normal_angle = col_normal.angle() / PI

      # if col.is_in_group("normal_walls"):
      #   ray_right_distance = (ray_right.cast_to.y - distance) / ray_right.cast_to.y
      # elif col.is_in_group("moving_walls"):
      #   ray_right_distance_mw = (ray_right.cast_to.y - distance) / ray_right.cast_to.y
      ray_right_distance = (ray_right.cast_to.y - distance) / ray_right.cast_to.y
      if col.is_in_group("moving_walls"):
        ray_right_distance_mw = (ray_right.cast_to.y - distance) / ray_right.cast_to.y

  if nn_activated_inputs.has("ray_f_up_right_distance") || nn_activated_inputs.has("rfu_col_normal_angle"):
    ray_f_up_right_distance = 0.0
    ray_f_up_right_distance_mw = 0.0
    rfu_col_normal_angle = 0.0
    if ray_f_up_right.is_colliding():
      var distance = global_position.distance_to(ray_f_up_right.get_collision_point())
      var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_up_right.cast_to.x,
          ray_f_up_right.cast_to.y))
      var col = ray_f_up_right.get_collider()

      if nn_activated_inputs.has("rfu_col_normal_angle"):
        var col_normal = ray_f_up_right.get_collision_normal()
        rfu_col_normal_angle = col_normal.angle() / PI

      # if col.is_in_group("normal_walls"):
      #   ray_f_up_right_distance = (ray_length - distance) / ray_length
      # elif col.is_in_group("moving_walls"):
      #   ray_f_up_right_distance_mw = (ray_length - distance) / ray_length
      ray_f_up_right_distance = (ray_length - distance) / ray_length
      if col.is_in_group("moving_walls"):
        ray_f_up_right_distance_mw = (ray_length - distance) / ray_length

  if nn_activated_inputs.has("ray_f_down_right_distance") || nn_activated_inputs.has("rfd_col_normal_angle"):
    ray_f_down_right_distance = 0.0
    ray_f_down_right_distance_mw = 0.0
    rfd_col_normal_angle = 0.0
    if ray_f_down_right.is_colliding():
      var distance = global_position.distance_to(ray_f_down_right.get_collision_point())
      var ray_length = Vector2.ZERO.distance_to(Vector2(ray_f_down_right.cast_to.x,
          ray_f_down_right.cast_to.y))
      var col = ray_f_down_right.get_collider()

      if nn_activated_inputs.has("rfd_col_normal_angle"):
        var col_normal = ray_f_down_right.get_collision_normal()
        rfu_col_normal_angle = col_normal.angle() / PI

      # if col.is_in_group("normal_walls"):
      #   ray_f_down_right_distance = (ray_length - distance) / ray_length
      # elif col.is_in_group("moving_walls"):
      #   ray_f_down_right_distance_mw = (ray_length - distance) / ray_length
      ray_f_down_right_distance = (ray_length - distance) / ray_length
      if col.is_in_group("moving_walls"):
        ray_f_down_right_distance_mw = (ray_length - distance) / ray_length

  if nn_activated_inputs.has("fitness"):
    # fitness = curve.get_closest_offset(position) / total_level_length
    fitness = simple_fitness / total_level_length

  if nn_activated_inputs.has("go_forward_input"):
    go_forward_input = clamp(nn_speed, 0, speed_limit) / speed_limit
  if nn_activated_inputs.has("go_right_input"):
    go_right_input = nn_rotation

  if nn_activated_inputs.has("mwall_1_pos"):
    # var mwall_1 = get_parent().get_parent().get_node("Walls/MovingWall")
    # var w_starting_y = 216
    # var w_ending_y = 316
    # var w_distance = abs(w_starting_y - w_ending_y)
    mwall_1_pos = 1.0 - (abs(mw1_starting_y - mwall_1.position.y) / mw_distance)

  if nn_activated_inputs.has("mwall_2_pos"):
    # var mwall_2 = get_parent().get_parent().get_node("Walls/MovingWall2")
    # var w_starting_y = 320
    # var w_ending_y = 216
    # var w_distance = abs(w_starting_y - w_ending_y)
    mwall_2_pos = abs(mw1_starting_y - mwall_2.position.y) / mw_distance

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

        "ray_f_distance_mw": ray_f_distance_mw,
        "ray_f_up_right_distance_mw": ray_f_up_right_distance_mw,
        "ray_f_down_right_distance_mw": ray_f_down_right_distance_mw,
        "ray_left_distance_mw": ray_left_distance_mw,
        "ray_right_distance_mw": ray_right_distance_mw,

        "rf_col_normal_angle": rf_col_normal_angle,
        "rl_col_normal_angle": rl_col_normal_angle,
        "rr_col_normal_angle": rr_col_normal_angle,
        "rfu_col_normal_angle": rfu_col_normal_angle,
        "rfd_col_normal_angle": rfd_col_normal_angle,

        "finish_distance": finish_distance,
        "finish_angle": finish_angle,

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

  # Apply a threshold in rotations
  var input_rotation = nn_output["go_right"]
  nn_rotation = clamp(input_rotation, -rotation_speed_limit, rotation_speed_limit)

  nn_speed = nn_output["go_forward"]
  var real_speed = clamp(nn_speed * speed, 0.0, speed_limit)
  velocity = Vector2(real_speed, 0).rotated(rotation)


func set_finished_agent():
  game.finished_agent = self.copy()
  game.completion_times.text = String(game.finished_agent.agent_completion_counter)


func finish():
  var finish_time = OS.get_ticks_msec()
  var time = finish_time - start_time
  if agent_completion_counter > 0:
    game.solved_message_box.visible = true

    var fin_agent = game.finished_agent
    if fin_agent == null:
      set_finished_agent()
    else:
      if agent_completion_counter > fin_agent.agent_completion_counter:
        set_finished_agent()
      else:
        if agent_completion_counter == fin_agent.agent_completion_counter &&\
            (lineage_times_finished > fin_agent.lineage_times_finished):
          set_finished_agent()
          # game.finished_agent = self.copy()

    if !game.is_loading_mode_enabled:
      game.save_button.disabled = false
    if time < game.best_time:
      game.best_time = time
      var mins = (time / 1000) / 60
      var secs = (time / 1000) % 60
      var msecs = time - ((mins * 60 * 1000) + (secs * 1000))
      game.solved_best_time.text = String("%02d:%02d:%03d" % [mins, secs, msecs])
  # else:
  #   if !game.is_loading_mode_enabled:
  #     spawn_children(true, true)
  #   kill_agent()

  agent_completion_counter += 1
  # if agent_completion_counter >= 2:
  #   print("counter: %s" % agent_completion_counter)
  position = game.get_initial_pos()
  rotation = 0.0
  death_timer.start()
  lineage_times_finished += 1
  # is_original = true
  game.BAACT.text = String(lineage_times_finished)


func copy():
  var agent: Node2D
  agent = Agent.instance()
  agent.position = game.get_initial_pos()
  agent.rotation = 0.0
  agent.population = population
  agent.nn_activated_inputs = game.input_names.duplicate()
  agent.game = game
  agent.lineage_times_finished = 0
  agent.agent_completion_counter = agent_completion_counter
  var new_genome = Genome.new(population)
  new_genome.copy(genome)
  agent.genome = new_genome
  return agent


func kill_agent():
  if is_dead:
    return
  # if game.is_loading_mode_enabled:
  #   game.generate_from_save()
  is_dead = true
  yield(get_tree(), "idle_frame")
  nn.disolve_nn()
  genome.disolve_genome()

  game.decrement_agent_population()
  # remove_from_group("agents")
  # game.get_node("Agents").remove_child(self)
  queue_free()


func _on_SpawnTimer_timeout():
  if is_dead || game.is_loading_mode_enabled:
    return
  var total_fitness := 0.0
  for i in range(1, FIT_GEN_HORIZON + 1):
    total_fitness += fitness_timeline[-i]
  var avg_fitness = total_fitness / FIT_GEN_HORIZON
  assign_fitness()
  fitness_timeline.append(get_fitness())
  if avg_fitness + FITNESS_IMPROVEMENT_THRESHOLD < get_fitness():
    # spawn_children()
    call_deferred("spawn_children")


func _on_DeathTimer_timeout():
  kill_agent()
  if game.is_loading_mode_enabled:
    game.generate_from_save()


# func _on_NNControlsUpdateTimer_timeout():
#   pass
  # get_nn_controls(nn, get_sensor_input())


# class AgentSorter:
#   static func sort_by_dist_ascenting(a, b):
#     if a[1] < b[1]:
#       return true
#     return false
#
#   static func sort_by_fitness_ascenting(a, b):
#     if a.get_fitness() < b.get_fitness():
#       return true
#     return false

