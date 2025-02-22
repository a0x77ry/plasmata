extends "res://scripts/game.gd"

const GENOME_QUEUE_LIMIT = 100 # last : 100
const COMBAT_AGENT_LIMIT = 80
const WAIT_TIME_ABOVE_GENOME_LIMIT = 0.2
const WAIT_TIME_BELOW_GENOME_LIMIT = 0.2
const DRAW_FITNESS_POINTS := 3.0 # last 3.0
const WIN_FITNESS = 5.0 # last 5.0
const HIT_WIN_FITNESS = 7.0 # last 7.0
const LOW_TIER_THRESHOLD = WIN_FITNESS
const FITNESS_TO_SELECTION_RATE = 8.0 # last 8.0
const REMOVE_ON_LIMIT := 15 # last 10
const THRESHOLD_FOR_NEW_ROUND := 2

export(PackedScene) var BattleCage

onready var battle_cages_node = get_node("BattleCages")
onready var camera = get_node("Camera2D")
onready var cage_fill_timer = get_node("CageFillTimer")
onready var background = get_node("Background")
onready var knockout_label = get_node("CanvasLayer/KnockoutLabel")
onready var stopwatch_label = get_node("CanvasLayer/StopwatchLabel")

var random = RandomNumberGenerator.new()
var agent_population : int = 0
var cage_height := 590
var cage_width := 950
var external_cage_height: float
var external_cage_width: float
var number_of_cages: int
var cages_map := []
var cage_side_size: int
var original_mouse_pos
var available_cages := []
var genome_queue := [] # example: [{"genome": gen01, "children_spawned": 5}]
var is_in_knockout_mode := false
var starting_new_round := false

var is_dragging: bool = false
var combat_time_scale = 1.0
var start_time
var elapsed_time
var pause_start_time


func _ready():
  random.randomize()
  initialize_cages()
  init_population()
  set_time_scale(combat_time_scale)
  unpaused_time_scale = combat_time_scale
  game_name = "combat_game"
  start_time = OS.get_ticks_msec()


func _process(_delta):
  if is_in_knockout_mode || is_game_paused:
    return

  elapsed_time = OS.get_ticks_msec() - start_time
  var msecs_in_an_hour = 1000 * 60 * 60
  var msecs_in_a_minute = 1000 * 60
  var msecs_in_a_second = 1000
  var hours = elapsed_time / msecs_in_an_hour
  var mins = (elapsed_time % msecs_in_an_hour) / msecs_in_a_minute
  var secs = ((elapsed_time % msecs_in_an_hour) % msecs_in_a_minute) / msecs_in_a_second

  stopwatch_label.text = String("%02d:%02d:%02d" % [hours, mins, secs])


func _input(event):
  if event.is_action_pressed("left_click"):
    original_mouse_pos = event.global_position
    is_dragging = true

  if event.is_action_released("left_click"):
    is_dragging = false

  if is_dragging && event is InputEventMouseMotion:
    camera.global_position -= (event.global_position - original_mouse_pos) * camera.zoom
    original_mouse_pos = event.global_position

  if event.is_action_pressed("zoom_in"):
    if camera.zoom.x > 0.11 && camera.zoom.y > 0.11:
      camera.zoom.x -= 0.1
      camera.zoom.y -= 0.1

  if event.is_action_pressed("zoom_out"):
    if camera.zoom.x < 10.0 && camera.zoom.y < 10.0:
      camera.zoom.x += 0.1
      camera.zoom.y += 0.1

  if event.is_action_pressed("knockout"):
    knockout_label.visible = true
    is_in_knockout_mode = true
    cage_fill_timer.stop()


