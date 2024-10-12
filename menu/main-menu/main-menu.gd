extends Control

export(PackedScene) var level_4_obstacles
export(PackedScene) var level_4_obstacles_lm
export(PackedScene) var level_3_obstacles
export(PackedScene) var level_3_obstacles_lm
export(PackedScene) var level_moving_obstacles
export(PackedScene) var level_moving_obstacles_lm

onready var game_picker  = get_node("GamePickerControl/GamePicker")
onready var saves_list = get_node("ButtonsBox/HBoxContainer/SavesList")
onready var id_to_game = [
  {"id": 1,
   "level": level_4_obstacles,
   "loadlevel": level_4_obstacles_lm,
   "level_name": "4 Obstacles",
   "level_dir": "level_4_obstacles",
  },
  {"id": 2,
   "level": level_3_obstacles,
   "loadlevel": level_3_obstacles_lm,
   "level_name": "3 Obstacles",
   "level_dir": "level_3_obstacles",
  },
  {"id": 3,
   "level": level_moving_obstacles,
   "loadlevel": level_moving_obstacles_lm,
   "level_name": "Moving Obstacles",
   "level_dir": "level_moving_obstacles",
   },
]

var selected_game_id := 1


func _ready():
  for index in id_to_game.size():
    game_picker.add_item(id_to_game[index]["level_name"], index + 1)
  update_level_dir()


func update_level_dir():
  saves_list.clear()
  var level_dir
  for g in id_to_game:
    if selected_game_id == g["id"]:
      level_dir = g["level_dir"]
      # print("Level id is %s" % selected_game_id)
  var path = "user://nav_game/{level_dir}".format({"level_dir": level_dir})
  var filenames = dir_contents(path)
  for filename in filenames:
    saves_list.add_item(filename)


func dir_contents(path):
  var filenames := []
  var dir = Directory.new()
  if dir.open(path) == OK:
      dir.list_dir_begin()
      var file_name = dir.get_next()
      while file_name != "":
        if !dir.current_is_dir():
          filenames.append(file_name)
        file_name = dir.get_next()
  else:
      print("An error occurred when trying to access the path.")
  return filenames


func _on_Train_pressed():
  var level_to_run
  for g in id_to_game:
    if selected_game_id == g["id"]:
      level_to_run = g["level"]
  var err = get_tree().change_scene_to(level_to_run)
  if err != OK:
    print("Cannot change scene")


func _on_Quit_pressed():
  get_tree().quit(0)


func _on_GamePicker_item_selected(index:int):
  selected_game_id = game_picker.get_item_id(index)
  update_level_dir()


func _on_Load_Genome_pressed():
  var level_to_load
  for g in id_to_game:
    if selected_game_id == g["id"]:
      level_to_load = g["loadlevel"]
  var err = get_tree().change_scene_to(level_to_load)
  if err != OK:
    print("Cannot change scene")
