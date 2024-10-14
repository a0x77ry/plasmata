extends "res://scripts/game.gd"

onready var spawning_area = get_node("SpawningArea")
onready var countdown = get_node("UI/Countdown/Time")
onready var gen_counter = get_node("UI/Statistics/GenCounter/GenNumber")
onready var genome_counter = get_node("UI/Statistics/Genomes/GenomesNumber")
onready var curve = get_node("Path2D").curve
onready var solved_message_box = get_node("UI/SolvedMessage")
onready var solved_best_time = get_node("UI/SolvedMessage/HBox/BestTime/HBox/Time")
onready var BAACT = get_node("UI/SolvedMessage/HBox/BAACT/HBox/CompletionTimes")
onready var winning_color_panel = get_node("UI/SolvedMessage/HBox/BestTime/HBox/WinningColor").get_stylebox("panel")
onready var time_scale_label = get_node("UI/TimeScale/TimeScaleLabel")
onready var FF_slider = get_node("UI/TimeScale/FFSlider")
onready var pause_when_solved_button = get_node("UI/PauseWhenSolved/CheckButton")
onready var save_button = get_node("UI/Pause/VBoxContainer/SaveBestAgent")
onready var spawn_timer = get_node("SpawnTimer")
onready var finish_area = get_node("FinishLine")
onready var completion_times = get_node("UI/CompletionTimesBox/CompletionTimesValue")

var best_time = INF
var do_pause_when_solved
var random = RandomNumberGenerator.new()
var agent_population : int = 0
var start_finish_distance: float
var fa_collision_mask
var fa_col_result
# var filename_to_load: String


func _ready():
  random.randomize()
  init_population()
  set_time_scale(unpaused_time_scale)
  do_pause_when_solved = pause_when_solved_button.pressed
  start_finish_distance = spawning_area.global_position.distance_to(finish_area.global_position)
  fa_collision_mask = 0b100
  game_name = "nav_game"


# func _process(_delta):
#   countdown.text = String("%.1f" % timer.time_left)


func _physics_process(_delta):
  var space_state = get_world_2d().direct_space_state
  fa_col_result = space_state.intersect_ray(global_position, finish_area.global_position,
      [self], fa_collision_mask, true, true)


func get_initial_pos() -> Vector2:
  var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
      spawning_area.get_position().x + area_extents.x)
  var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
      spawning_area.get_position().y + area_extents.y)
  return Vector2(pos_x, pos_y)


func generate_agent_population(agent_pop = population_stream):
  var agents = []
  var agent: Node2D
  # var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  for i in agent_pop:
    if agent_population < ceil(Main.AGENT_LIMIT / 3.0):
      agent = Agent.instance()
      # Set the initial position and rotation of the agent
      agent.position = get_initial_pos()
      # agent.rotation = rand_range(-PI, PI)
      agent.rotation = 0.0

      agent.population = population
      agent.nn_activated_inputs = input_names.duplicate()
      assert(population.genomes[i] != null)
      # agent.set_genome(population.genomes[i])

      # var geno = Genome.new(population)
      # geno.duplicate(population.genomes[i])
      # agent.genome = geno

      agent.genome = population.genomes[i]

      # agent.modulate = agent.genome.tint
      agent.game = self
      agent.lineage_times_finished = 0

      agents.append(agent)
      agent.add_to_group("agents")
      increment_agent_population()
      # agents_node.add_child(agent)
      agents_node.call_deferred("add_child", agent)
      # agents_node.add_child(agent)


func generate_from_save():
  var agent: Node2D
  agent = Agent.instance()

  agent.position = get_initial_pos()
  agent.rotation = 0.0
  agent.population = population
  agent.nn_activated_inputs = input_names.duplicate()
  agent.game = self
  agent.lineage_times_finished = 0

  var gen = Genome.new(population)
  gen.from_dict(load_agent(Main.filename_to_load))
  agent.genome = gen

  agent.game = self
  agent.lineage_times_finished = 0
  agent.add_to_group("agents")
  increment_agent_population()
  agents_node.call_deferred("add_child", agent)


func decrement_agent_population(num: int = 1) -> void:
  agent_population -= num

func increment_agent_population(num: int = 1) -> void:
  agent_population += num


func restart_population_specific():
  best_time = INF
  solved_best_time.text = "-"
  BAACT.text = "0"
  solved_message_box.visible = false


func change_generation():
  .change_generation()
  gen_counter.text = str(population.generation)
  genome_counter.text = str(population.genomes.size())


func set_time_scale(value):
  .set_time_scale(value)
  time_scale_label.text = "Time Scale: %sx" % value


func pause():
  .pause()
  if is_paused():
    FF_slider.editable = false
    FF_slider.scrollable = false
  else:
    FF_slider.editable = true
    FF_slider.scrollable = true


# func save_best_agent():
#   pass


func _on_FinishLine_body_entered(body:Node):
  if body.is_in_group("agents"):
    var agent = body as Node2D
    agent.finish()
    # if do_pause_when_solved && agent.is_original:
    #   pause()


# func _on_Timer_timeout():
#   change_generation()


func _on_CheckButton_toggled(button_pressed):
  do_pause_when_solved = button_pressed 


func _on_FFSlider_value_changed(value):
  set_time_scale(value)

func _on_SpawnTimer_timeout():
  if is_loading_mode_enabled:
    return
  var agents = get_active_agents()
  if agents.size() < ceil(Main.AGENT_LIMIT / 5.0):
    generate_agent_population()

