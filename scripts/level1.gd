extends Node2D

const TARGET_POPULATION := 32

onready var spawning_area = get_node("SpawningArea")
onready var timer = get_node("Timer")
onready var countdown = get_node("Countdown/Time")
onready var gen_counter = get_node("GenCounter/GenNumber")
onready var curve = get_node("Path2D").curve

var number_of_agents = TARGET_POPULATION
var number_of_extra_agents = 0
var agents = []


func _ready():
  randomize()
  if !Main.genomes.empty():
    number_of_agents = Main.genomes.size()
  generate_population()
  Main.generation += 1
  gen_counter.text = str(Main.generation)


func _process(_delta):
  # if Input.is_action_just_pressed("ui_accept"):
  #   change_generation()

  countdown.text = String("%.1f" % timer.time_left)


func change_generation():
    Main.calculate_fitness(curve, agents) # gives each of Main.genomes a fitness value
    Main.speciate() # populates Main.species with Main.genomes
    Main.share_fitness() # creates an adjusted_fitness in each species
    Main.select_in_species(agents.size() * Main.SELECTION_RATE) # populates avg_fitness and parent_genomes for each species
    var crossovered_genomes = Main.crossover()
    Main.genomes = Main.mutate(crossovered_genomes)
    # breakpoint
    var err = get_tree().change_scene("res://level1.tscn")
    if err:
      print("Failed to load scene with error: %s" % err)
    # Main.get_level()


func generate_population():
  var agent: Node2D
  var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  for i in range(number_of_agents + number_of_extra_agents):
    agent = preload("res://agent.tscn").instance()
    var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
        spawning_area.get_position().x + area_extents.x)
    var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
        spawning_area.get_position().y + area_extents.y)
    # if !Main.genomes.empty() && i < number_of_agents: 
    if Main.genomes.size() - 1 >= i && i < number_of_agents: 
    # if !Main.generation > 0 && i < number_of_agents: 
      agent.set_genome(Main.genomes[i])
    agent.set_position(Vector2(pos_x, pos_y))
    # agent.rotation = Main.init_rot
    agent.rotation = rand_range(-PI, PI)
    agent.timer = get_node("Timer")
    agents.append(agent)
    agent.add_to_group("agents")
    add_child(agent)


func _on_FinishLine_body_entered(body:Node):
  if body.is_in_group("agents"):
    change_generation()


func _on_Timer_timeout():
  change_generation()