func initialize_cages() -> void:
  cage_side_size = int(ceil(sqrt(COMBAT_AGENT_LIMIT * 0.5)))
  number_of_cages = int(pow(cage_side_size, 2.0))
  external_cage_height = cage_height * cage_side_size
  external_cage_width = cage_width * cage_side_size
  var texture_height = background.texture.get_height()
  var texture_width = background.texture.get_width()
  background.scale.x = external_cage_width / texture_width
  background.scale.y = external_cage_height / texture_height
  for row in cage_side_size:
    cages_map.append([])
    for column in cage_side_size:
      cages_map[row].append({
        "has_cage": true,
        "has_combat": false,
        "pos": Vector2(column * cage_width, row * cage_height)
      })
      var battle_cage = BattleCage.instance()
      battle_cage.game = self
      available_cages.append(battle_cage)
      battle_cage.global_position = cages_map[row][column]["pos"]
      battle_cage.connect("battle_won", self, "_on_battle_won")
      battle_cage.connect("battle_draw", self, "_on_battle_draw")
      battle_cage.connect("cage_cleared", self, "_on_cage_cleared")
      # battle_cage.connect("agent_queued", self, "_on_agent_queued")
      cages_map[row][column]["cage"] = battle_cage
      battle_cages_node.add_child(battle_cage)


func get_initial_pos(cage, side) -> Vector2:
  var starting_pos
  if side == Main.Side.LEFT:
    starting_pos = cage.get_node("StartingPos/LeftStartingPos")
  elif side == Main.Side.RIGHT:
    starting_pos = cage.get_node("StartingPos/RightStartingPos")
  return starting_pos.global_position

func get_initial_rot(side):
  if side == Main.Side.LEFT:
    return 0.0
  elif side == Main.Side.RIGHT:
    return PI


func increment_agent_population(num: int = 1) -> void:
  agent_population += num

func decrement_agent_population(num: int = 1) -> void:
  agent_population -= num


func generate_agent_population():
  var agent: Node2D
  for i in initial_population:
    agent = Agent.instance()

    # Determine cage and side
    if i % 2 == 0:
      agent.side = Main.Side.LEFT
    else:
      agent.side = Main.Side.RIGHT
    var cage_count = i / 2
    var row = cage_count / cage_side_size
    var column = cage_count % cage_side_size
    var cage = cages_map[row][column]["cage"]

    agent.battle_cage = cage
    agent.position = get_initial_pos(cage, agent.side)
    agent.rotation = get_initial_rot(agent.side)

    agent.population = population
    agent.nn_activated_inputs = input_names.duplicate()

    assert(population.genomes[i] != null)
    agent.genome = population.genomes[i]
    cage.add_agent(agent)
    if is_instance_valid(cage.agent_left) && is_instance_valid(cage.agent_right):
      var cage_to_remove
      for av_cage in available_cages:
        if cage.get_instance_id() == av_cage.get_instance_id():
         cage_to_remove = av_cage
      available_cages.erase(cage_to_remove)

    agent.game = self

    agent.add_to_group("agents")
    increment_agent_population()

    agent.connect("agent_removed", self, "decrement_agent_population")
    agent.connect("agent_killed", cage, "_on_agent_death")
    agents_node.call_deferred("add_child", agent)


func spawn_new_agent(b_cage, side, geno: Genome):
  var new_agent = Agent.instance()
  new_agent.position = get_initial_pos(b_cage, side)
  new_agent.rotation = get_initial_rot(side)

  new_agent.battle_cage = b_cage
  new_agent.side = side
  new_agent.population = population
  new_agent.nn_activated_inputs = input_names.duplicate()
  new_agent.genome = geno
  b_cage.add_agent(new_agent)
  # new_agent.current_fitness = geno.fitness
  new_agent.game = self
  new_agent.add_to_group("agents")
  increment_agent_population()
  new_agent.connect("agent_removed", self, "decrement_agent_population")
  new_agent.connect("agent_killed", b_cage, "_on_agent_death")
  b_cage.death_timer.start()
  agents_node.call_deferred("add_child", new_agent)


