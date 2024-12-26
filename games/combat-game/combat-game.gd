extends "res://scripts/game.gd"

const HIT_WIN_FITNESS_POINTS := 6.0
const WINNING_FITNESS_POINTS := 3.0
const DRAW_FITNESS_POINTS := 1.0
const GENOME_QUEUE_LIMIT = 100 
const TOTAL_QUEUE_CHILDREN = GENOME_QUEUE_LIMIT# * 8
const COMBAT_AGENT_LIMIT = 80
const GENOME_QUEUE_SOFT_LIMIT = 50
const WAIT_TIME_ABOVE_GENOME_LIMIT = 0.2
const WAIT_TIME_BELOW_GENOME_LIMIT = 0.4
const HIT_WIN_CHILDREN = 6
const WIN_CHILDREN = 3
const DRAW_CHILDREN = 1
const HIT_WIN_RELATIVE_FITNESS = 0.8
const WIN_RELATIVE_FITNESS = 0.4
const DRAW_REALTIVE_FITNESS = 0.1
const INDEX_DIVISOR = 3

export(PackedScene) var BattleCage

onready var battle_cages_node = get_node("BattleCages")
onready var camera = get_node("Camera2D")
onready var cage_fill_timer = get_node("CageFillTimer")

var random = RandomNumberGenerator.new()
var agent_population : int = 0
var cage_height := 590
var cage_width := 950
var number_of_cages: int
var cages_map := []
var cage_side_size: int
var original_mouse_pos
var available_cages := []
# var agent_queue := []
var genome_queue := [] # example: [{"genome": gen01, "children_spawned": 5}]

var is_dragging: bool = false
var combat_time_scale = 2.0


func _ready():
  random.randomize()
  initialize_cages()
  init_population()
  set_time_scale(combat_time_scale)
  unpaused_time_scale = combat_time_scale


func _physics_process(_delta):
  if Input.is_action_just_pressed("left_click"):
    is_dragging = true
  # agent_queue.sort_custom(AgentSorter, "sort_by_fitness_ascenting")


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
    camera.zoom.x -= 0.1
    camera.zoom.y -= 0.1

  if event.is_action_pressed("zoom_out"):
    camera.zoom.x += 0.1
    camera.zoom.y += 0.1


func initialize_cages() -> void:
  cage_side_size = int(ceil(sqrt(COMBAT_AGENT_LIMIT * 0.5)))
  number_of_cages = int(pow(cage_side_size, 2.0))
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
  # print("New agent fitness: %s" % new_agent.current_fitness)
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


func queue_or_dissolve(genome):
  if genome_queue.size() < GENOME_QUEUE_LIMIT:
    genome_queue.append({"genome": genome, "children_spawned": 0})
  else:
    if genome.fitness >= WINNING_FITNESS_POINTS:
      for i in genome_queue.size():
        if genome_queue[i]["genome"].fitness <= DRAW_FITNESS_POINTS:
          genome_queue[i]["genome"].dissolve_genome()
          genome_queue[i] = {"genome": genome, "children_spawned": 0}
          return
    else:
      genome.dissolve_genome()



# Determines the maximum number of children a genome in the queue can have
func calc_children_number_and_relative_fitness(genome_index: int) -> Dictionary:
  # var total_fitness := 0.0
  var min_fitness: float = INF
  var max_fitness := 0.0
  for gen_dict in genome_queue:
    var gen_fitness = gen_dict["genome"].fitness
    if gen_fitness < min_fitness:
      min_fitness = gen_fitness
    if gen_fitness > max_fitness:
      max_fitness = gen_fitness
    # total_fitness += gen_dict["genome"].fitness
  var fitness_range = max(max_fitness - min_fitness, 0.0001)
  # print(fitness_range)
  # var relative_fitness = genome_queue[genome_index]["genome"].fitness / total_fitness
  var relative_fitness = max((genome_queue[genome_index]["genome"].fitness - min_fitness), 0.0001) / fitness_range
  # print(relative_fitness)
  # var children_number = max(int(round(relative_fitness * TOTAL_QUEUE_CHILDREN)), 1)
  var children_number = int(round(relative_fitness * 10))
  # print(children_number)
  var dict = {"children_number": children_number, "relative_fitness": relative_fitness}
  return dict


