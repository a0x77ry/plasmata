extends Control

export(PackedScene) var combat_game
export(PackedScene) var level_to_load

onready var saves_list = get_node("SelectGenomeContainer/SavesList")

var selected_filename_id := 1


func _ready():
  update_level_dir()


func update_level_dir():
  saves_list.clear()
  var path = "user://combat_game/simple_combat_level"
  var filenames = dir_contents(path)
  var index = 0
  for filename in filenames:
    saves_list.add_item(filename, index)
    index += 1
  if saves_list.get_item_count() > 0:
    Main.filename_to_load = saves_list.get_item_text(0)


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
  return filenames


func _on_Train_pressed():
  var err = get_tree().change_scene_to(combat_game)
  if err != OK:
    print("Cannot change scene")


func _on_SavesList_item_selected(index:int):
  selected_filename_id = saves_list.get_item_id(index)
  Main.filename_to_load = saves_list.get_item_text(selected_filename_id)


func _on_Load_Genome_pressed():
  if saves_list.get_item_count() > 0:
    var err = get_tree().change_scene_to(level_to_load)
    if err != OK:
      print("Cannot change scene")


func _on_RemoveGenome_pressed():
  var dir = Directory.new()
  var path = "user://combat_game/simple_combat_level/{filename}"\
      .format({"filename": Main.filename_to_load})
  dir.remove(path)
  update_level_dir()


func _on_Back_pressed():
  get_tree().change_scene("res://menu/main-menu/main-menu.tscn")