func get_alter_genome(winner_genome, mate_genome):
  var winner_genome_copy = Genome.new(population)
  winner_genome_copy.copy(winner_genome)
  var crossed_genomes = population\
    .couple_crossover([winner_genome_copy, mate_genome], 1)
  crossed_genomes[0].mutate()
  return crossed_genomes[0]


func genome_duplicate(original_genome: Genome) -> Genome:
  var new_genome = Genome.new(population)
  new_genome.copy(original_genome)
  return new_genome


func remove_random_from_queue():
  var queue_size = genome_queue.size()
  var low_tier_gendicts := []
  var to_be_removed := []

  for i in queue_size:
    if genome_queue[i]["genome"].fitness <= LOW_TIER_THRESHOLD:
      low_tier_gendicts.append(genome_queue[i])
  for i in low_tier_gendicts.size():
    to_be_removed.append(low_tier_gendicts[i])
    low_tier_gendicts[i]["genome"].dissolve_genome()
  
  for gendict in to_be_removed:
    genome_queue.erase(gendict)


func queue_or_dissolve(genome):
  var queue_size = genome_queue.size()
  if queue_size >= GENOME_QUEUE_LIMIT:
    remove_random_from_queue()

  if genome_queue.size() < GENOME_QUEUE_LIMIT:
    genome_queue.append({"genome": genome, "children_spawned": 0})
  else:
    genome.dissolve_genome()


func calc_children_number_and_selection_rate_index(genome_index: int) -> Dictionary:
  var genome_fitness = genome_queue[genome_index]["genome"].fitness
  if is_in_knockout_mode:
    return {"children_number": 1, "selection_rate": 1.0}
  return {"children_number": int(round(genome_fitness)), "selection_rate": genome_fitness / FITNESS_TO_SELECTION_RATE}

func calc_children_number_and_selection_rate_genome(genome: Genome) -> Dictionary:
  var genome_fitness = genome.fitness
  if is_in_knockout_mode:
    return {"children_number": 1, "selection_rate": 1.0}
  return {"children_number": int(round(genome_fitness)), "selection_rate": genome_fitness / FITNESS_TO_SELECTION_RATE}


func get_first_available_cage():
  var cage = available_cages.pop_front()
  # use this if more that two agents appear in a cage
  while cage.has_active_battle:
    cage = available_cages.pop_front()
  return cage


func populate_cage(cage):
  for leftright in 2:
    var main_genome: Genome
    var mate_genome: Genome
    var queue_size = genome_queue.size() # because it could change while searching
    var used_index: int = -1
    assert(queue_size >= 1)
    while main_genome == null || (mate_genome == null && !is_in_knockout_mode):
      main_genome = null
      mate_genome = null
      for i in queue_size:
        var rand_index: int
        rand_index = random.randi_range(0, queue_size - 1)
        while rand_index == used_index:
          rand_index = random.randi_range(0, queue_size - 1)
        var gendict = calc_children_number_and_selection_rate_index(rand_index)
        if random.randf() < gendict["selection_rate"]:
          if main_genome == null:
            main_genome = genome_duplicate(genome_queue[rand_index]["genome"])
            genome_queue[rand_index]["children_spawned"] += 1
            used_index = rand_index
            if is_in_knockout_mode:
              break
          elif mate_genome == null:
            mate_genome = genome_duplicate(genome_queue[rand_index]["genome"])
            var mate_children_num: int
            mate_children_num = 1
            genome_queue[rand_index]["children_spawned"] += mate_children_num
    var current_side
    if leftright == 0:
      current_side = Main.Side.LEFT
    else:
      current_side = Main.Side.RIGHT
    if is_in_knockout_mode:
      spawn_new_agent(cage, current_side, main_genome)
      continue
    spawn_new_agent(cage, current_side, get_alter_genome(main_genome, mate_genome))

  # erase cage from available_cages
  assert(cage.agent_left != null && cage.agent_right != null)
  available_cages.erase(cage)


