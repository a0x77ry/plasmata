extends Node2D

# const NUMBER_OF_SELECTED := 5
const TARGET_POPULATION := 22

onready var spawning_area = get_node("SpawningArea")

var number_of_agents = 22
var agents = []


func _ready():
  randomize()
  if !Main.genomes.empty():
    number_of_agents = Main.genomes.size()
  generate_population()


func _process(_delta):
  if Input.is_action_just_pressed("ui_accept"):
    change_generation()


func change_generation():
    # var parent_genomes = Main.select_naive(agents)
    var parent_genomes = Main.select_roulette(agents)
    var crossovered_genomes = Main.crossover_sbx(parent_genomes, TARGET_POPULATION)
    Main.genomes = Main.mutate(crossovered_genomes)
    var err = get_tree().change_scene("res://level1.tscn")
    if err:
      print("Failed to load scene with error: %s" % err)


func generate_population():
  var agent: Node2D
  var area_extents = spawning_area.get_node("CollisionShape2D").shape.extents
  for i in range(number_of_agents):
    agent = preload("res://agent.tscn").instance()
    var pos_x = rand_range(spawning_area.get_position().x - area_extents.x,
        spawning_area.get_position().x + area_extents.x)
    var pos_y = rand_range(spawning_area.get_position().y - area_extents.y,
        spawning_area.get_position().y + area_extents.y)
    if !Main.genomes.empty():
      agent.set_genome(Main.genomes[i])
    agent.set_position(Vector2(pos_x, pos_y))
    agents.append(agent)
    agent.add_to_group("agents")
    add_child(agent)


func _on_FinishLine_body_entered(body:Node):
  if body.is_in_group("agents"):
    change_generation()


func _on_Timer_timeout():
  change_generation()

