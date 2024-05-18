extends Node2D

# const TIME =
export(int, 200) var time
export(int, 400) var target_population
export(PackedScene) var Agent
export(int, 10) var unpaused_time_scale = 0
export(float, 10.0) var mut_std_dev = 2.0

onready var timer = get_node("Timer")
onready var pause_message = get_node("UI/Pause")
onready var agents_node = get_node("Agents")
# onready var spawning_area = get_node("SpawningArea")

var population
var number_of_agents
var agents = []
var agents_alive = []
var is_game_paused := false

var input_names = []
var output_names = []


func _process(_delta):
  if Input.is_action_just_pressed("pause"):
    pause()

func init_population():
  var starting_gen = 0
  if population != null:
    starting_gen = population.generation
  population = Population.new([], input_names, output_names,
      starting_gen, target_population)
  number_of_agents = population.target_population
  generate_agent_population()
  change_generation()


func restart_population():
  agents_alive = get_tree().get_nodes_in_group("agents")
  for agent in agents_alive:
    agent.queue_free()
  population.genomes = []
  population = Population.new([], input_names, output_names,
      0, target_population)
  number_of_agents = population.target_population
  generate_agent_population()
  timer.start(0.1)

func generate_agent_population():
  pass

# func generate_agent_population():
#   agents = []
#   var agent: Node2D
#   var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
#   for i in number_of_agents:
#     agent = Agent.instance()
#     # Set the initial position and rotation of the agent
#     var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
#         spawning_area.get_position().x + area_extents.x)
#     var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
#         spawning_area.get_position().y + area_extents.y)
#     agent.set_position(Vector2(pos_x, pos_y))
#     agent.rotation = rand_range(-PI, PI)
#
#     agent.timer = timer
#     agent.nn_activated_inputs = input_names
#     assert(population.genomes[i] != null)
#     agent.set_genome(population.genomes[i])
#     agent.modulate = agent.genome.tint
#
#     agents.append(agent)
#     agent.add_to_group("agents")
#     agents_node.add_child(agent)
#

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


func is_paused():
  return is_game_paused


func set_time_scale(value):
  if !is_game_paused:
    unpaused_time_scale = value
    Engine.time_scale = value


func _on_Quit_pressed():
  get_tree().quit(0)


func _on_Resume_pressed():
  pause()


func _on_Restart_pressed():
  restart_population()
  pause()


func _on_MainMenu_pressed():
  pause()
  var err = get_tree().change_scene("res://menu/main-menu/main-menu.tscn")
  if err != OK:
    print("Cannot change scene")
