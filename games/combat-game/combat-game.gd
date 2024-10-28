extends "res://scripts/game.gd"

export(PackedScene) var BattleCage

onready var battle_cages_node = get_node("BattleCages")

var agent_population : int = 0
var cage_height := 590
var cage_width := 950
var number_of_cages: int
var cages_map := []
var cage_side_size: int


func _ready():
  initialize_cages()
  init_population()


func initialize_cages() -> void:
  cage_side_size = int(ceil(sqrt(Main.AGENT_LIMIT)))
  number_of_cages = int(pow(cage_side_size, 2.0))
  for row in cage_side_size:
    cages_map.append([])
    for column in cage_side_size:
      cages_map[row].append({
        "has_cage": true,
        "has_combat": false,
        "pos": Vector2(column * cage_width, row * cage_height)
      })
      var battle_cage = BattleCage.instance()
      battle_cage.global_position = cages_map[row][column]["pos"]
      cages_map[row][column]["cage"] = battle_cage
      battle_cages_node.add_child(battle_cage)


# func get_initial_pos() -> Vector2:
#   var starting_pos = battle_cages_node.get_node("BattleCage/StartingPos/LeftStartingPos")
#   return starting_pos.global_position

func get_initial_pos(cage, side) -> Vector2:
  var starting_pos
  if side == Main.Side.LEFT:
    starting_pos = cage.get_node("StartingPos/LeftStartingPos")
  elif side == Main.Side.RIGHT:
    starting_pos = cage.get_node("StartingPos/RightStartingPos")
  return starting_pos.global_position

func get_initial_rot(side):
  if side == Main.Side.LEFT:
    return 0.0
  elif side == Main.Side.RIGHT:
    return PI


func increment_agent_population(num: int = 1) -> void:
  agent_population += num

func decrement_agent_population(num: int = 1) -> void:
  agent_population -= num


func generate_agent_population():
  var agent: Node2D
  for i in initial_population:
    agent = Agent.instance()

    # Determine cage and side
    if i % 2 == 0:
      agent.side = Main.Side.LEFT
    else:
      agent.side = Main.Side.RIGHT
    var cage_count = i / 2
    var row = cage_count / cage_side_size
    var column = cage_count % cage_side_size
    var cage = cages_map[row][column]["cage"]

    agent.position = get_initial_pos(cage, agent.side)
    agent.rotation = get_initial_rot(agent.side)

    agent.population = population
    agent.nn_activated_inputs = input_names.duplicate()
    assert(population.genomes[i] != null)

    agent.genome = population.genomes[i]

    agent.game = self

    agent.add_to_group("agents")
    increment_agent_population()

    agent.connect("agent_removed", self, "decrement_agent_population")
    agents_node.call_deferred("add_child", agent)
