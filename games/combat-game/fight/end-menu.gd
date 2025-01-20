extends CanvasLayer

signal rematch_pressed

var main_scene = get_parent()
var main_menu = "res://menu/main-menu/main-menu.tscn"


func _on_Rematch_pressed():
  Engine.time_scale = 1.0
  emit_signal("rematch_pressed")


func _on_MainMenu_pressed():
  Engine.time_scale = 1.0
  var err = get_tree().change_scene(main_menu)
  if err != OK:
    print("Cannot load main menu scene")

