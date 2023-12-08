extends Node2D

const NUMBER_OF_AGENTS := 10

var used_node_ids := []

onready var agent: Node2D
onready var spawning_area: Area2D
onready var level: Node2D


func _ready():
  randomize()
  level = get_tree().get_nodes_in_group("level")[0]
  spawning_area = level.get_node("SpawningArea")
  var area_extents = spawning_area.get_node("CollisionShape2D").get_shape().get_extents()
  for _i in range(NUMBER_OF_AGENTS):
    agent = preload("res://agent.tscn").instance()
    var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
        spawning_area.get_position().x + area_extents.x)
    var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
        spawning_area.get_position().y + area_extents.y)

    agent.set_position(Vector2(pos_x, pos_y))
    add_child(agent)


func generate_UID():
  var id = randi() % 1000
  while id in used_node_ids:
    id = randi() % 1000
  return id
