extends Node2D

const NUMBER_OF_SELECTED := 5
const MUTATION_RATE = 0.05
const MUTATION_STANDARD_DEVIATION = 1.0

var used_node_ids := []
var genomes := [] # A list of genomes
var generation := 0


func select_naive(agents):
  agents.sort_custom(AgentSorter, "sort_ascenting")
  var fittest_agents = agents.slice(-NUMBER_OF_SELECTED, -1)
  # print("fittest_agents length is %s" % fittest_agents.size())
  var _genomes = []
  for agent in fittest_agents:
    # print("agent's position.x is: %s" % agent.position.x)
    _genomes.append(agent.genome.duplicate())
  return _genomes


func select_roulette(agents):
  var random = RandomNumberGenerator.new()
  random.randomize()
  var total_distance := 0.0
  var _genomes = []
  for agent in agents:
    total_distance += agent.position.x
  while _genomes.size() < ceil(agents.size() / 2.0):
    for agent in agents:
      var selection_probability = agent.position.x / total_distance
      if random.randf() < selection_probability:
        _genomes.append(agent.genome.duplicate())
  return _genomes


func crossover_sbx(parent_genomes_original, target_polutation: int):
  # print("Parent genomes size: %s" % parent_genomes.size())
  var random = RandomNumberGenerator.new()
  var parent_genomes = parent_genomes_original.duplicate()
  var original_gens_size = parent_genomes.size()
  random.randomize()
  var offspring_genomes := []
  while parent_genomes.size() >= 2:
    var couple := [parent_genomes.pop_at(random.randi_range(0, parent_genomes.size() - 1)),
        parent_genomes.pop_at(random.randi_range(0, parent_genomes.size() - 1))]
    offspring_genomes.append_array(couple_crossover_sbx(couple, (target_polutation / original_gens_size) * 2))
    # print("Number of offspring: %s" % ((target_polutation / original_gens_size) * 2))
  # print("Offspring genomes size after crossover: %s" % offspring_genomes.size())
  return offspring_genomes


func couple_crossover_sbx(couple_genomes, number_of_offspring):
  var random = RandomNumberGenerator.new()
  var crossovered_genomes := []
  random.randomize()
  var crossovered_genome = couple_genomes[0].duplicate()
  for _i in number_of_offspring:
    for i in range(couple_genomes[0]["links"].size()):
      var b = random.randfn(1.0, 0.2)
      var offspring_link_weight: float
      if random.randf() > 0.5:
        offspring_link_weight = ((1.0 + b) * couple_genomes[0]["links"][i]["weight"] 
            + (1 - b) * couple_genomes[1]["links"][i]["weight"]) / 2.0
      else:
        offspring_link_weight = ((1.0 - b) * couple_genomes[0]["links"][i]["weight"] 
            + (1 + b) * couple_genomes[1]["links"][i]["weight"]) / 2.0
      crossovered_genome["links"][i]["weight"] = offspring_link_weight
    crossovered_genomes.append(crossovered_genome)
  return crossovered_genomes


func mutate(parent_genomes):
  var random = RandomNumberGenerator.new()
  random.randomize()
  var check := false
  var mutated_genomes = parent_genomes.duplicate(true)
  for genome in mutated_genomes:
    if random.randf() < MUTATION_RATE:
      print("Mutated")
      check = true
      for link in genome["links"]:
        if random.randf() < 1.0 / float(genome["links"].size()):
          link["weight"] = random.randfn(link["weight"], MUTATION_STANDARD_DEVIATION)

  # for i_gen in mutated_genomes.size():
  #   if random.randf() < MUTATION_RATE:
  #     print("Mutated")
  #     check = true
  #     for i_link in mutated_genomes[i_gen]["links"].size():
  #       if random.randf() < 1.0 / float(mutated_genomes[i_gen]["links"][i_link].size()):
  #         mutated_genomes[i_gen]["links"][i_link]["weight"] = random.randfn(mutated_genomes[i_gen]["links"][i_link]["weight"], MUTATION_STANDARD_DEVIATION)

  if check:
    for i in parent_genomes.size():
      for link_i in parent_genomes[i]["links"].size():
        var original_w = parent_genomes[i]["links"][link_i]["weight"]
        var mutated_w = mutated_genomes[i]["links"][link_i]["weight"]
        if original_w != mutated_w:
          print("Gene %s. Original: %s. Mutated: %s" % [i, original_w, mutated_w])

  return mutated_genomes


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


