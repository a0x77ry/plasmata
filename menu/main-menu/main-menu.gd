extends Control

export(PackedScene) var level_4_obstacles
export(PackedScene) var level_3_obstacles
export(PackedScene) var level_moving_obstacles

onready var game_picker  = get_node("GamePickerControl/GamePicker")
onready var id_to_game = [
  {"id": 1, "level": level_4_obstacles},
  {"id": 2, "level": level_3_obstacles},
  {"id": 3, "level": level_moving_obstacles},
]

var selected_game_id := 1


func _on_Run_pressed():
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
