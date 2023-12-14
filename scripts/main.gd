extends Node2D

const NUMBER_OF_SELECTED := 10
const MUTATION_RATE = 0.1
const MUTATION_STANDARD_DEVIATION = 2.0
const EXPECTED_MUTATED_GENES = 2.0

var used_node_ids := []
var genomes := [] # A list of genomes
var generation := 0
# var init_rot = rand_range(-PI, PI)


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
    total_distance += pow(agent.position.x, 2.0)
    # total_distance += agent.position.x
  while _genomes.size() < ceil(agents.size() / 2.0):
    for agent in agents:
      # var selection_probability = agent.position.x / total_distance
      var selection_probability = pow(agent.position.x, 2.0) / total_distance
      if random.randf() < selection_probability:
        _genomes.append(agent.genome.duplicate())
  return _genomes


func crossover_sbx(parent_genomes_original, target_polutation: int):
  var random = RandomNumberGenerator.new()
  var parent_genomes = parent_genomes_original.duplicate()
  var original_genomes_size = parent_genomes.size()
  random.randomize()
  var offspring_genomes := []
  # while parent_genomes.size() >= 2:
  #   var couple := [parent_genomes.pop_at(random.randi_range(0, parent_genomes.size() - 1)),
  #       parent_genomes.pop_at(random.randi_range(0, parent_genomes.size() - 1))]
  #
  #   offspring_genomes.append_array(couple_crossover_sbx(couple, (target_polutation / original_genomes_size) * 2))
  #   print("Number of offspring: %s" % ((target_polutation / original_genomes_size) * 2))
  for _i in range(parent_genomes.size() / 2):
    var couple := [parent_genomes[random.randi_range(0, parent_genomes.size() - 1)],
        parent_genomes[random.randi_range(0, parent_genomes.size() - 1)]]

    offspring_genomes.append_array(couple_crossover_sbx(couple, (target_polutation / original_genomes_size) * 2))
  #   print("Number of offspring: %s" % ((target_polutation / original_genomes_size) * 2))
  # print("Offspring genomes size after crossover: %s" % offspring_genomes.size())
  return offspring_genomes


func couple_crossover_sbx(couple_genomes, number_of_offspring):
  var random = RandomNumberGenerator.new()
  random.randomize()
  var crossovered_genomes := []
  var crossovered_genome = couple_genomes[0].duplicate()
  for _i in range(number_of_offspring):
    for i in range(crossovered_genome["links"].size()):
      var b = random.randfn(1.0, 0.2)
      var c = random.randfn(1.0, 0.2)
      var offspring_link_weight_1: float
      var offspring_link_w_shift_1: float
      var offspring_link_weight_2: float
      var offspring_link_w_shift_2: float

      var p0_w = couple_genomes[0]["links"][i]["weight"]
      var p1_w = couple_genomes[1]["links"][i]["weight"]
      var p0_ws = couple_genomes[0]["links"][i]["w_shift"]
      var p1_ws = couple_genomes[1]["links"][i]["w_shift"]
      offspring_link_weight_1 = ((1.0 + b) * p0_w + (1.0 - b) * p1_w) / 2.0
      offspring_link_w_shift_1 = ((1.0 + c) * p0_ws + (1.0 - c) * p1_ws) / 2.0
      offspring_link_weight_2 = ((1.0 - b) * p0_w + (1.0 + b) * p1_w) / 2.0
      offspring_link_w_shift_2 = ((1.0 - c) * p0_ws + (1.0 + c) * p1_ws) / 2.0

      # if p0_w != p1_w or p0_ws != p1_ws:
      #   print("Parent 0 weight: %s" % p0_w)
      #   print("Parent 1 weight: %s" % p1_w)
      #   print("Offspring weight: %s" % offspring_link_weight_1)
      #   print("Parent 0 w_shift: %s" % p0_ws)
      #   print("Parent 1 w_shift: %s" % p1_ws)
      #   print("Offspring w_shift: %s" % offspring_link_w_shift_1)

      crossovered_genome["links"][i]["weight"] = offspring_link_weight_1
      crossovered_genome["links"][i]["w_shift"] = offspring_link_w_shift_1
      crossovered_genome["links"][i]["weight"] = offspring_link_weight_2
      crossovered_genome["links"][i]["w_shift"] = offspring_link_w_shift_2
    crossovered_genomes.append(crossovered_genome)
  # print("Couple crossover returning %s offspring" % crossovered_genomes.size())
  return crossovered_genomes


func mutate(parent_genomes):
  var random = RandomNumberGenerator.new()
  random.randomize()
  var check := false
  var mutated_genomes = parent_genomes.duplicate(true)
  for genome in mutated_genomes:
    if random.randf() < MUTATION_RATE:
      check = false
      for link in genome["links"]:
        if random.randf() < EXPECTED_MUTATED_GENES / float(genome["links"].size()):
          print("Weight Mutated")
          print("Original: %s" % link["weight"])
          link["weight"] = random.randfn(link["weight"], MUTATION_STANDARD_DEVIATION)
          print("Mutated: %s" % link["weight"])
        if random.randf() < EXPECTED_MUTATED_GENES / float(genome["links"].size()):
          print("Weight Shift Mutated")
          print("Original: %s" % link["w_shift"])
          link["w_shift"] = random.randfn(link["w_shift"], MUTATION_STANDARD_DEVIATION)
          print("Mutated: %s" % link["w_shift"])

  if check:
    for i in parent_genomes.size():
      for link_i in parent_genomes[i]["links"].size():
        var original_w = parent_genomes[i]["links"][link_i]["weight"]
        var mutated_w = mutated_genomes[i]["links"][link_i]["weight"]
        var original_w_s = parent_genomes[i]["links"][link_i]["w_shift"]
        var mutated_w_s = mutated_genomes[i]["links"][link_i]["w_shift"]
        if original_w != mutated_w || original_w_s != mutated_w_s:
          print("Genome %s. Original: %s. Mutated: %s" % [i, original_w, mutated_w])
          print("Genome %s. Original shift: %s. Mutated shift: %s" % [i, original_w_s, mutated_w_s])

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


