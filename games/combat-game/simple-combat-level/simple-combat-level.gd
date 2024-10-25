extends "res://games/combat-game/combat-game.gd"

export(PackedScene) var BattleCage

onready var battle_cages_node = get_node("BattleCages")


func _ready():
  var battle_cage = BattleCage.instance()
  battle_cages_node.call_deferred("add_child", battle_cage)
