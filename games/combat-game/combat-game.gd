extends "res://scripts/game.gd"

export(PackedScene) var BattleCage

onready var battle_cages_node = get_node("BattleCages")

var agent_population : int = 0


func _ready():
  var battle_cage = BattleCage.instance()
  # battle_cages_node.call_deferred("add_child", battle_cage)
  battle_cages_node.add_child(battle_cage)
  init_population()


func get_initial_pos() -> Vector2:
  var starting_pos = battle_cages_node.get_node("BattleCage/StartingPos/LeftStartingPos")
  return starting_pos.global_position


func increment_agent_population(num: int = 1) -> void:
  agent_population += num

func decrement_agent_population(num: int = 1) -> void:
  agent_population -= num


func generate_agent_population():
  var agent: Node2D
  # for i in initial_population:
  for i in 1:
    agent = Agent.instance()
    agent.position = get_initial_pos()
    agent.rotation = 0.0

    agent.population = population
    agent.nn_activated_inputs = input_names.duplicate()
    assert(population.genomes[i] != null)

    agent.genome = population.genomes[i]

    agent.game = self
    agent.lineage_times_finished = 0

    agent.add_to_group("agents")
    increment_agent_population()

    agent.connect("agent_removed", self, "decrement_agent_population")
    agents_node.call_deferred("add_child", agent)
