extends Node2D

export(PackedScene) var CombatPlayer
export(PackedScene) var Agent
export(bool) var debugging

onready var battle_cage = get_node("BattleCage")
onready var countdown_label = get_node("CanvasLayer/CountdownLabel")
onready var win_label = get_node("CanvasLayer/WinLabel")
onready var lose_label = get_node("CanvasLayer/LoseLabel")
onready var end_menu = get_node("EndMenu")

var player
var population
var is_loading_mode_enabled = false
var is_in_fight_mode = true
var countdown_time = 3.0

var input_names = [
  "rotation",

  # "pos_x",
  # "pos_y",
  "ray_f_distance",
  "ray_b_distance",
  "ray_f_up_right_distance",
  "ray_f_down_right_distance",
  "ray_left_distance",
  "ray_right_distance",

  "rf_col_normal_angle",
  "rb_col_normal_angle",
  "rl_col_normal_angle",
  "rr_col_normal_angle",
  "rfu_col_normal_angle",
  "rfd_col_normal_angle",

  "turn_right_input",
  "move_forward_input",
  "move_right_input",
  "shooting_input",

  "opponents_forward_movement",
  "opponents_right_movement",
  "opponents_heading",
  "opponent_angle",
  "opponent_distance",

  "traced_laser_1_angle",
  "traced_laser_1_distance",
]

var output_names = [
  "turn_right",
  # "rotation_target",
  "move_forward",
  "move_right",
  "shooting"
]


func _ready():
  var err = end_menu.connect("rematch_pressed", self, "_on_rematch_pressed")
  if err != OK:
    print("Could not connect signal rematch_pressed")

  Input.mouse_mode = Input.MOUSE_MODE_CONFINED

  yield(countdown(), "completed")
  player = CombatPlayer.instance()
  player.global_position = battle_cage.left_pos.global_position
  player.game = self
  battle_cage.agent_left = player
  add_child(player)

  if !debugging:
    population = Population.new([], input_names, output_names, 10)
    generate_from_save()


func countdown():
  yield(get_tree(), "idle_frame")
  countdown_label.visible = true
  for i in int(countdown_time):
    countdown_label.text = String(countdown_time - float(i))
    yield(get_tree().create_timer(1.0), "timeout")
  countdown_label.visible = false


func generate_from_save():
  var agent: Node2D
  agent = Agent.instance()

  agent.position = battle_cage.right_pos.global_position
  agent.rotation = PI
  agent.population = population
  agent.nn_activated_inputs = input_names.duplicate()
  agent.game = self
  agent.side = Main.Side.RIGHT
  agent.battle_cage = battle_cage
  var err = agent.connect("agent_killed", self, "_on_agent_death")
  if err != OK:
    print("Could not connect signal to _on_agent_death")

  var gen = Genome.new(population)
  gen.from_dict(load_agent(Main.filename_to_load))
  agent.genome = gen
  battle_cage.agent_right = agent

  add_child(agent)


func load_agent(name) -> Dictionary:
  var saved_agent = File.new()
  var filepath = "user://combat_game/simple_combat_level/{name}"\
      .format({"name": name})
  assert(saved_agent.file_exists(filepath))
  saved_agent.open(filepath, File.READ)
  var saved_agent_dict = parse_json(saved_agent.get_line())
  saved_agent.close()
  return saved_agent_dict


func end_match(has_player_won: bool):
  var label
  if has_player_won:
    label = win_label
  else:
    label = lose_label

  battle_cage.clean_cage()

  label.visible = true
  yield(get_tree().create_timer(2.0), "timeout")
  Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
  Engine.time_scale = 0.0
  label.visible = false
  end_menu.visible = true


func _on_player_dead():
  end_match(false)


func _on_agent_death(_side, _is_hit):
  end_match(true)


func _on_rematch_pressed():
  var err = get_tree().reload_current_scene()
  if err != OK:
    print("Cannot reload current scene: fight")

