extends Node2D

const TIME = 20

onready var spawning_area = get_node("SpawningArea")
onready var timer = get_node("Timer")
onready var countdown = get_node("UI/Countdown/Time")
onready var gen_counter = get_node("UI/Statistics/GenCounter/GenNumber")
onready var genome_counter = get_node("UI/Statistics/Genomes/GenomesNumber")
onready var species_counter = get_node("UI/Statistics/Species/SpeciesNum")
onready var curve = get_node("Path2D").curve
onready var solved_message_box = get_node("UI/SolvedMessage")
onready var solved_best_time = get_node("UI/SolvedMessage/HBox/BestTime/HBox/Time")
onready var winning_color_panel = get_node("UI/SolvedMessage/HBox/BestTime/HBox/WinningColor").get_stylebox("panel")
onready var pause_message = get_node("UI/Pause")
onready var time_scale_label = get_node("UI/TimeScale/TimeScaleLabel")
onready var FF_slider = get_node("UI/TimeScale/FFSlider")
onready var pause_when_solved_button = get_node("UI/PauseWhenSolved/CheckButton")
onready var agents_node = get_node("Agents")

var population
var number_of_agents
var agents = []
var agents_alive = []
var best_time = INF
var do_pause_when_solved
var is_game_paused := false

var input_names = [
  "rotation",
  # "inverse_rotation",
  # "time_since_birth",
  # "pos_x",
  # "pos_y",
  "ray_f_distance",
  "ray_f_up_right_distance",
  "ray_f_down_right_distance",
  "ray_left_distance",
  "ray_right_distance",
  "fitness",
  # "go_right_input",
  # "go_forward_input"
]
var output_names = [
  "go_right",
  "go_forward"
]

func _ready():
  randomize()
  init_population()
  set_time_scale(Main.TIME_SCALE)
  do_pause_when_solved = pause_when_solved_button.pressed


func _process(_delta):
  # if Input.is_action_just_pressed("ui_accept"):
  #   change_generation()

  countdown.text = String("%.1f" % timer.time_left)


func init_population():
  var starting_gen = 0
  if population != null:
    starting_gen = population.generation
  population = Population.new([], [], input_names, output_names, starting_gen)
  number_of_agents = population.target_population
  # population.init_genomes(input_names, output_names, number_of_agents)
  generate_agent_population()
  change_generation()
  # population.increment_generation()
  # gen_counter.text = str(population.generation)


func change_generation():
    agents_alive = get_tree().get_nodes_in_group("agents")
    if agents_alive.size() == 0:
      print("Agents 0: Restart")
      init_population()
      return
    # population.next_generation(agents_alive)
    population.next_generation(agents_alive)
    number_of_agents = population.genomes.size()
    for agent in agents_alive:
      agent.queue_free()
    generate_agent_population()
    if number_of_agents > 0:
      timer.start(TIME)
    else:
      timer.start(0.1)
    gen_counter.text = str(population.generation)
    genome_counter.text = str(population.genomes.size())
    species_counter.text = str(population.species.size())

    # Main.calculate_fitness(curve, agents_alive) # gives each of Main.genomes a fitness value
    # Main.speciate() # populates Main.species with Main.genomes
    # Main.share_fitness() # creates an adjusted_fitness in each species
    # # populates avg_fitness and parent_genomes for each species
    # # kills species with no members
    # Main.select_in_species(agents.size() * Main.SELECTION_RATE)
    # var crossovered_genomes = Main.crossover()
    # Main.genomes = Main.mutate(crossovered_genomes)
    # var err = get_tree().change_scene("res://level1.tscn")
    # if err:
    #   print("Failed to load scene with error: %s" % err)
    # Main.get_level()


func generate_agent_population():
  agents = []
  var agent: Node2D
  var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  for i in number_of_agents:
    agent = preload("res://agent.tscn").instance()
    # Set the initial position and rotation of the agent
    var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
        spawning_area.get_position().x + area_extents.x)
    var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
        spawning_area.get_position().y + area_extents.y)
    agent.set_position(Vector2(pos_x, pos_y))
    agent.rotation = rand_range(-PI, PI)

    agent.nn_activated_inputs = input_names
    # if population.genomes.size() >= i && i <= number_of_agents: 
    assert(population.genomes[i] != null)
    agent.set_genome(population.genomes[i])
    agent.modulate = agent.genome.tint

    agent.timer = get_node("Timer")
    agents.append(agent)
    agent.add_to_group("agents")
    agents_node.add_child(agent)


func pause(is_paused):
  if is_paused:
    pause_message.visible = true
    is_game_paused = true
    FF_slider.editable = false
    FF_slider.scrollable = false
  else:
    pause_message.visible = false
    is_game_paused = false
    FF_slider.editable = true
    FF_slider.scrollable = true


func set_time_scale(value):
  if !is_game_paused:
    Main.change_time_scale(value)
    time_scale_label.text = "Time Scale: %sx" % value


func _on_FinishLine_body_entered(body:Node):
  if body.is_in_group("agents"):
    var agent = body as Node2D
    agent.finish(timer.time_left)
    solved_message_box.visible = true
    var time = TIME - timer.time_left
    if time < best_time:
      best_time = time
      solved_best_time.text = String("%.2f" % time)
      winning_color_panel.bg_color = agent.genome.tint
    if do_pause_when_solved:
      Main.pause()


func _on_Timer_timeout():
  change_generation()


func _on_CheckButton_toggled(button_pressed):
  do_pause_when_solved = button_pressed 


func _on_FFSlider_value_changed(value):
  set_time_scale(value)
  
