extends Control

export(PackedScene) var game1
export(PackedScene) var game2

onready var game_picker  = get_node("GamePickerControl/GamePicker")
onready var id_to_game = [
  {"id": 1, "game": game1},
  {"id": 2, "game": game2}
]

var selected_game_id := 1


func _on_Run_pressed():
  var game_to_run
  for g in id_to_game:
    if selected_game_id == g["id"]:
      game_to_run = g["game"]
  var err = get_tree().change_scene_to(game_to_run)
  if err != OK:
    print("Cannot change scene")


func _on_Quit_pressed():
  get_tree().quit(0)


func _on_GamePicker_item_selected(index:int):
  selected_game_id = game_picker.get_item_id(index)
