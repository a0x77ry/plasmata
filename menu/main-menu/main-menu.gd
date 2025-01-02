extends Control

export(PackedScene) var combat_menu
export(PackedScene) var navigation_menu


func _on_Combat_pressed():
  var err = get_tree().change_scene_to(combat_menu)
  if err != OK:
    print("Cannot change scene")


func _on_Navigation_pressed():
  var err = get_tree().change_scene_to(navigation_menu)
  if err != OK:
    print("Cannot change scene")


func _on_Quit_pressed():
  get_tree().quit(0)

