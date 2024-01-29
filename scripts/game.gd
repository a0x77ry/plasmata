extends Node2D

# const TIME =
export(int, 200) var time
export(int, 200) var target_population
export(PackedScene) var Agent
export(int, 10) var unpaused_time_scale = 0

onready var timer = get_node("Timer")
onready var pause_message = get_node("UI/Pause")
onready var agents_node = get_node("Agents")

var population
var number_of_agents
var agents = []
var agents_alive = []
var is_game_paused := false

var input_names = []
var output_names = []


func init_population():
  var starting_gen = 0
  if population != null:
    starting_gen = population.generation
  population = Population.new([], [], input_names, output_names,
      starting_gen, target_population)
  number_of_agents = population.target_population
  generate_agent_population()
  change_generation()


func generate_agent_population():
  pass


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
    timer.start(time)
  else:
    timer.start(0.1)


func pause():
  if !is_game_paused:
    Engine.time_scale = 0.0
    is_game_paused = true
    pause_message.visible = true
  else:
    Engine.time_scale = unpaused_time_scale
    is_game_paused = false
    pause_message.visible = false


func set_time_scale(value):
  if !is_game_paused:
    unpaused_time_scale = value
    Engine.time_scale = value