func start_new_round():
  Engine.time_scale = 0.0
  assert(genome_queue.size() >= 2)
  starting_new_round = true
  while available_cages.size() > 0:
    var cage = get_first_available_cage()
    populate_cage(cage)
    herod()
    if genome_queue.size() < 2:
      break
  starting_new_round = false
  Engine.time_scale = combat_time_scale


func _on_battle_won(winner_gen, is_won_with_hit):
  if !(is_in_knockout_mode && genome_queue.size() <= 0 \
      && get_active_agents().size() <= THRESHOLD_FOR_NEW_ROUND \
      && !starting_new_round):
    if is_won_with_hit:
      winner_gen.fitness = HIT_WIN_FITNESS
    else:
      winner_gen.fitness = WIN_FITNESS
    queue_or_dissolve(winner_gen)

  if is_in_knockout_mode && genome_queue.size() <= 0 \
      && get_active_agents().size() <= THRESHOLD_FOR_NEW_ROUND \
      && !starting_new_round:
    # Engine.time_scale = 0.0
    winner_genome = winner_gen
    enter_save_menu(true)

  elif is_in_knockout_mode && genome_queue.size() < 2:
    return
  elif is_in_knockout_mode && get_active_agents().size() <= THRESHOLD_FOR_NEW_ROUND:
    start_new_round()
    return


func _on_battle_draw(left_genome, right_genome):
  if is_in_knockout_mode:
    yield(get_tree(), "idle_frame")

  if is_in_knockout_mode && get_active_agents().size() <= THRESHOLD_FOR_NEW_ROUND:
    if genome_queue.size() == 0:
      left_genome.fitness = DRAW_FITNESS_POINTS
      right_genome.fitness = DRAW_FITNESS_POINTS
      queue_or_dissolve(left_genome)
      queue_or_dissolve(right_genome)
    elif genome_queue.size() == 1 && !starting_new_round:
      # Engine.time_scale = 0.0
      winner_genome = genome_queue[0]
      enter_save_menu(true)

    assert(genome_queue.size() >= 2)
    start_new_round()
    return

  if !is_in_knockout_mode:
    left_genome.fitness = DRAW_FITNESS_POINTS
    right_genome.fitness = DRAW_FITNESS_POINTS
    queue_or_dissolve(left_genome)
    queue_or_dissolve(right_genome)


func _on_cage_cleared(cage):
  available_cages.append(cage)


# Remove excess genomes
func herod():
  var gen_queue_dict_to_be_erased := []
  for gen_queue_dict in genome_queue:
    var gen_calc_dict = calc_children_number_and_selection_rate_genome(gen_queue_dict["genome"])
    if gen_queue_dict["children_spawned"] >= gen_calc_dict["children_number"]:
      gen_queue_dict_to_be_erased.append(gen_queue_dict)
  for gen_queue_dict in gen_queue_dict_to_be_erased:
    genome_queue.erase(gen_queue_dict)


func pause():
  if !is_game_paused:
    pause_start_time = OS.get_ticks_msec()
  else:
    start_time += OS.get_ticks_msec() - pause_start_time
  .pause()



func _on_CageFillTimer_timeout():
  if get_active_agents().size() > COMBAT_AGENT_LIMIT || \
      (is_in_knockout_mode && genome_queue.size() <= 2) || \
      genome_queue.size() <= 2:
    herod()
    return

  if genome_queue.size() > round(GENOME_QUEUE_LIMIT * 0.5):
    cage_fill_timer.wait_time = WAIT_TIME_ABOVE_GENOME_LIMIT
  else:
    cage_fill_timer.wait_time = WAIT_TIME_BELOW_GENOME_LIMIT

  if available_cages.size() > 0:
    assert(genome_queue.size() > 2)
    var cage = get_first_available_cage()

    populate_cage(cage)
    herod()

