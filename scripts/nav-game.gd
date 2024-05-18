extends "res://scripts/game.gd"

onready var spawning_area = get_node("SpawningArea")
onready var countdown = get_node("UI/Countdown/Time")
onready var gen_counter = get_node("UI/Statistics/GenCounter/GenNumber")
onready var genome_counter = get_node("UI/Statistics/Genomes/GenomesNumber")
onready var curve = get_node("Path2D").curve
onready var solved_message_box = get_node("UI/SolvedMessage")
onready var solved_best_time = get_node("UI/SolvedMessage/HBox/BestTime/HBox/Time")
onready var winning_color_panel = get_node("UI/SolvedMessage/HBox/BestTime/HBox/WinningColor").get_stylebox("panel")
onready var time_scale_label = get_node("UI/TimeScale/TimeScaleLabel")
onready var FF_slider = get_node("UI/TimeScale/FFSlider")
onready var pause_when_solved_button = get_node("UI/PauseWhenSolved/CheckButton")

var best_time = INF
var do_pause_when_solved


func _ready():
  # randomize()
  init_population()
  set_time_scale(unpaused_time_scale)
  do_pause_when_solved = pause_when_solved_button.pressed


func generate_agent_population():
  agents = []
  var agent: Node2D
  var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  for i in number_of_agents:
    agent = Agent.instance()
    # Set the initial position and rotation of the agent
    var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
        spawning_area.get_position().x + area_extents.x)
    var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
        spawning_area.get_position().y + area_extents.y)
    agent.set_position(Vector2(pos_x, pos_y))
    agent.rotation = rand_range(-PI, PI)

    # agent.population = population
    agent.timer = timer
    agent.nn_activated_inputs = input_names
    assert(population.genomes[i] != null)
    agent.set_genome(population.genomes[i])
    agent.modulate = agent.genome.tint

    agents.append(agent)
    agent.add_to_group("agents")
    agents_node.add_child(agent)


func _process(_delta):
  countdown.text = String("%.1f" % timer.time_left)


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


func _on_FinishLine_body_entered(body:Node):
  if body.is_in_group("agents"):
    var agent = body as Node2D
    agent.finish(timer.time_left)
    solved_message_box.visible = true
    var _time = time - timer.time_left
    if _time < best_time:
      best_time = _time
      solved_best_time.text = String("%.2f" % _time)
      winning_color_panel.bg_color = agent.genome.tint
    if do_pause_when_solved:
      pause()


func _on_Timer_timeout():
  change_generation()


func _on_CheckButton_toggled(button_pressed):
  do_pause_when_solved = button_pressed 


func _on_FFSlider_value_changed(value):
  set_time_scale(value)

