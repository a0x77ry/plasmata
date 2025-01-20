extends Node2D

# const TIME =
export(int, 200) var time
export(PackedScene) var Agent
export(int, 10) var unpaused_time_scale = 3
export(float, 10.0) var mut_std_dev = 2.0
export(int, 400) var initial_population = 20

# onready var timer = get_node("Timer")
onready var pause_message = get_node("UI/Pause")
# onready var pause_ui = get_node("UI/Pause")
onready var agents_node = get_node("Agents")
onready var save_ui = get_node("UI/SaveUI")
onready var save_ui_lineedit = get_node("UI/SaveUI/VBoxContainer/Filename")

var population
var agents_alive = []
var is_game_paused := false
var input_names = []
var output_names = []
# var sorted_agents = []
var is_loading_mode_enabled := false
var finished_agent
var winner_genome
var game_name
var level_name
var is_in_save_menu := false
var exit_when_finished_saving := false


func _process(_delta):
  if Input.is_action_just_pressed("pause") && !is_in_save_menu:
    pause()


func _physics_process(_delta):
  pass
  # sorted_agents = get_active_agents()
  # sorted_agents.sort_custom(AgentSorter, "sort_by_fitness_ascenting")


func init_population():
  if !is_loading_mode_enabled:
    population = Population.new([], input_names, output_names, initial_population)
  else:
    population = Population.new([], input_names, output_names, initial_population, true)
  if !is_loading_mode_enabled:
    generate_agent_population()
  else:
    generate_from_save()


func save(genome_dict, filename):
  var save_game = File.new()

  var dir = Directory.new()
  var dirpath = "user://{game_name}/{level_name}".format({"game_name": game_name, "level_name": level_name})
  if !dir.dir_exists(dirpath):
    if dir.make_dir_recursive(dirpath) != OK:
      printerr("Cannot make save directory")

  var filepath = "user://{game_name}/{level_name}/{filename}.save"\
      .format({"game_name": game_name, "level_name": level_name, "filename": filename})
  save_game.open(filepath, File.WRITE)
  save_game.store_line(to_json(genome_dict))
  save_game.close()


func load_agent(name, game_name: String) -> Dictionary:
  var saved_agent = File.new()
  var filepath = "user://{game_name}/{level_name}/{name}"\
      .format({"game_name": game_name, "level_name": level_name, "name": name})
  assert(saved_agent.file_exists(filepath))
  saved_agent.open(filepath, File.READ)
  var saved_agent_dict = parse_json(saved_agent.get_line())
  saved_agent.close()
  return saved_agent_dict


func restart_population():
  get_tree().reload_current_scene()


func get_active_agents():
  var all_agents =  get_tree().get_nodes_in_group("agents")
  var active_agents := []
  for agent in all_agents:
    if !agent.is_queued_for_deletion() && !agent.is_dead:
      active_agents.append(agent)
  return active_agents


func generate_agent_population():
  pass

func decrement_agent_population(num: int = 1) -> void:
  pass

func increment_agent_population(num: int = 1) -> void:
  pass

func change_generation():
  pass

func restart_population_specific():
  pass

func generate_from_save():
  pass


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


func _on_Save_Best_Agent_pressed():
  enter_save_menu()


func enter_save_menu(exit_after: bool = false):
  is_in_save_menu = true
  save_ui.visible = true
  exit_when_finished_saving = exit_after
  save_ui_lineedit.grab_focus()
  save_ui_lineedit.caret_blink = true
  save_ui_lineedit.caret_blink_speed = 0.8


func _on_Filename_text_entered(new_text:String):
  # save(finished_agent.genome.to_dict(), new_text)
  save(winner_genome.to_dict(), new_text)
  is_in_save_menu = false
  save_ui.visible = false
  # pause_ui.visible = true
  if exit_when_finished_saving:
    var err = get_tree().change_scene("res://menu/main-menu/main-menu.tscn")
    if err != OK:
      printerr("Cannot change scene")



class AgentSorter:
  static func sort_by_dist_ascenting(a, b):
    if a[1] < b[1]:
      return true
    return false

  static func sort_by_fitness_ascenting(a, b):
    if a.get_fitness() < b.get_fitness():
      return true
    return false

