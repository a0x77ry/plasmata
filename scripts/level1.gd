extends Node2D

const TIME = 20
const TARGET_POPULATION = 110

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
var unpaused_time_scale := 3
var Agent = preload("res://agent.tscn")

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
  set_time_scale(unpaused_time_scale)
  do_pause_when_solved = pause_when_solved_button.pressed


func _process(_delta):
  if Input.is_action_just_pressed("ui_accept"):
    pause()
  countdown.text = String("%.1f" % timer.time_left)


func init_population():
  var starting_gen = 0
  if population != null:
    starting_gen = population.generation
  population = Population.new([], [], input_names, output_names,
      starting_gen, TARGET_POPULATION)
  number_of_agents = population.target_population
  generate_agent_population()
  change_generation()


func change_generation():
  agents_alive = get_tree().get_nodes_in_group("agents")
  if agents_alive.size() == 0:
    init_population()
    return
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


func generate_agent_population():
  agents = []
  var agent: Node2D
  var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  for i in number_of_agents:
    # agent = preload("res://agent.tscn").instance()
    agent = Agent.instance()
    # Set the initial position and rotation of the agent
    var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
        spawning_area.get_position().x + area_extents.x)
    var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
        spawning_area.get_position().y + area_extents.y)
    agent.set_position(Vector2(pos_x, pos_y))
    agent.rotation = rand_range(-PI, PI)

    agent.timer = timer
    agent.nn_activated_inputs = input_names
    # if population.genomes.size() >= i && i <= number_of_agents: 
    assert(population.genomes[i] != null)
    agent.set_genome(population.genomes[i])
    agent.modulate = agent.genome.tint

    agent.timer = get_node("Timer")
    agents.append(agent)
    agent.add_to_group("agents")
    agents_node.add_child(agent)


func pause():
  if !is_game_paused:
    Engine.time_scale = 0.0
    is_game_paused = true
    pause_message.visible = true
    FF_slider.editable = false
    FF_slider.scrollable = false
  else:
    Engine.time_scale = unpaused_time_scale
    is_game_paused = false
    pause_message.visible = false
    FF_slider.editable = true
    FF_slider.scrollable = true


func set_time_scale(value):
  if !is_game_paused:
    unpaused_time_scale = value
    Engine.time_scale = value
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
      pause()


func _on_Timer_timeout():
  change_generation()


func _on_CheckButton_toggled(button_pressed):
  do_pause_when_solved = button_pressed 


func _on_FFSlider_value_changed(value):
  set_time_scale(value)
  