func calc_children_number_and_relative_fitness_non_cumulative(genome_index: int) -> Dictionary:
  # var win_num
  # var draw_num
  # if genome_queue.size() < 200:
  #   win_num = 5
  #   draw_num = 2
  # else:
  #   win_num = 2
  #   draw_num = 1
  var win_num = WIN_CHILDREN
  var hit_win_num = HIT_WIN_CHILDREN
  var draw_num = DRAW_CHILDREN
  if genome_queue[genome_index]["genome"].fitness == WINNING_FITNESS_POINTS:
    return {"children_number": hit_win_num, "relative_fitness": WIN_RELATIVE_FITNESS}
  elif genome_queue[genome_index]["genome"].fitness == HIT_WIN_FITNESS_POINTS:
    return {"children_number": win_num, "relative_fitness": HIT_WIN_RELATIVE_FITNESS}
  else:
    return {"children_number": draw_num, "relative_fitness": DRAW_REALTIVE_FITNESS}


func _on_battle_won(winner_genome, is_won_with_hit):
  # winner_genome.fitness += WINNING_FITNESS_POINTS
  if is_won_with_hit:
    winner_genome.fitness = HIT_WIN_FITNESS_POINTS
  else:
    winner_genome.fitness = WINNING_FITNESS_POINTS
  queue_or_dissolve(winner_genome)


func _on_battle_draw(left_genome, right_genome):
  # left_genome.fitness += DRAW_FITNESS_POINTS
  # right_genome.fitness += DRAW_FITNESS_POINTS
  left_genome.fitness = DRAW_FITNESS_POINTS
  right_genome.fitness = DRAW_FITNESS_POINTS
  queue_or_dissolve(left_genome)
  queue_or_dissolve(right_genome)


func _on_cage_cleared(cage):
  available_cages.append(cage)


func _on_CageFillTimer_timeout():
  if get_active_agents().size() > COMBAT_AGENT_LIMIT:
    return
  if genome_queue.size() > GENOME_QUEUE_LIMIT:
    cage_fill_timer.wait_time = WAIT_TIME_ABOVE_GENOME_LIMIT
  else:
    cage_fill_timer.wait_time = WAIT_TIME_BELOW_GENOME_LIMIT
  if available_cages.size() > 0 && genome_queue.size() >= 1:
    var cage = available_cages.pop_front()
    # use this if more that two agents appear in a cage
    while cage.has_active_battle:
      cage = available_cages.pop_front()

    # determine main and mate genomes
    for leftright in 2:
      var main_genome: Genome
      var mate_genome: Genome
      var original_gene_trasfer: bool = false
      if genome_queue.size() == 1:
        original_gene_trasfer = true
        main_genome = genome_duplicate(genome_queue[0]["genome"])
        mate_genome = genome_duplicate(genome_queue[0]["genome"])
        genome_queue[0]["children_spawned"] += 2
      else:
        var queue_size = genome_queue.size() # because it could change while searching
        while main_genome == null || mate_genome == null: 
          if genome_queue.size() == 0:
           return
          for i in queue_size:
            var rand_index = random.randi_range(0, queue_size - 1)
            var gendict = calc_children_number_and_relative_fitness_non_cumulative(rand_index)
            if random.randf() < gendict["relative_fitness"]:
              if main_genome == null:
                main_genome = genome_duplicate(genome_queue[rand_index]["genome"])
                if (rand_index % INDEX_DIVISOR) == 0:
                  original_gene_trasfer = true
                else:
                  original_gene_trasfer = false
                genome_queue[rand_index]["children_spawned"] += 1
              elif mate_genome == null:
                mate_genome = genome_duplicate(genome_queue[rand_index]["genome"])
                var mate_children_num: int
                if original_gene_trasfer:
                  mate_children_num = 0
                else:
                  mate_children_num = 1
                genome_queue[rand_index]["children_spawned"] += mate_children_num
      var current_side
      if leftright == 0:
        current_side = Main.Side.LEFT
      else:
        current_side = Main.Side.RIGHT
      if original_gene_trasfer:
        spawn_new_agent(cage, current_side, main_genome)
      else:
        spawn_new_agent(cage, current_side, get_alter_genome(main_genome, mate_genome))

    var queue_size = genome_queue.size()
    var removed_counter := 0
    for i in queue_size:
      if i > queue_size - 1 - removed_counter:
        break
      var gendict = calc_children_number_and_relative_fitness_non_cumulative(i)
      if genome_queue[i]["children_spawned"] >= gendict["children_number"]:
        genome_queue.remove(i)
        removed_counter += 1

    for av_cage in available_cages:
      if av_cage.agent_left != null || av_cage.agent_right != null:
        available_cages.erase(av_cage)

