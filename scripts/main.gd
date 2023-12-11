extends Node2D

const NUMBER_OF_SELECTED := 5

var used_node_ids := []
var genomes := [] # A list of genomes


func select(agents):
    agents.sort_custom(AgentSorter, "sort_ascenting")
    var fittest_agents = agents.slice(-NUMBER_OF_SELECTED, -1)
    print("fittest_agents length is %s" % fittest_agents.size())
    var _genomes = []
    for agent in fittest_agents:
      print("agent's position.x is: %s" % agent.position.x)
      _genomes.append(agent.genome)
    return _genomes


func mutate(parent_genomes):
  var random = RandomNumberGenerator.new()
  random.randomize()
  if random.randf() > 0.95:
    print("Mutated")
    var mutated_genomes = parent_genomes
    for genome in mutated_genomes:
      for link in genome["links"]:
        if random.randf() < 1 / genome["links"].size():
          link["weight"] = random.randfn(link["weight"], 1.0)
    return mutated_genomes
  else:
    return parent_genomes


func generate_UID():
  var id = randi() % 1000
  while id in used_node_ids:
    id = randi() % 1000
  return id



class AgentSorter:
  static func sort_ascenting(a, b):
    if a.position.x < b.position.x:
      return true
    return false


