extends Control

export(PackedScene) var combat_game


func _on_Train_pressed():
  var err = get_tree().change_scene_to(combat_game)
  if err != OK:
    print("Cannot change scene")


func _on_Back_pressed():
  get_tree().change_scene("res://menu/main-menu/main-menu.tscn")
