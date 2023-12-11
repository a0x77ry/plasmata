extends Node2D

const NUMBER_OF_AGENTS := 10
const NUMBER_OF_SELECTED := 5

onready var spawning_area = get_node("SpawningArea")

var agents = []


func _ready():
  randomize()
  generate_population()


func _process(_delta):
  if Input.is_action_just_pressed("ui_accept"):
    var parent_genomes = Main.select(agents)
    Main.genomes = Main.mutate(parent_genomes)
    Main.genomes.append_array(Main.mutate(parent_genomes))
    var err = get_tree().change_scene("res://level1.tscn")
    if err:
      print("Failed to load scene with error: %s" % err)


func generate_population():
  var agent: Node2D
  var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  for i in range(NUMBER_OF_AGENTS):
    agent = preload("res://agent.tscn").instance()
    var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
        spawning_area.get_position().x + area_extents.x)
    var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
        spawning_area.get_position().y + area_extents.y)
    if !Main.genomes.empty():
      agent.set_genome(Main.genomes[i])
    agent.set_position(Vector2(pos_x, pos_y))
    agents.append(agent)
    add_child(agent)

